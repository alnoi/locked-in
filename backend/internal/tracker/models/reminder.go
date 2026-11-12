package models

import "github.com/alnoi/locked-in/backend/internal/app/apperr"

type ReminderMode string

const (
	ReminderModeNone         ReminderMode = "none"
	ReminderModeNotification ReminderMode = "notification"
	ReminderModeAlarm        ReminderMode = "alarm"
)

func ParseReminderMode(value string) (ReminderMode, error) {
	mode := ReminderMode(value)
	if mode == "" {
		mode = ReminderModeNone
	}
	switch mode {
	case ReminderModeNone, ReminderModeNotification, ReminderModeAlarm:
		return mode, nil
	}
	return "", apperr.ErrValidation()
}
