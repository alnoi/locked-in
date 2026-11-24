package http

import (
	"errors"
	"strings"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/gin-gonic/gin"
)

func (h *AuthHandlers) Authenticate() gin.HandlerFunc {
	return func(c *gin.Context) {
		path := c.Request.URL.Path
		if c.Request.Method == "GET" && (path == "/livez" || path == "/readyz") {
			c.Next()
			return
		}
		if c.Request.Method == "POST" && (path == "/api/v1/auth/login" || path == "/api/v1/auth/register") {
			if !h.limiter.allow(c.ClientIP()) {
				c.Header("Retry-After", "60")
				apperr.WriteError(c, apperr.ErrRateLimited())
				return
			}
			c.Next()
			return
		}
		report := c.Request.Method == "POST" && path == "/api/v1/bug-reports"
		if report && !h.limiter.allow("report:"+c.ClientIP()) {
			c.Header("Retry-After", "60")
			apperr.WriteError(c, apperr.ErrRateLimited())
			return
		}
		parts := strings.Fields(c.GetHeader("Authorization"))
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			if report {
				c.Next()
				return
			}
			apperr.WriteError(c, apperr.ErrUnauthorized())
			return
		}
		session, err := h.authentication.Authenticate(c.Request.Context(), parts[1])
		var unauthorized *apperr.Error
		if report && errors.As(err, &unauthorized) && unauthorized.Code == apperr.CodeUnauthorized {
			c.Next()
			return
		}
		if err != nil {
			apperr.WriteError(c, err)
			return
		}
		c.Set("identity.session", session)
		c.Header("Cache-Control", "no-store")
		c.Next()
	}
}
