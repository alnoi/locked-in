package app

import (
	"sync/atomic"

	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/config"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type routerDependencies struct {
	logger       *zap.Logger
	settings     config.Server
	pool         *pgxpool.Pool
	handlers     tracker_genapi.ServerInterface
	authenticate gin.HandlerFunc
	ready        *atomic.Bool
}
