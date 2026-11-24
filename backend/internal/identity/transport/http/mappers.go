package http

import (
	"github.com/AlekSi/pointer"
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
)

func mapUser(value models.User) tracker_genapi.UserOut {
	return tracker_genapi.UserOut{Id: value.ID, Username: value.Username, TimeZone: value.TimeZone, AvatarEmoji: value.AvatarEmoji, CreatedAt: value.CreatedAt}
}
func mapAuthentication(value models.Authentication) tracker_genapi.AuthenticationOut {
	return tracker_genapi.AuthenticationOut{User: mapUser(value.User), AccessToken: value.AccessToken, ExpiresAt: value.ExpiresAt}
}
func mapRegistration(value tracker_genapi.RegisterIn) (models.CredentialsIn, error) {
	in := models.CredentialsIn{Username: models.NormalizeUsername(value.Username), Password: value.Password, TimeZone: value.TimeZone, AvatarEmoji: pointer.Get(value.AvatarEmoji)}
	return in, models.ValidateRegistration(in)
}
func mapLogin(value tracker_genapi.LoginIn) models.CredentialsIn {
	return models.CredentialsIn{Username: models.NormalizeUsername(value.Username), Password: value.Password}
}
