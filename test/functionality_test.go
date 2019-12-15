package functionality_test

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/miekg/dns"
	"github.com/powerman/check"
)

// This was originally an init func but os.Getenv must be
// called inside each Test... func for test caching to work.
// See: https://github.com/golang/go/issues/24589
func getBinPath(t *testing.T) string {
	t.Helper()
	searchPaths := []string{}
	name := "dnscrypt-proxy"
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	if path := os.Getenv("BINPATH"); len(path) > 0 { // user can provide a path in the BINPATH environment variable, it can be:
		searchPaths = append(searchPaths, path)                      // the full path to the binary (in case it has a different name)
		searchPaths = append(searchPaths, filepath.Join(path, name)) // or a directory containing the binary
	}
	if path, err := os.Getwd(); err == nil { // also search in current directory
		searchPaths = append(searchPaths, filepath.Join(path, name))
	}
	searchPaths = append(searchPaths, name) // also search standard PATH environment variable (exec.LookPath does this implicitly when given plain filename)
	for _, path := range searchPaths {
		if binPath, err := exec.LookPath(path); err == nil {
			if binPath, err = filepath.Abs(binPath); err != nil {
				t.Errorf("Failed to get absolute path: %s", err)
			}
			t.Logf("Testing application binary %s", binPath)
			if err = os.Chdir(filepath.Dir(binPath)); err != nil {
				t.Errorf("Failed to change directory: %s", err)
			}
			return binPath
		}
	}
	t.Skipf(`To run functionality tests, either:
	- provide full path to executable file in BINPATH environment variable, or
	- provide directory containing executable '%s' in BINPATH environment variable, or
	- place executable '%s' in working directory or any directory specified in PATH environment variable.
Paths searched:
	- %s`, name, name, strings.Join(searchPaths, `
	- `))
	return ""
}

type matcherOutput interface{}                  // see matchOne func for implemented matcher outputs - https://github.com/golang/go/issues/19412
type lineMatcher interface{}                    // see matchOne func for implemented matcher types - https://github.com/golang/go/issues/19412
type lineMatchers map[lineMatcher][]lineMatcher // last successful line matcher maps to slice of matchers valid for next line
type matchHandler func(ctx context.Context, c *check.C, p *os.Process, o matcherOutput)
type matchHandlers map[lineMatcher]matchHandler // last successful line matcher maps to function handling that event
type matchResult struct {                       // result struct for passing through chan from matcher goroutines to handler goroutine
	matcher lineMatcher
	match   matcherOutput
}

type dnsQuery struct {
	domain string
	rtype  string
	log    *regexp.Regexp
	rcode  string
	answer []*regexp.Regexp
}
type FuncTest struct {
	name     string
	args     []string
	env      []string
	dir      string
	stdin    string
	stdout   lineMatchers
	stderr   lineMatchers
	fail     bool
	handlers matchHandlers
}

const ( // snippets of configuration passed to the tested executable via stdin
	c_Offline   = "offline_mode = true\n"
	c_Listen    = "listen_addresses = ['127.0.0.1:0']\n"
	c_BlockV6   = "block_ipv6 = true\n"
	c_Cloak     = "cloaking_rules = '%s'\n"
	c_qLog      = "[query_log]\nfile = '/dev/stdout'\n"
	c_Blacklist = "[blacklist]\nblacklist_file = '%s'\n"
)
const ( // snippets of uncompiled regular expressions for use in matchers
	r_LogPrefix = `^\[[^\]]+\]\s\[[^\]]+\]\s`
	r_QueryLog  = `^\[[^\]]+\]\s127\.0\.0\.1\s%s\s%s\s%s\s\d+ms\s%s$`
	r_Version   = `\d+\.\d+\.\d+`
	r_IP        = `\d+\.\d+\.\d+\.\d+`
)

var ( // line matchers used to check contents of stdout and stderr
	m_Version      = regexp.MustCompile(`^` + r_Version + `$`)
	m_HelpHeader   = regexp.MustCompile(`^Usage of [^:]+:$`)
	m_HelpItem     = regexp.MustCompile(`^  -.+$`)
	m_HelpText     = regexp.MustCompile(`^    	.+$`)
	m_NoConfig     = regexp.MustCompile(r_LogPrefix + `Unable to load the configuration file`)
	m_NameVersion  = regexp.MustCompile(r_LogPrefix + `dnscrypt-proxy ` + r_Version)
	m_Connectivity = regexp.MustCompile(r_LogPrefix + `Network connectivity detected$`)
	m_NoServers    = regexp.MustCompile(r_LogPrefix + `No servers configured$`)
	m_Checked      = regexp.MustCompile(r_LogPrefix + `Configuration successfully checked$`)
	m_LoadFirefox  = regexp.MustCompile(r_LogPrefix + `Firefox workaround initialized$`)
	m_LoadCloak    = regexp.MustCompile(r_LogPrefix + `Loading the set of cloaking rules`)
	m_LoadBlock    = regexp.MustCompile(r_LogPrefix + `Loading the set of blocking rules`)
	m_Listening    = regexp.MustCompile(r_LogPrefix + `Now listening to (` + r_IP + `:\d+) \[([^\]]+)\]$`)
	m_Stopped      = regexp.MustCompile(r_LogPrefix + `Stopped\.$`)
)

