// api/auth.go
package api

import (
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/pllus/main-fiber/config"
	"github.com/pllus/main-fiber/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"golang.org/x/crypto/bcrypt"
)

func usersColl() *mongo.Collection { return config.DB.Collection("users") }
func jwtSecret() []byte            { return []byte(os.Getenv("JWT_SECRET")) }

// ---- payloads ----
type loginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}
type loginResp struct {
	AccessToken string `json:"access_token"`
}

// ---- routes ----
func RegisterAuthRoutes(r fiber.Router) {
	r.Post("/auth/login", loginHandler)
	// inside RegisterAuthRoutes
	r.Get("/auth/me", meHandler)

}

// POST /api/auth/login  -> { access_token }
// @Summary      Login
// @Description  Authenticates user and returns JWT access token
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        loginReq  body      loginReq  true  "Login credentials"
// @Success      200       {object}  loginResp
// @Router       /api/auth/login [post]
func loginHandler(c *fiber.Ctx) error {
	var req loginReq
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid body")
	}
	email := strings.TrimSpace(strings.ToLower(req.Email))
	if email == "" || req.Password == "" {
		return fiber.NewError(fiber.StatusBadRequest, "email and password required")
	}

	var u models.User
	if err := usersColl().FindOne(c.Context(), bson.M{"email": email}).Decode(&u); err != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid credentials")
	}
	if u.PasswordHash == "" || bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)) != nil {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid credentials")
	}

	// simple 24h token
	claims := jwt.MapClaims{
		"sub":   u.ID.Hex(),                 // ObjectID as string
		"email": u.Email,                    // for convenience
		"exp":   time.Now().Add(24 * time.Hour).Unix(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString(jwtSecret())
	if err != nil {
		return fiber.NewError(fiber.StatusInternalServerError, "sign failed")
	}

	return c.JSON(loginResp{AccessToken: signed})
}


// @Summary      Get current user info
// @Description  Returns claims of the authenticated user
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        Authorization  header    string  true  "Bearer JWT token"
// @Success      200           {object}  map[string]interface{}
// @Router       /api/auth/me [get]
func meHandler(c *fiber.Ctx) error {
    auth := c.Get("Authorization")
    if !strings.HasPrefix(auth, "Bearer ") {
        return fiber.NewError(fiber.StatusUnauthorized, "missing token")
    }
    tokenStr := strings.TrimPrefix(auth, "Bearer ")
    claims := jwt.MapClaims{}
    t, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) { return jwtSecret(), nil })
    if err != nil || !t.Valid {
        return fiber.NewError(fiber.StatusUnauthorized, "invalid token")
    }
    return c.JSON(claims) // just dump claims for now
}