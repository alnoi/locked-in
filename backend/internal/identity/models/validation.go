package models

import (
	"regexp"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
)

var usernamePattern = regexp.MustCompile(`^[a-z0-9_][a-z0-9_.-]{2,31}$`)

func NormalizeUsername(value string) string { return strings.ToLower(strings.TrimSpace(value)) }
func ValidateCredentials(in CredentialsIn) error {
	if !usernamePattern.MatchString(in.Username) {
		return apperr.ErrInvalidUsername()
	}
	if utf8.RuneCountInString(in.Password) < 8 || len(in.Password) > 256 {
		return apperr.ErrInvalidPassword()
	}
	return nil
}
func ValidateRegistration(in CredentialsIn) error {
	if err := ValidateCredentials(in); err != nil {
		return err
	}
	if _, err := time.LoadLocation(in.TimeZone); err != nil {
		return apperr.ErrInvalidTimeZone()
	}
	return ValidateAvatar(in.AvatarEmoji)
}
func ValidateAvatar(value string) error {
	if len(value) > 128 {
		return apperr.ErrInvalidAvatar()
	}
	for _, character := range value {
		if unicode.IsControl(character) || unicode.IsSpace(character) {
			return apperr.ErrInvalidAvatar()
		}
	}
	return nil
}
