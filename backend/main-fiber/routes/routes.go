package routes

import (
	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/api"
)

// SetupRoutes initializes all API routes
func SetupRoutes(app *fiber.App) {
	api := app.Group("/api")

	// Register user routes under /api
	user.RegisterUserRoutes(api)
}