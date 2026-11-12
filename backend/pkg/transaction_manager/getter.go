package transaction_manager

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Postgres interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
	Query(context.Context, string, ...any) (pgx.Rows, error)
}
type Getter struct{ pool *pgxpool.Pool }

func NewGetter(pool *pgxpool.Pool) *Getter { return &Getter{pool: pool} }
func (g *Getter) Get(ctx context.Context) Postgres {
	if transaction, ok := ctx.Value(transactionKey{}).(pgx.Tx); ok {
		return transaction
	}
	return g.pool
}
