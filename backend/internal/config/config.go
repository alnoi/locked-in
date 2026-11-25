package config

import (
	"fmt"
	"net"
	"time"

	"github.com/caarlos0/env/v11"
)

type Server struct {
	TrustedProxies  []string      `env:"SERVER_TRUSTED_PROXIES" envSeparator:","`
	Address         string        `env:"SERVER_ADDRESS,required"`
	RequestTimeout  time.Duration `env:"SERVER_REQUEST_TIMEOUT,required"`
	ShutdownTimeout time.Duration `env:"SERVER_SHUTDOWN_TIMEOUT,required"`
	MaxBodyBytes    int64         `env:"SERVER_MAX_BODY_BYTES,required"`
}
type Postgres struct {
	Schema          string        `env:"POSTGRES_SCHEMA,required"`
	Host            string        `env:"POSTGRES_HOST,required"`
	Port            uint16        `env:"POSTGRES_PORT,required"`
	Database        string        `env:"POSTGRES_DATABASE,required"`
	User            string        `env:"POSTGRES_USER,required"`
	Password        string        `env:"POSTGRES_PASSWORD,required"`
	SSLMode         string        `env:"POSTGRES_SSLMODE,required"`
	MaxConns        int32         `env:"POSTGRES_MAX_CONNS,required"`
	MinConns        int32         `env:"POSTGRES_MIN_CONNS,required"`
	MaxConnLifetime time.Duration `env:"POSTGRES_MAX_CONN_LIFETIME,required"`
	MaxConnIdleTime time.Duration `env:"POSTGRES_MAX_CONN_IDLE_TIME,required"`
	ConnectTimeout  time.Duration `env:"POSTGRES_CONNECT_TIMEOUT,required"`
}
type LocalUser struct {
	Username string `env:"LOCAL_USER_NAME,required"`
	TimeZone string `env:"LOCAL_USER_TIME_ZONE,required"`
}
type Config struct {
	Server         Server
	Postgres       Postgres
	LocalUser      LocalUser
	MigrationsPath string `env:"MIGRATIONS_PATH,required"`
	LogLevel       string `env:"LOG_LEVEL,required"`
}

func LoadFromEnv() (Config, error) {
	var result Config
	if err := env.Parse(&result); err != nil {
		return result, fmt.Errorf("LoadFromEnv: %w", err)
	}
	if err := result.Validate(); err != nil {
		return result, err
	}
	return result, nil
}
func (c Config) Validate() error {
	host, _, err := net.SplitHostPort(c.Server.Address)
	if err != nil {
		return fmt.Errorf("Validate: server address must include a loopback IP and port")
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("Validate: local mode requires a loopback IP")
	}
	if c.Server.RequestTimeout <= 0 || c.Server.ShutdownTimeout <= 0 || c.Server.MaxBodyBytes <= 0 {
		return fmt.Errorf("Validate: invalid server limits")
	}
	if c.Postgres.MaxConns < 1 || c.Postgres.MinConns < 0 || c.Postgres.MinConns > c.Postgres.MaxConns || c.Postgres.ConnectTimeout <= 0 {
		return fmt.Errorf("Validate: invalid PostgreSQL limits")
	}
	if _, err := time.LoadLocation(c.LocalUser.TimeZone); err != nil {
		return fmt.Errorf("Validate: invalid user time zone")
	}
	if c.LocalUser.Username == "" {
		return fmt.Errorf("Validate: empty local username")
	}
	return nil
}
