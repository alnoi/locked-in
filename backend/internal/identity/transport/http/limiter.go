package http

import (
	"sync"
	"time"
)

type authAttempts struct {
	started time.Time
	count   int
}
type authLimiter struct {
	mutex   sync.Mutex
	entries map[string]authAttempts
}

func newAuthLimiter() *authLimiter { return &authLimiter{entries: make(map[string]authAttempts)} }
func (l *authLimiter) allow(key string) bool {
	l.mutex.Lock()
	defer l.mutex.Unlock()
	now := time.Now()
	attempts := l.entries[key]
	if now.Sub(attempts.started) >= time.Minute {
		attempts = authAttempts{started: now}
	}
	if attempts.count >= 20 {
		return false
	}
	if len(l.entries) >= 4096 {
		for address, entry := range l.entries {
			if now.Sub(entry.started) >= time.Minute {
				delete(l.entries, address)
			}
		}
		if len(l.entries) >= 4096 {
			return false
		}
	}
	attempts.count++
	l.entries[key] = attempts
	return true
}