var ( // DNS queries to send to the tested executable after it tells us which ports it listens on, and the expected response
	q_Firefox = newDNSQuery("use-application-dns.net", "A", "SYNTH", "-", "NXDOMAIN")
	q_BlockV6 = newDNSQuery("dnscrypt.info", "AAAA", "SYNTH", "-", "NOERROR",
		`^dnscrypt\.info\.\s86400\sIN\sHINFO\s"AAAA queries have been locally blocked by dnscrypt-proxy" "Set block_ipv6 to false to disable this feature"$`,
	)
	q_ExampleCloak     = newDNSQuery("localhost", "A", "CLOAK", "-", "NOERROR", `^localhost\.\s600\sIN\sA\s127\.0\.0\.1$`)
	q_ExampleCloakV6   = newDNSQuery("localhost", "AAAA", "CLOAK", "-", "NOERROR", `^localhost\.\s600\sIN\sAAAA\s::1$`)
	q_ExampleBlacklist = newDNSQuery("eth0.me", "A", "REJECT", "-", "NOERROR",
		`^eth0\.me\.\s1\sIN\sHINFO\s"This query has been locally blocked" "by dnscrypt-proxy"$`,
	)
)

func newDNSQuery(domain, rtype, logRcode, logServer, rcode string, answers ...string) *dnsQuery {
	m_answers := make([]*regexp.Regexp, len(answers))
	for i, a := range answers {
		m_answers[i] = regexp.MustCompile(a)
	}
	r := fmt.Sprintf(r_QueryLog, regexp.QuoteMeta(domain), regexp.QuoteMeta(rtype), regexp.QuoteMeta(logRcode), regexp.QuoteMeta(logServer))
	return &dnsQuery{domain, rtype, regexp.MustCompile(r), rcode, m_answers}
}

func matchOne(ctx context.Context, c *check.C, actual string, expects []lineMatcher) (result *matchResult) {
	matched := false
	for _, matcher := range expects {
		switch expect := matcher.(type) {
		case string:
			matched = expect == actual
		case *regexp.Regexp:
			if expect.NumSubexp() > 0 {
				if match := expect.FindStringSubmatch(actual); match != nil {
					return &matchResult{matcher, match}
				}
			} else {
				matched = expect.MatchString(actual)
			}
		}
		if matched {
			return &matchResult{matcher, true}
		}
	}
	return nil
}

func matchLines(ctx context.Context, c *check.C, wg *sync.WaitGroup, name string, r io.Reader, matchers lineMatchers, results chan<- *matchResult) {
	var matcher lineMatcher = 0 // the 0 key holds the set of starting matchers, the nil key should not be set to catch faulty tests
	shouldFunc := func(c *check.C, actual, expects interface{}) (matched bool) {
		if r := matchOne(ctx, c, actual.(string), expects.([]lineMatcher)); r != nil {
			results <- r
			matcher = r.matcher
			matched = true
		}
		return
	}
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		if !c.Should(shouldFunc, scanner.Text(), matchers[matcher], name) {
			var remaining strings.Builder
			for scanner.Scan() {
				remaining.Write(scanner.Bytes())
				remaining.WriteByte('\n')
			}
			if remaining.Len() > 0 {
				c.Logf("Remaining %s:\n%s", name, remaining.String())
			}
		}
	}
	wg.Done()
}

func handleMatchResult(ctx context.Context, c *check.C, p *os.Process, done chan<- bool, results <-chan *matchResult, handlers matchHandlers) {
	for result := range results {
		if handler, ok := handlers[result.matcher]; ok {
			handler(ctx, c, p, result.match)
		}
	}
	done <- true
}

