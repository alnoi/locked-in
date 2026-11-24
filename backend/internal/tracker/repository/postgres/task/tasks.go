package task

import (
	"context"
	"errors"
	"fmt"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/alnoi/locked-in/backend/pkg/transaction_manager"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type Repository struct{ getter *transaction_manager.Getter }

func New(getter *transaction_manager.Getter) *Repository { return &Repository{getter: getter} }
func (r *Repository) GetTasks(ctx context.Context, filters models.GetTasksFilters) ([]models.Task, error) {
	query, args := selectQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return nil, fmt.Errorf("GetTasks: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return nil, fmt.Errorf("GetTasks: %w", err)
	}
	return entitiesToModels(values), nil
}
func (r *Repository) GetTasksCount(ctx context.Context, filters models.GetTasksFilters) (int, error) {
	query, args := countQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return 0, fmt.Errorf("GetTasksCount: %w", err)
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowTo[int])
	if err != nil {
		return 0, fmt.Errorf("GetTasksCount: %w", err)
	}
	return value, nil
}
func (r *Repository) CreateTask(ctx context.Context, in *models.CreateTaskIn) (models.Task, error) {
	args := pgx.NamedArgs{"is_project": in.IsProject, "id": in.ID, "owner_id": in.OwnerID, "title": in.Title, "description": in.Description, "list_id": in.ListID, "parent_id": in.ParentID, "deadline_date": in.DeadlineDate, "deadline_at": in.DeadlineAt, "planned_at": in.PlannedAt, "reminder_mode": in.ReminderMode, "reminder_minutes_before": in.ReminderMinutesBefore, "duration_minutes": in.DurationMinutes}
	return r.write(ctx, createQuery, args)
}
func (r *Repository) UpdateTask(ctx context.Context, scope *uuid.UUID, in *models.UpdateTaskIn) (models.Task, error) {
	args := pgx.NamedArgs{"is_project": in.IsProject, "id": in.ID, "scope": scope, "title": in.Title, "description": in.Description, "list_id": in.ListID, "parent_id": in.ParentID, "deadline_date": in.DeadlineDate, "deadline_at": in.DeadlineAt, "planned_at": in.PlannedAt, "reminder_mode": in.ReminderMode, "reminder_minutes_before": in.ReminderMinutesBefore, "duration_minutes": in.DurationMinutes, "clear_description": in.ClearDescription, "clear_list_id": in.ClearListID, "clear_parent_id": in.ClearParentID, "clear_deadline_date": in.ClearDeadlineDate, "clear_deadline_at": in.ClearDeadlineAt, "clear_planned_at": in.ClearPlannedAt, "clear_duration_minutes": in.ClearDurationMinutes}
	return r.write(ctx, updateQuery, args)
}
func (r *Repository) SoftDeleteTask(ctx context.Context, filters models.DeleteTaskFilters) (int64, error) {
	if filters.ID == nil || filters.Scope == nil {
		return 0, nil
	}
	tag, err := r.getter.Get(ctx).Exec(ctx, deleteQuery, pgx.NamedArgs{"id": filters.ID, "scope": filters.Scope})
	if err != nil {
		return 0, fmt.Errorf("SoftDeleteTask: %w", apperr.HandleConstraintViolation(err))
	}
	return tag.RowsAffected(), nil
}
func (r *Repository) write(ctx context.Context, query string, args pgx.NamedArgs) (models.Task, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return models.Task{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[entity])
	if errors.Is(err, pgx.ErrNoRows) {
		return models.Task{}, apperr.ErrNotFound()
	}
	if err != nil {
		return models.Task{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	return entityToModel(value), nil
}
func (r *Repository) SetTaskCompleted(ctx context.Context, scope *uuid.UUID, in *models.SetTaskCompletedIn) (models.Task, error) {
	return r.write(ctx, completeQuery, pgx.NamedArgs{"scope": scope, "id": in.ID, "completed": in.Completed})
}

func (r *Repository) RestoreTask(ctx context.Context, scope *uuid.UUID, id uuid.UUID) error {
	if scope == nil {
		return apperr.ErrNotFound()
	}
	tag, err := r.getter.Get(ctx).Exec(ctx, restoreQuery, pgx.NamedArgs{"id": id, "scope": scope})
	if err != nil {
		return fmt.Errorf("RestoreTask: %w", apperr.HandleConstraintViolation(err))
	}
	if tag.RowsAffected() == 0 {
		return apperr.ErrNotFound()
	}
	return nil
}
