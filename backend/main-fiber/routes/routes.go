package routes

import (
	"github.com/gofiber/fiber/v2"
	"github.com/pllus/main-fiber/api"
)

func SetupRoutes(app *fiber.App) {
	apiGroup := app.Group("/api")

	api.RegisterUserRoutes(apiGroup)
	api.RegisterPostRoutes(apiGroup)
}