func sendQuery(ctx context.Context, c *check.C, proto, addr string, q *dnsQuery) bool {
	m := dns.Msg{}
	m.SetQuestion(dns.Fqdn(q.domain), dns.StringToType[q.rtype])
	var r *dns.Msg
	var err error
	switch proto {
	case "UDP":
		r, err = dns.ExchangeContext(ctx, &m, addr)
	case "TCP":
		dConn := new(dns.Conn)
		dConn.Conn, err = new(net.Dialer).DialContext(ctx, "tcp", addr)
		if !c.Nil(err, "TCP dial %s\n%s", addr, m) {
			return false
		}
		defer dConn.Close()
		err = dConn.WriteMsg(&m)
		if !c.Nil(err, "TCP write %s\n%s", addr, m) {
			return false
		}
		r, err = dConn.ReadMsg()
	default:
		c.Errorf("Unimplemented DNS transport protocol: %s", proto)
		return false
	}
	if !c.Nil(err, "%s query to %s\n%s", proto, addr, m) || !c.NotNil(r, "%s query to %s\n%s", proto, addr, m) {
		return false
	}
	c.Logf("%s query to %s\n%s", proto, addr, r)
	if !c.EQ(r.Rcode, dns.StringToRcode[q.rcode], "DNS Rcode") || !c.EQ(len(r.Answer), len(q.answer), "DNS answers") {
		return false
	}
	for i, a := range q.answer {
		if !c.Match(r.Answer[i].String(), a, "DNS answer") {
			return false
		}
	}
	return true
}

func handleListening(queries ...*dnsQuery) func(ctx context.Context, c *check.C, p *os.Process, o matcherOutput) {
	return func(ctx context.Context, c *check.C, p *os.Process, o matcherOutput) {
		match := o.([]string)
		c.Must(c.NotNil(match, "empty matcher output"))
		c.Must(c.Len(match, 3, "unexpected matcher output length"))
		for _, q := range queries {
			if !sendQuery(ctx, c, match[2], match[1], q) {
				c.Must(c.Nil(p.Kill(), "send kill signal"))
				return
			}
		}
		if match[2] == "TCP" { // TODO: make this condition less fragile/arbitrary
			c.Must(c.Nil(p.Signal(os.Interrupt), "send interrupt signal"))
		}
	}
}

func runFuncTest(t *testing.T, tt FuncTest, binPath string) {
	name := tt.name
	if len(name) == 0 {
		name = strings.Join(tt.args, " ")
	}
	t.Run(name, func(t *testing.T) {
		c := check.T(t)
		c.Parallel() // this requires `tt` to be a copy of the variable being manipulated by `range`, which we get in a func
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, binPath, tt.args...)
		cmd.Env = append(cmd.Env, tt.env...)
		cmd.Dir = tt.dir
		cmd.Stdin = strings.NewReader(tt.stdin)
		stdout, err := cmd.StdoutPipe()
		c.Must(c.Nil(err, "cmd.StdoutPipe()"))
		stderr, err := cmd.StderrPipe()
		c.Must(c.Nil(err, "cmd.StderrPipe()"))
		var wg sync.WaitGroup
		wg.Add(2)
		r := make(chan *matchResult)
		done := make(chan bool, 1)
		go matchLines(ctx, c, &wg, "stdout", stdout, tt.stdout, r)
		go matchLines(ctx, c, &wg, "stderr", stderr, tt.stderr, r)
		c.Must(c.Nil(cmd.Start(), "cmd.Start()"))
		go handleMatchResult(ctx, c, cmd.Process, done, r, tt.handlers)
		wg.Wait()
		close(r)
		<-done
		err = cmd.Wait()
		c.EQ(cmd.ProcessState.Success(), !tt.fail, "exit success")
		if tt.fail {
			c.Match(err, "exit status", "exit error")
		} else {
			c.Nil(err, "exit error")
		}
		c.NotErr(ctx.Err(), context.DeadlineExceeded, "timeout")
	})
}

