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
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/swagger"

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

	// CORS
	allowed := getEnv("FRONTEND_ORIGINS", "http://localhost:5173")
	app.Use(cors.New(cors.Config{
		AllowOrigins:     strings.Join(strings.Split(allowed, ","), ","),
		AllowMethods:     "GET,POST,PUT,DELETE,PATCH,OPTIONS",
		AllowHeaders:     "Origin, Content-Type, Accept, Authorization",
		ExposeHeaders:    "Authorization",
		AllowCredentials: true,
	}))

	// DB
	config.ConnectMongo()

	// Health
	app.Get("/healthz", func(c *fiber.Ctx) error { return c.SendString("ok") })

	// API group
	apiGroup := app.Group("/api")

	// Auth
	api.RegisterAuthRoutes(apiGroup)
	

	// Existing (keep)
	api.RegisterUserRoutes(apiGroup)

	// 🔄 REPLACE old roles route with positions + policies
	// REMOVE: api.RegisterRoleRoutes(apiGroup)
	api.RegisterPositionRoutes(apiGroup) // /positions CRUD (catalog of roles)
	api.RegisterPolicyRoutes(apiGroup)   // /policies CRUD (permission rules)

	// 🆕 Posts (backward compatible model + new fields)
	api.RegisterPostRoutes(apiGroup) // /posts


	api.RegisterOrgRoutes(apiGroup)

	// after other feature routes
	api.RegisterMembershipRoutes(apiGroup)
	api.RegisterOrgAdminRoutes(apiGroup) // CRUD for org nodes (node-level)
	// Swagger
	app.Get("/docs/*", swagger.HandlerDefault)

	port := getEnv("PORT", "3000")
	log.Fatal(app.Listen(":" + port))
}