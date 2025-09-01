// @title My API
// @version 1.0
// @description This is my API
// @BasePath /api

package main

import (
	"log"
	"os"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/swagger"
	"github.com/gofiber/fiber/v2/middleware/cors"

	_ "github.com/pllus/main-fiber/docs"

	"github.com/pllus/main-fiber/api"
	"github.com/pllus/main-fiber/config"
)

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	app := fiber.New()

	// Allow one or more specific origins (comma-separated).
	// Example dev: FRONTEND_ORIGINS=http://localhost:5173
	allowed := getEnv("FRONTEND_ORIGINS", "http://localhost:5173")

	app.Use(cors.New(cors.Config{
		AllowOrigins:     strings.Join(strings.Split(allowed, ","), ","),
		AllowMethods:     "GET,POST,PUT,DELETE,OPTIONS",
		AllowHeaders:     "Origin, Content-Type, Accept, Authorization",
		ExposeHeaders:    "Authorization",
		AllowCredentials: true, // <- required when using cookies
	}))

	config.ConnectMongo()

	// Health
	app.Get("/healthz", func(c *fiber.Ctx) error { return c.SendString("ok") })

	// Group all API under /api
	apiGroup := app.Group("/api")

	// Auth routes (added below)
	api.RegisterAuthRoutes(apiGroup)

	// Existing feature routes
	api.RegisterUserRoutes(apiGroup)
	api.RegisterRoleRoutes(apiGroup)

	// Swagger after routes
	app.Get("/docs/*", swagger.HandlerDefault)

	port := getEnv("PORT", "3000")
	log.Fatal(app.Listen(":" + port))
}