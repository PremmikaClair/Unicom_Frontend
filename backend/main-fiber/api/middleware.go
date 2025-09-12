package api

import (
    "github.com/gofiber/fiber/v2"
    "github.com/golang-jwt/jwt/v5"
)

func RequireAuth() fiber.Handler {
	return func(c *fiber.Ctx) error {
		auth := c.Get("Authorization")
		if auth == "" || len(auth) < 8 {
			return fiber.NewError(fiber.StatusUnauthorized, "missing token")
		}
		tokenStr := auth[len("Bearer "):]
		claims := jwt.MapClaims{}
		t, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) { return jwtSecret(), nil })
		if err != nil || !t.Valid {
			return fiber.NewError(fiber.StatusUnauthorized, "invalid token")
		}
		c.Locals("claims", claims)
		return c.Next()
	}
}

// Simple role check using the "roles" claim (array of strings)
func RequireRole(role string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		claims, ok := c.Locals("claims").(jwt.MapClaims)
		if !ok {
			return fiber.NewError(fiber.StatusUnauthorized, "no claims")
		}
		roles, _ := claims["roles"].([]interface{})
		for _, r := range roles {
			if rs, _ := r.(string); rs == role {
				return c.Next()
			}
		}
		return fiber.NewError(fiber.StatusForbidden, "forbidden")
	}
}


// RequireAbility enforces a single action at an org path (taken from route param by name).
// Example: app.Post("/org/:path/members", RequireAbility("membership:assign", "path"), handler)
func RequireAbility(action, orgParam string) fiber.Handler {
    return func(c *fiber.Ctx) error {
        uid, err := userIDFromBearer(c)
        if err != nil { return err }
        org := c.Params(orgParam)
        if org == "" { org = c.Query("org_path") }
        ok, err := Can(c.Context(), uid, action, org)
        if err != nil { return fiber.ErrInternalServerError }
        if !ok { return fiber.ErrForbidden }
        return c.Next()
    }
}
