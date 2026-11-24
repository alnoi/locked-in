package domain

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
)

func NewToken() (models.Token, error) {
	value := make([]byte, 32)
	if _, err := rand.Read(value); err != nil {
		return models.Token{}, fmt.Errorf("NewToken: %w", err)
	}
	raw := base64.RawURLEncoding.EncodeToString(value)
	hash := sha256.Sum256([]byte(raw))
	return models.Token{Raw: raw, Hash: hash[:]}, nil
}
func TokenHash(value string) ([]byte, error) {
	decoded, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil || len(decoded) != 32 || len(value) != 43 {
		return nil, apperr.ErrUnauthorized()
	}
	hash := sha256.Sum256([]byte(value))
	return hash[:], nil
}
