package http

import (
	"context"
	"io"
	"net/http"
	"time"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/config"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

func Configure(router *gin.Engine, logger *zap.Logger, settings config.Server) {
	router.Use(func(c *gin.Context) {
		started := time.Now()
		requestID := uuid.NewString()
		c.Set("logger", logger.With(zap.String("requestID", requestID)))
		c.Header("X-Request-ID", requestID)
		c.Next()
		logger.Info("http request", zap.String("requestID", requestID), zap.String("method", c.Request.Method), zap.String("path", c.FullPath()), zap.Int("status", c.Writer.Status()), zap.Duration("duration", time.Since(started)))
	})
	router.Use(gin.CustomRecoveryWithWriter(io.Discard, func(c *gin.Context, recovered any) {
		logger.Error("http panic", zap.Any("panic", recovered))
		apperr.WriteError(c, apperr.ErrInternal())
	}))
	router.Use(func(c *gin.Context) {
		if c.GetHeader("Origin") != "" {
			apperr.WriteError(c, apperr.ErrUnauthorized())
			return
		}
		ctx, cancel := context.WithTimeout(c.Request.Context(), settings.RequestTimeout)
		defer cancel()
		c.Request = c.Request.WithContext(ctx)
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, settings.MaxBodyBytes)
		c.Next()
	})
}
