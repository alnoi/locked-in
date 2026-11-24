package app

import (
	"context"

	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	apphttp "github.com/alnoi/locked-in/backend/internal/app/http"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func newRouter(dependencies routerDependencies) *gin.Engine {
	logger, settings, pool := dependencies.logger, dependencies.settings, dependencies.pool
	handlers, ready := dependencies.handlers, dependencies.ready
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	if err := router.SetTrustedProxies(nil); err != nil {
		logger.Fatal("configure trusted proxies", zap.Error(err))
	}
	apphttp.Configure(router, logger, settings)
	router.Use(dependencies.authenticate)
	router.GET("/livez", func(c *gin.Context) { c.Status(204) })
	router.GET("/readyz", func(c *gin.Context) {
		if !ready.Load() {
			apperr.WriteError(c, apperr.ErrUnavailable())
			return
		}
		ctx, cancel := context.WithTimeout(c.Request.Context(), settings.RequestTimeout)
		defer cancel()
		if err := pool.Ping(ctx); err != nil {
			apperr.WriteError(c, apperr.ErrUnavailable())
			return
		}
		c.Status(204)
	})
	router.HandleMethodNotAllowed = true
	router.NoMethod(func(c *gin.Context) { apperr.WriteError(c, apperr.ErrMethodNotAllowed()) })
	router.NoRoute(func(c *gin.Context) { apperr.WriteError(c, apperr.ErrNotFound()) })
	tracker_genapi.RegisterHandlersWithOptions(router, handlers, tracker_genapi.GinServerOptions{ErrorHandler: func(c *gin.Context, _ error, _ int) { apperr.WriteError(c, apperr.ErrValidation()) }})
	return router
}
