// @title My API
// @version 1.0
// @description This is my API
// @BasePath /api

package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/swagger"
	_ "github.com/pllus/main-fiber/docs" // <- Swagger docs import

	"github.com/pllus/main-fiber/config"
	"github.com/pllus/main-fiber/routes"

	"github.com/gofiber/fiber/v2/middleware/cors"
)

func main() {
	app := fiber.New()

	app.Use(cors.New(cors.Config{
		AllowOrigins: "http://localhost:5173",
		AllowMethods: "GET,POST,PUT,DELETE,OPTIONS",
	}))

	config.ConnectMongo()
	routes.SetupRoutes(app)

	// Swagger UI route — after routes setup
	app.Get("/docs/*", swagger.HandlerDefault)

	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}

	log.Fatal(app.Listen(":" + port))
}