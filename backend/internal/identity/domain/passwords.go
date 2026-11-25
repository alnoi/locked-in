package domain

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"strings"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"golang.org/x/crypto/argon2"
)

func HashPassword(password string) (string, error) {
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("HashPassword: %w", err)
	}
	hash := argon2.IDKey([]byte(password), salt, 3, 64*1024, 1, 32)
	return "$argon2id$v=19$m=65536,t=3,p=1$" + base64.RawStdEncoding.EncodeToString(salt) + "$" + base64.RawStdEncoding.EncodeToString(hash), nil
}
func VerifyPassword(encoded, password string) error {
	if encoded == "" {
		salt := make([]byte, 16)
		_ = argon2.IDKey([]byte(password), salt, 3, 64*1024, 1, 32)
		return apperr.ErrInvalidCredentials()
	}
	parts := strings.Split(encoded, "$")
	if len(parts) != 6 || parts[1] != "argon2id" || parts[2] != "v=19" || parts[3] != "m=65536,t=3,p=1" {
		return apperr.ErrInvalidCredentials()
	}
	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil || len(salt) != 16 {
		return apperr.ErrInvalidCredentials()
	}
	expected, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil || len(expected) != 32 {
		return apperr.ErrInvalidCredentials()
	}
	actual := argon2.IDKey([]byte(password), salt, 3, 64*1024, 1, 32)
	if subtle.ConstantTimeCompare(actual, expected) != 1 {
		return apperr.ErrWrongPassword()
	}
	return nil
}
