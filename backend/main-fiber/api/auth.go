package api

import (
	"log"
	"os"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/pllus/main-fiber/models"
	"go.mongodb.org/mongo-driver/bson"
	"golang.org/x/crypto/bcrypt"
)

// ---- helpers ----

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return def
}

func jwtSecret() []byte { return []byte(os.Getenv("JWT_SECRET")) }

func signAccess(u models.User) (string, error) {
	min := envInt("ACCESS_TOKEN_TTL_MIN", 15)
	claims := jwt.MapClaims{
		"sub":   u.ID,
		"email": u.Email,
		"roles": u.Roles,
		"exp":   time.Now().Add(time.Duration(min) * time.Minute).Unix(),
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return t.SignedString(jwtSecret())
}

func signRefresh(u models.User) (string, error) {
	min := envInt("REFRESH_TOKEN_TTL_MIN", 60*24*30)
	claims := jwt.MapClaims{
		"sub": u.ID,
		"typ": "refresh",
		"exp": time.Now().Add(time.Duration(min) * time.Minute).Unix(),
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return t.SignedString(jwtSecret())
}

func setRefreshCookie(c *fiber.Ctx, token string) {
	c.Cookie(&fiber.Cookie{
		Name:     "refresh_token",
		Value:    token,
		HTTPOnly: true,
		SameSite: "None",
		Secure:   false, // set true when serving over https
		Path:     "/api/auth",
		MaxAge:   envInt("REFRESH_TOKEN_TTL_MIN", 60*24*30) * 60,
	})
}

func clearRefreshCookie(c *fiber.Ctx) {
	c.Cookie(&fiber.Cookie{
		Name:     "refresh_token",
		Value:    "",
		HTTPOnly: true,
		SameSite: "None",
		Secure:   false,
		Path:     "/api/auth",
		MaxAge:   -1,
	})
}

// ---- payloads ----

type loginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type loginResp struct {
	User        models.User `json:"user"`
	AccessToken string      `json:"accessToken"`
}

// ---- routes ----

func RegisterAuthRoutes(r fiber.Router) {
	g := r.Group("/auth")
	g.Post("/login", loginHandler)
	g.Get("/me", meHandler)
	g.Post("/refresh", refreshHandler)
	g.Post("/logout", logoutHandler)
}

func loginHandler(c *fiber.Ctx) error {
	var req loginReq
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid body")
	}

	var user models.User
	err := usersColl().FindOne(c.Context(), bson.M{"email": req.Email}).Decode(&user)
	if err != nil {
		// DEBUG: distinguish not found vs other errors
		// NOTE: mongo.ErrNoDocuments lives in the mongo package; but we don't need to branch specifically here
		log.Println("login error:", err)
		return fiber.NewError(fiber.StatusUnauthorized, "invalid credentials")
	}
	if user.PasswordHash == "" {
		log.Println("login: user has no password_hash set", req.Email)
		return fiber.NewError(fiber.StatusUnauthorized, "invalid credentials")
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)) != nil {
		log.Println("login: bcrypt mismatch for", req.Email)
		return fiber.NewError(fiber.StatusUnauthorized, "invalid credentials")
	}

	access, err := signAccess(user)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "sign access failed")
	}
	refresh, err := signRefresh(user)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "sign refresh failed")
	}
	setRefreshCookie(c, refresh)

	return c.JSON(loginResp{User: user, AccessToken: access})
}

func meHandler(c *fiber.Ctx) error {
	auth := c.Get("Authorization")
	if auth == "" || len(auth) < len("Bearer ")+1 {
		return fiber.NewError(fiber.StatusUnauthorized, "missing token")
	}
	tokenStr := auth[len("Bearer "):]
	claims := jwt.MapClaims{}
	t, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) { return jwtSecret(), nil })
	if err != nil || !t.Valid {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid token")
	}
	email, _ := claims["email"].(string)
	var user models.User
	if err := usersColl().FindOne(c.Context(), bson.M{"email": email}).Decode(&user); err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "user not found")
	}
	return c.JSON(user)
}

func refreshHandler(c *fiber.Ctx) error {
	rt := c.Cookies("refresh_token")
	if rt == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "no refresh")
	}
	claims := jwt.MapClaims{}
	t, err := jwt.ParseWithClaims(rt, claims, func(t *jwt.Token) (interface{}, error) { return jwtSecret(), nil })
	if err != nil || !t.Valid || claims["typ"] != "refresh" {
		return fiber.NewError(fiber.StatusUnauthorized, "bad refresh")
	}
	sub, ok := claims["sub"].(float64) // JWT numbers become float64
	if !ok {
		return fiber.NewError(fiber.StatusUnauthorized, "bad sub")
	}
	var user models.User
	if err := usersColl().FindOne(c.Context(), bson.M{"id": int(sub)}).Decode(&user); err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "user not found")
	}
	access, err := signAccess(user)
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "re-sign failed")
	}
	return c.JSON(fiber.Map{"accessToken": access})
}

func logoutHandler(c *fiber.Ctx) error {
	clearRefreshCookie(c)
	return c.JSON(fiber.Map{"ok": true})
}