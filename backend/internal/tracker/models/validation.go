package models

import (
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/google/uuid"
)

var colorPattern = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

func ValidateName(value string) error {
	if strings.TrimSpace(value) == "" || utf8.RuneCountInString(value) > 300 {
		return apperr.ErrValidation()
	}
	return nil
}
func ValidateColor(value *string) error {
	if value != nil && !colorPattern.MatchString(*value) {
		return apperr.ErrValidation()
	}
	return nil
}
func ValidateTask(task Task) error {
	mode, err := ParseReminderMode(string(task.ReminderMode))
	if err != nil {
		return err
	}
	if task.ReminderMinutesBefore < 0 || task.ReminderMinutesBefore > 10080 {
		return apperr.ErrValidation()
	}
	if mode == ReminderModeAlarm && task.PlannedAt == nil && task.DeadlineAt == nil {
		return apperr.ErrValidation()
	}
	if mode != ReminderModeNone && task.DeadlineAt == nil && task.DeadlineDate == nil && task.PlannedAt == nil {
		return apperr.ErrValidation()
	}

	if err := ValidateName(task.Title); err != nil {
		return err
	}
	if task.DeadlineDate != nil && task.DeadlineAt != nil {
		return apperr.ErrValidation()
	}
	if task.DeadlineDate != nil {
		if _, err := time.Parse(time.DateOnly, *task.DeadlineDate); err != nil {
			return apperr.ErrValidation()
		}
	}
	return nil
}
func ValidateComment(value string) error {
	if strings.TrimSpace(value) == "" || utf8.RuneCountInString(value) > 20000 {
		return apperr.ErrValidation()
	}
	return nil
}
func ValidateIDs(values []uuid.UUID) error {
	seen := map[uuid.UUID]struct{}{}
	for _, id := range values {
		if id == uuid.Nil {
			return apperr.ErrValidation()
		}
		if _, exists := seen[id]; exists {
			return apperr.ErrValidation()
		}
		seen[id] = struct{}{}
	}
	return nil
}
func ValidatePagination(limit, offset *int) error {
	if limit != nil && (*limit < 1 || *limit > 1000) {
		return apperr.ErrValidation()
	}
	if offset != nil && *offset < 0 {
		return apperr.ErrValidation()
	}
	return nil
}
