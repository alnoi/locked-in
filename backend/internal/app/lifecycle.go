package app

import (
	"context"
	"errors"
	"net/http"

	"go.uber.org/zap"
)

func (a *App) Run(ctx context.Context) error {
	defer a.Close()
	failures := make(chan error, 1)
	go func() { failures <- a.server.ListenAndServe() }()
	a.logger.Info("server started", zap.String("address", a.server.Addr))
	select {
	case err := <-failures:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		a.ready.Store(false)
		shutdownContext, cancel := context.WithTimeout(context.WithoutCancel(ctx), a.shutdownTimeout)
		defer cancel()
		if err := a.server.Shutdown(shutdownContext); err != nil {
			return errors.Join(err, a.server.Close())
		}
		return nil
	}
}
