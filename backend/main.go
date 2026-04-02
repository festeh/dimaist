package main

import (
	"flag"
	"fmt"
	"net/http"

	"dimaist/ai"
	"dimaist/calendar"
	"dimaist/database"
	_ "dimaist/docs"
	"dimaist/env"
	"dimaist/logger"
	"dimaist/middleware"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"github.com/joho/godotenv"
	httpSwagger "github.com/swaggo/http-swagger/v2"
)

var appEnv *env.Env

// @title Dimaist API
// @version 1.0
// @description Task management REST API
// @host localhost:3000
// @BasePath /
func main() {
	port := flag.String("port", "3000", "Port to run the server on")
	verbose := flag.Bool("verbose", false, "Enable verbose logging (shows AI request bodies)")
	flag.Parse()

	err := godotenv.Load()
	if err != nil {
		fmt.Printf("Warning: Error loading .env file, using environment variables: %v\n", err)
	}

	appEnv, err = env.New()
	if err != nil {
		fmt.Printf("Error: Failed to initialize environment: %v\n", err)
		return
	}

	ai.SetEnv(appEnv)
	calendar.SetEnv(appEnv)

	logger.InitLogger(appEnv.LogLevel, appEnv.LogFormat, *verbose)

	if *verbose {
		logger.Debug("Verbose mode enabled - debug logs will be shown").Send()
	}

	err = database.InitDB(appEnv.DatabaseURL)
	if err != nil {
		logger.Error("Unable to connect to database").Err(err).Send()
		return
	}

	r := chi.NewRouter()
	r.Use(middleware.LoggingMiddleware)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("welcome"))
	})

	r.Route("/tasks", func(r chi.Router) {
		r.Get("/", listTasks)
		r.Post("/", createTask)
		r.Route("/{taskID}", func(r chi.Router) {
			r.Get("/", getTask)
			r.Put("/", updateTask)
			r.Delete("/", deleteTask)
			r.Post("/complete", completeTask)
		})
	})

	r.Route("/projects", func(r chi.Router) {
		r.Get("/", listProjects)
		r.Post("/", createProject)
		r.Route("/{projectID}", func(r chi.Router) {
			r.Put("/tasks/reorder", reorderTasks)
			r.Put("/", updateProject)
			r.Delete("/", deleteProject)
		})
	})

	r.Put("/projects-reorder", reorderProjects)
	r.Get("/ai", ai.HandleWebSocket)
	r.Get("/ai/models", ai.HandleModels)
	r.Get("/sync", syncData)
	r.Get("/find", findItems)
	r.Get("/swagger/*", httpSwagger.WrapHandler)

	logger.Info("Starting server").Str("port", *port).Send()
	err = http.ListenAndServe(":"+*port, r)
	if err != nil {
		logger.Error("Server failed to start").Err(err).Send()
	}
}