func TestBasic(t *testing.T) {
	binPath := getBinPath(t)
	for _, tt := range []FuncTest{
		{
			args:   []string{"-version"},
			stdout: lineMatchers{0: {m_Version}},
		},
		{
			args:   []string{"-check"},
			stderr: lineMatchers{0: {m_NoConfig}},
			fail:   true,
		},
		{
			args: []string{"-help"},
			stderr: lineMatchers{
				0:            {m_HelpHeader},
				m_HelpHeader: {m_HelpItem},
				m_HelpItem:   {m_HelpText},
				m_HelpText:   {m_HelpItem, m_HelpText},
			},
			fail: true,
		},
		{
			args: []string{"-config", "/dev/null"},
			stderr: lineMatchers{
				0:              {m_NameVersion},
				m_NameVersion:  {m_Connectivity},
				m_Connectivity: {m_NoServers},
			},
			fail: true,
		},
		{
			name:  "check offline",
			args:  []string{"-check", "-config", "/dev/stdin"},
			stdin: c_Offline,
			stderr: lineMatchers{
				0:              {m_NameVersion},
				m_NameVersion:  {m_Connectivity},
				m_Connectivity: {m_Checked},
			},
		},
		{
			name:  "show-certs offline",
			args:  []string{"-show-certs", "-config", "/dev/stdin"},
			stdin: c_Offline,
			stderr: lineMatchers{
				0:              {m_NameVersion},
				m_NameVersion:  {m_Connectivity},
				m_Connectivity: {m_LoadFirefox},
			},
		},
		{
			name:  "query firefox plugin",
			args:  []string{"-config", "/dev/stdin"},
			stdin: c_Offline + c_Listen + c_qLog,
			stdout: lineMatchers{
				0:             {q_Firefox.log},
				q_Firefox.log: {q_Firefox.log},
			},
			stderr: lineMatchers{
				0:              {m_NameVersion},
				m_NameVersion:  {m_Connectivity},
				m_Connectivity: {m_LoadFirefox},
				m_LoadFirefox:  {m_Listening},
				m_Listening:    {m_Listening, m_Stopped},
			},
			handlers: matchHandlers{
				m_Listening: handleListening(q_Firefox),
			},
		},
		{
			name:  "query block_ipv6",
			args:  []string{"-config", "/dev/stdin"},
			stdin: c_Offline + c_Listen + c_BlockV6 + c_qLog,
			stdout: lineMatchers{
				0:             {q_BlockV6.log},
				q_BlockV6.log: {q_BlockV6.log},
			},
			stderr: lineMatchers{
				0:              {m_NameVersion},
				m_NameVersion:  {m_Connectivity},
				m_Connectivity: {m_LoadFirefox},
				m_LoadFirefox:  {m_Listening},
				m_Listening:    {m_Listening, m_Stopped},
			},
			handlers: matchHandlers{
				m_Listening: handleListening(q_BlockV6),
			},
		},
		{
			name:  "query example cloaking",
			args:  []string{"-config", "/dev/stdin"},
			stdin: c_Offline + c_Listen + fmt.Sprintf(c_Cloak, filepath.Join(filepath.Dir(binPath), "example-cloaking-rules.txt")) + c_qLog,
			stdout: lineMatchers{
				0:                    {q_ExampleCloak.log, q_ExampleCloakV6.log}, // queries can be logged out of order
				q_ExampleCloak.log:   {q_ExampleCloak.log, q_ExampleCloakV6.log}, // and UDP/TCP tests can overlap
				q_ExampleCloakV6.log: {q_ExampleCloak.log, q_ExampleCloakV6.log},
			},
			stderr: lineMatchers{
				0:              {m_NameVersion},
				m_NameVersion:  {m_Connectivity},
				m_Connectivity: {m_LoadFirefox},
				m_LoadFirefox:  {m_LoadCloak},
				m_LoadCloak:    {m_Listening},
				m_Listening:    {m_Listening, m_Stopped},
			},
			handlers: matchHandlers{
				m_Listening: handleListening(q_ExampleCloak, q_ExampleCloakV6),
			},
		},
		{
			name:  "query example blacklist",
			args:  []string{"-config", "/dev/stdin"},
			stdin: c_Offline + c_Listen + c_qLog + fmt.Sprintf(c_Blacklist, filepath.Join(filepath.Dir(binPath), "example-blacklist.txt")),
			stdout: lineMatchers{
				0:                      {q_ExampleBlacklist.log},
				q_ExampleBlacklist.log: {q_ExampleBlacklist.log},
			},
			stderr: lineMatchers{
				0:              {m_NameVersion},
				m_NameVersion:  {m_Connectivity},
				m_Connectivity: {m_LoadFirefox},
				m_LoadFirefox:  {m_LoadBlock},
				m_LoadBlock:    {m_Listening},
				m_Listening:    {m_Listening, m_Stopped},
			},
			handlers: matchHandlers{
				m_Listening: handleListening(q_ExampleBlacklist),
			},
		},
	} {
		runFuncTest(t, tt, binPath)
	}
}

// func TestForwarding(t *testing.T) {
//	binPath := getBinPath(t)
// TODO: start a DNS server that will respond to queries from the tested application
// 	for _, tt := range []FuncTest{
// 	} {
// 		runFuncTest(t, tt, binPath)
// 	}
// }

// func TestDnscrypt(t *testing.T) {
//	binPath := getBinPath(t)
// TODO: start a DNSCrypt server that will respond to queries from the tested application
// 	for _, tt := range []FuncTest{
// 	} {
// 		runFuncTest(t, tt, binPath)
// 	}
// }

// func TestDoH(t *testing.T) {
//	binPath := getBinPath(t)
// TODO: start a DoH server that will respond to queries from the tested application
// 	for _, tt := range []FuncTest{
// 	} {
// 		runFuncTest(t, tt, binPath)
// 	}
// }

func TestMain(m *testing.M) { check.TestMain(m) }
