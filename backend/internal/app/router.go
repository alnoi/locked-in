package app

import (
	"context"
	"sync/atomic"

	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	apphttp "github.com/alnoi/locked-in/backend/internal/app/http"
	"github.com/alnoi/locked-in/backend/internal/config"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

func newRouter(logger *zap.Logger, settings config.Server, pool *pgxpool.Pool, handlers tracker_genapi.ServerInterface, ready *atomic.Bool) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	if err := router.SetTrustedProxies(nil); err != nil {
		logger.Fatal("configure trusted proxies", zap.Error(err))
	}
	apphttp.Configure(router, logger, settings)
	router.GET("/livez", func(c *gin.Context) { c.Status(204) })
	router.GET("/readyz", func(c *gin.Context) {
		if !ready.Load() {
			c.Status(503)
			return
		}
		ctx, cancel := context.WithTimeout(c.Request.Context(), settings.RequestTimeout)
		defer cancel()
		if err := pool.Ping(ctx); err != nil {
			c.Status(503)
			return
		}
		c.Status(204)
	})
	router.NoRoute(func(c *gin.Context) { apperr.WriteError(c, apperr.ErrNotFound()) })
	tracker_genapi.RegisterHandlersWithOptions(router, handlers, tracker_genapi.GinServerOptions{ErrorHandler: func(c *gin.Context, _ error, _ int) { apperr.WriteError(c, apperr.ErrValidation()) }})
	return router
}
