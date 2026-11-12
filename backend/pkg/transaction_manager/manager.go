package transaction_manager

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type transactionKey struct{}
type Manager struct{ pool *pgxpool.Pool }

func NewManager(pool *pgxpool.Pool) *Manager { return &Manager{pool: pool} }
func (m *Manager) WithinTransaction(ctx context.Context, action func(context.Context) error) (result error) {
	if _, ok := ctx.Value(transactionKey{}).(pgx.Tx); ok {
		return action(ctx)
	}
	transaction, err := m.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("WithinTransaction: %w", err)
	}
	defer func() {
		rollbackContext, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
		defer cancel()
		rollbackError := transaction.Rollback(rollbackContext)
		if rollbackError != nil && !errors.Is(rollbackError, pgx.ErrTxClosed) {
			result = errors.Join(result, fmt.Errorf("WithinTransaction: %w", rollbackError))
		}
	}()
	if err := action(context.WithValue(ctx, transactionKey{}, transaction)); err != nil {
		return err
	}
	if err := transaction.Commit(ctx); err != nil {
		return fmt.Errorf("WithinTransaction: %w", err)
	}
	return nil
}
