package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"time"

	"github.com/alnoi/locked-in/backend/internal/app"
	"github.com/alnoi/locked-in/backend/internal/config"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
)

func main() {
	settings, err := config.LoadFromEnv()
	if err != nil {
		log.Fatal(err)
	}
	var in models.CredentialsIn
	decoder := json.NewDecoder(io.LimitReader(os.Stdin, 4096))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&in); err != nil {
		log.Fatal("Invalid profile input")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	user, err := app.ClaimLegacyProfile(ctx, settings, &in)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Profile ready: %s (%s)\n", user.Username, user.ID)
}
