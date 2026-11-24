package app

import (
	"context"
	"fmt"
	"net/http"
	"sync/atomic"
	"time"

	reportrepo "github.com/alnoi/locked-in/backend/internal/feedback/repository/postgres/report"
	reporthttp "github.com/alnoi/locked-in/backend/internal/feedback/transport/http"
	reportusecase "github.com/alnoi/locked-in/backend/internal/feedback/usecase"

	"github.com/alnoi/locked-in/backend/internal/config"
	identityrepo "github.com/alnoi/locked-in/backend/internal/identity/repository/postgres"
	sessionrepo "github.com/alnoi/locked-in/backend/internal/identity/repository/postgres/session"
	identityhttp "github.com/alnoi/locked-in/backend/internal/identity/transport/http"
	identityusecase "github.com/alnoi/locked-in/backend/internal/identity/usecase"
	boardrepo "github.com/alnoi/locked-in/backend/internal/tracker/repository/postgres/board"
	commentrepo "github.com/alnoi/locked-in/backend/internal/tracker/repository/postgres/comment"
	linksrepo "github.com/alnoi/locked-in/backend/internal/tracker/repository/postgres/links"
	listrepo "github.com/alnoi/locked-in/backend/internal/tracker/repository/postgres/list"
	tagrepo "github.com/alnoi/locked-in/backend/internal/tracker/repository/postgres/tag"
	taskrepo "github.com/alnoi/locked-in/backend/internal/tracker/repository/postgres/task"
	"github.com/alnoi/locked-in/backend/internal/tracker/transport/http/local"
	"github.com/alnoi/locked-in/backend/internal/tracker/usecase"
	"github.com/alnoi/locked-in/backend/pkg/transaction_manager"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type App struct {
	logger          *zap.Logger
	pool            *pgxpool.Pool
	server          *http.Server
	ready           atomic.Bool
	shutdownTimeout time.Duration
}

func New(ctx context.Context, settings config.Config) (*App, error) {
	if err := settings.Validate(); err != nil {
		return nil, err
	}
	loggerConfig := zap.NewProductionConfig()
	if err := loggerConfig.Level.UnmarshalText([]byte(settings.LogLevel)); err != nil {
		return nil, fmt.Errorf("New: %w", err)
	}
	logger, err := loggerConfig.Build()
	if err != nil {
		return nil, fmt.Errorf("New: %w", err)
	}
	pool, err := openDatabase(ctx, settings.Postgres)
	if err != nil {
		return nil, err
	}
	if err := migrate(ctx, pool, settings.MigrationsPath); err != nil {
		pool.Close()
		return nil, err
	}
	getter := transaction_manager.NewGetter(pool)
	transactions := transaction_manager.NewManager(pool)
	users := identityrepo.New(getter)
	boards := boardrepo.New(getter)
	lists := listrepo.New(getter)
	tags := tagrepo.New(getter)
	tasks := taskrepo.New(getter)
	comments := commentrepo.New(getter)
	links := linksrepo.New(getter)
	core := usecase.New(usecase.Dependencies{Boards: boards, Lists: lists, Tags: tags, Tasks: tasks, Comments: comments, Links: links, Transactions: transactions})
	authorized := usecase.NewAuthorized(core)
	sessions := sessionrepo.New(getter)
	identity := identityusecase.New(users, sessions, core, transactions)
	profiles := identityusecase.NewAuthorized(identity)
	authentication := identityhttp.New(identity, profiles)
	tracker := local.New(authorized, authentication.Actor)
	reports := reportrepo.New(getter)
	reportCore := reportusecase.New(reports)
	reportAuthorized := reportusecase.NewAuthorized(reportCore)
	feedback := reporthttp.New(reportAuthorized, authentication.Actor)
	handlers := struct {
		*local.Handlers
		*identityhttp.AuthHandlers
		*reporthttp.ReportHandlers
	}{tracker, authentication, feedback}
	application := &App{logger: logger, pool: pool, shutdownTimeout: settings.Server.ShutdownTimeout}
	application.ready.Store(true)
	router := newRouter(routerDependencies{logger: logger, settings: settings.Server, pool: pool, handlers: handlers, authenticate: authentication.Authenticate(), ready: &application.ready})
	application.server = &http.Server{Addr: settings.Server.Address, Handler: router, ReadHeaderTimeout: 5 * time.Second, ReadTimeout: settings.Server.RequestTimeout, WriteTimeout: settings.Server.RequestTimeout + time.Second, IdleTimeout: 60 * time.Second, MaxHeaderBytes: 1 << 20}
	return application, nil
}
func (a *App) Handler() http.Handler { return a.server.Handler }
func (a *App) Close()                { a.ready.Store(false); a.pool.Close() }
