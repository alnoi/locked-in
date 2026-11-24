package http

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	apphttp "github.com/alnoi/locked-in/backend/internal/app/http"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/gin-gonic/gin"
)

type AuthHandlers struct {
	authentication authenticationUseCase
	profile        profileUseCase
	limiter        *authLimiter
}

func New(authentication authenticationUseCase, profile profileUseCase) *AuthHandlers {
	return &AuthHandlers{authentication: authentication, profile: profile, limiter: newAuthLimiter()}
}
func (h *AuthHandlers) Register(c *gin.Context) {
	var request tracker_genapi.RegisterIn
	if err := apphttp.DecodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapRegistration(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.authentication.Register(c.Request.Context(), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.Header("Cache-Control", "no-store")
	c.JSON(201, mapAuthentication(out))
}
func (h *AuthHandlers) Login(c *gin.Context) {
	var request tracker_genapi.LoginIn
	if err := apphttp.DecodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in := mapLogin(request)
	out, err := h.authentication.Login(c.Request.Context(), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.Header("Cache-Control", "no-store")
	c.JSON(200, mapAuthentication(out))
}
func (h *AuthHandlers) GetMe(c *gin.Context) {
	out, err := h.profile.GetMe(c.Request.Context(), h.Actor(c))
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.Header("Cache-Control", "no-store")
	c.JSON(200, mapUser(out))
}
func (h *AuthHandlers) UpdateProfile(c *gin.Context) {
	var request tracker_genapi.UpdateProfileIn
	if err := apphttp.DecodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in := models.UpdateProfileIn{AvatarEmoji: request.AvatarEmoji}
	out, err := h.profile.UpdateProfile(c.Request.Context(), h.Actor(c), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapUser(out))
}
func (h *AuthHandlers) Logout(c *gin.Context) {
	if err := h.profile.Logout(c.Request.Context(), h.Actor(c)); err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.Status(204)
}
func (h *AuthHandlers) Actor(c *gin.Context) models.Actor {
	value, exists := c.Get("identity.session")
	if !exists {
		return models.Actor{}
	}
	session, valid := value.(models.AuthenticatedSession)
	if !valid {
		return models.Actor{}
	}
	return models.Actor{UserID: session.User.ID, SessionID: session.SessionID}
}
