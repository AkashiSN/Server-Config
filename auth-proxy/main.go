package main

import (
	"crypto/rand"
	"flag"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/gorilla/sessions"
	"github.com/labstack/echo-contrib/session"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

const slackURL = "https://slack.com/oauth/authorize"

func serve(clientID string) *echo.Echo{
	e := echo.New()

	token := make([]byte, 32)
	rand.Read(token)

	e.Use(session.Middleware(sessions.NewCookieStore([]byte(token))))
	e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Format: "method=${method}, uri=${uri}, status=${status}\n",
	}))

	// nginxからauth_requestでとんでくるルーティング
	e.GET("/oauth2/auth", func(c echo.Context) error {
		UA := c.Request().UserAgent()
		if strings.Contains(UA, "VLC") {
			return c.NoContent(http.StatusOK)
		}

		sess, err := session.Get("session", c)
		if err != nil {
			return c.NoContent(http.StatusUnauthorized)
		}

		b, ok := sess.Values["auth"]
		// ログインしてるとき
		if ok && b == "true" {
			return c.NoContent(http.StatusOK)
		}

		return c.NoContent(http.StatusUnauthorized)
	})

	// ログインする
	e.GET("/oauth2/start", func(c echo.Context) error {
		scheme := c.Request().Header.Get("X-Forwarded-Proto")
		domain := c.Request().Header.Get("X-Forwarded-Server")
		url := scheme + "://" + domain + "/oauth2/callback"

		request, err := http.NewRequest("GET", slackURL, nil)
		if err != nil{
			log.Fatal(err)
		}
		
		//クエリパラメータ
		params := request.URL.Query()
		params.Add("scope", "identity.basic,identity.email")
		params.Add("client_id", clientID)
		params.Add("redirect_uri", url)
		request.URL.RawQuery = params.Encode()
 
		log.Println(request.URL.String())
		
		return c.Redirect(http.StatusFound, request.URL.String())
	})

	// slackからのcallback
	e.GET("/oauth2/callback", func(c echo.Context) error {
		if c.QueryParam("error") != "" {
			return c.String(http.StatusUnauthorized, "Forbidden")
		}

		scheme := c.Request().Header.Get("X-Forwarded-Proto")
		domain := c.Request().Header.Get("X-Forwarded-Server")
		url := scheme + "://" + domain

		log.Println(url)
		sess, _ := session.Get("session", c)
		sess.Options = &sessions.Options{
			Path:     "/",
			Domain:   domain,
			MaxAge:   86400 * 7,
			HttpOnly: true,
		}
		sess.Values["auth"] = "true"

		if err := sess.Save(c.Request(), c.Response()); err != nil {
			return c.NoContent(http.StatusInternalServerError)
		}

		return c.Redirect(http.StatusFound, url)
	})

	return e
}

func main() {
	clientID := flag.String("clientID","","Slack client ID (required)")

	flag.Parse()
	if *clientID == "" {
		flag.Usage()
		os.Exit(1)
	}

	server := serve(*clientID)
	log.Println(server.Start(":8080"))
}
