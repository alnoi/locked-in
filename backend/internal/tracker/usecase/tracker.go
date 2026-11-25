package usecase

import (
	"context"

	"github.com/google/uuid"
)

type Dependencies struct {
	TaskOrders   taskOrderRepository
	Boards       boardRepository
	Lists        listRepository
	Tags         tagRepository
	Tasks        taskRepository
	Comments     commentRepository
	Links        linksRepository
	Transactions transactionManager
}
type UseCase struct{ dependencies Dependencies }

func New(dependencies Dependencies) *UseCase { return &UseCase{dependencies: dependencies} }
func (u *UseCase) mutate(ctx context.Context, scope *uuid.UUID, action func(context.Context) error) error {
	return u.dependencies.Transactions.WithinTransaction(ctx, func(ctx context.Context) error {
		if err := u.dependencies.Links.LockOwner(ctx, scope); err != nil {
			return err
		}
		return action(ctx)
	})
}
