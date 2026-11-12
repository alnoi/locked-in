package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/alnoi/locked-in/backend/internal/app"
	"github.com/alnoi/locked-in/backend/internal/config"
)

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	settings, err := config.LoadFromEnv()
	if err != nil {
		log.Fatal(err)
	}
	application, err := app.New(ctx, settings)
	if err != nil {
		log.Fatal(err)
	}
	if err := application.Run(ctx); err != nil {
		log.Fatal(err)
	}
}
