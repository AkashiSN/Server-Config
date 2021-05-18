package main

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/gorilla/sessions"
	"github.com/labstack/echo-contrib/session"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

const (
	slackAuthorizeURL   = "https://slack.com/oauth/authorize"
	slackOauthAccessURL = "https://slack.com/api/oauth.access"

	logFilePath       = "/var/promtail/auth-proxy/"
	accessLogFileName = "access.log"
	errorLogFileName  = "error.log"
	infoLogFileName   = "info.log"

	unregister = `if ('serviceWorker' in navigator) {
	navigator.serviceWorker.getRegistrations().then((registrations) => {
		if (registrations.length != 0) {
			for (let i = 0; i < registrations.length; i++) {
				registrations[i].unregister();
				console.log('ServiceWorker unregister.');
			}
			caches.keys().then((keys) => {
				Promise.all(keys.map((key) => { caches.delete(key); })).then(() => {
					console.log('caches delete.');
				});
			});
		}
	});
}
alert("ServiceWorker has been unregistered. Redirect to Slack...");
document.location="/"`
)

var (
	slackClientID     = os.Getenv("SLACK_CLIENT_ID")
	slackClientSecret = os.Getenv("SLACK_CLIENT_SECRET")

	infolog *log.Logger
	errlog  *log.Logger

	accesslogWriter    *Writer
	infoLogFileWriter  *Writer
	errorLogFileWriter *Writer
)

func newWriter(fileName string) *Writer {
	logFile, _ := os.OpenFile(filepath.Join(logFilePath, fileName), os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
	return NewReplaceableWriter(logFile)
}

func (w *Writer) replaceWriter(fileName string) {
	logFile, _ := os.OpenFile(filepath.Join(logFilePath, fileName), os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
	w.Replace(logFile)
}

func init() {
	if _, err := os.Stat(logFilePath); err != nil {
		os.Mkdir(logFilePath, 0775)
	}

	accesslogWriter = newWriter(accessLogFileName)

	infoLogFileWriter = newWriter(infoLogFileName)
	infolog = log.New(infoLogFileWriter, "", log.LstdFlags)

	errorLogFileWriter = newWriter(errorLogFileName)
	errlog = log.New(errorLogFileWriter, "", log.LstdFlags)

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGUSR1)
	go func() {
		for {
			<-ch
			fmt.Println("Catch signal.")
			accesslogWriter.replaceWriter(accessLogFileName)
			infoLogFileWriter.replaceWriter(infoLogFileName)
			errorLogFileWriter.replaceWriter(errorLogFileName)
		}
	}()

	// Record my PID
	f, _ := os.Create("/var/run/auth-proxy.pid")
	fmt.Fprintf(f, "%d", os.Getpid())
	f.Close()
}

func makeRandomStr(digit uint32) (string, error) {
	const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

	b := make([]byte, digit)
	rand.Read(b)

	var result string
	for _, v := range b {
		result += string(letters[int(v)%len(letters)])
	}

	return result, nil
}

// callbackされてきたcodeが正規の物か確認
func checkCode(code, redirectURL string) (string, error) {
	values := url.Values{}
	values.Set("code", code)
	values.Add("client_id", slackClientID)
	values.Add("client_secret", slackClientSecret)
	values.Add("redirect_uri", redirectURL)

	request, err := http.NewRequest("POST", slackOauthAccessURL, strings.NewReader(values.Encode()))
	if err != nil {
		errlog.Fatal(err)
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	client := &http.Client{}
	resp, err := client.Do(request)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	bodyData, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var jsonBody map[string]interface{}
	err = json.Unmarshal(bodyData, &jsonBody)
	if err != nil {
		return "", err
	}

	if !jsonBody["ok"].(bool) {
		return "", fmt.Errorf("Forbidden")
	}

	return jsonBody["user"].(map[string]interface{})["name"].(string), nil
}

func serve() *echo.Echo {
	e := echo.New()

	token := make([]byte, 32)
	rand.Read(token)

	e.Use(session.Middleware(sessions.NewCookieStore([]byte(token))))

	e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Format: "${time_rfc3339}, ${remote_ip}, method=${method}, uri=${uri}, status=${status}, ua=${user_agent}\n",
		Output: accesslogWriter,
	}))

	// nginxからauth_requestでとんでくるルーティング
	e.GET("/oauth2/auth", func(c echo.Context) error {
		sess, err := session.Get("session", c)
		if err != nil {
			return c.NoContent(http.StatusUnauthorized)
		}

		_, ok := sess.Values["userName"]
		// ログインしてるとき
		if ok {
			return c.NoContent(http.StatusOK)
		}

		return c.NoContent(http.StatusUnauthorized)
	})

	// ログインする
	e.GET("/oauth2/start", func(c echo.Context) error {
		scheme := c.Request().Header.Get("X-Forwarded-Proto")
		domain := c.Request().Header.Get("X-Forwarded-Server")
		redirectURL := scheme + "://" + domain + "/oauth2/callback"

		request, err := http.NewRequest("GET", slackAuthorizeURL, nil)
		if err != nil {
			errlog.Fatal(err)
		}

		sess, _ := session.Get("session", c)
		sess.Options = &sessions.Options{
			Path:     "/",
			Domain:   domain,
			MaxAge:   86400,
			HttpOnly: true,
		}

		// 一時的なランダム文字列
		state, err := makeRandomStr(32)
		if err != nil {
			errlog.Fatal(err)
		}

		//クエリパラメータ
		params := request.URL.Query()
		params.Add("scope", "identity.basic,identity.email")
		params.Add("client_id", slackClientID)
		params.Add("redirect_uri", redirectURL)
		params.Add("state", state)
		request.URL.RawQuery = params.Encode()

		// ランダム文字列をセッションに保存
		sess.Values["state"] = state
		if err := sess.Save(c.Request(), c.Response()); err != nil {
			return c.NoContent(http.StatusInternalServerError)
		}

		return c.Redirect(http.StatusFound, request.URL.String())
	})

	// slackからのcallback
	e.GET("/oauth2/callback", func(c echo.Context) error {
		sess, _ := session.Get("session", c)

		// 一時的なランダム文字列により正規ユーザかを確認
		val, ok := sess.Values["state"]
		if !ok || val != c.QueryParam("state") {
			return c.HTML(http.StatusUnauthorized, "<script>"+unregister+"</script>")
		}
		sess.Values["state"] = ""

		scheme := c.Request().Header.Get("X-Forwarded-Proto")
		domain := c.Request().Header.Get("X-Forwarded-Server")
		URL := scheme + "://" + domain
		redirectURL := URL + "/oauth2/callback"

		code := c.QueryParam("code")
		userName, err := checkCode(code, redirectURL)
		if err != nil {
			errlog.Print(err)
			return c.String(http.StatusUnauthorized, "Forbidden: invalid user")
		}

		sess.Options = &sessions.Options{
			Path:     "/",
			Domain:   domain,
			MaxAge:   86400 * 7,
			HttpOnly: true,
		}
		sess.Values["userName"] = userName

		if err := sess.Save(c.Request(), c.Response()); err != nil {
			return c.NoContent(http.StatusInternalServerError)
		}

		infolog.Println("Logined " + userName)

		return c.Redirect(http.StatusFound, URL)
	})

	return e
}

func main() {
	if slackClientID == "" || slackClientSecret == "" {
		errlog.Fatal("must be setted clientID and client secret")
	}

	server := serve()
	server.Start(":80")
}
