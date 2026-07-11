package config

import (
	"fmt"
	"os"

	"github.com/jackc/pgx/v5"
	"gopkg.in/yaml.v3"
)

type TagEntry struct {
	Key   string `yaml:"key"`
	DBKey string `yaml:"db_key"`
}

type TagsConfig struct {
	Tags []TagEntry `yaml:"tags"`
}

func LoadTagsConfig(path string) (*TagsConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg TagsConfig
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parse tags.yaml: %w", err)
	}
	for i := range cfg.Tags {
		if cfg.Tags[i].DBKey == "" {
			cfg.Tags[i].DBKey = cfg.Tags[i].Key
		}
	}
	return &cfg, nil
}

// BuildConnConfig resolves Postgres connection settings.
//
// Preferred: DATABASE_URL — full Postgres URI, e.g.
//   postgres://user:pw@host:5432/db?sslmode=verify-full&sslrootcert=/etc/pg-certs/ca.crt
//
// Fallback (local dev): DB_USER + DB_PASSWORD + DB_HOST + DB_NAME (+ optional
// DB_PORT, DB_SSLROOTCERT). Kept for backwards-compat with .env files.
func BuildConnConfig() (*pgx.ConnConfig, error) {
	if url := os.Getenv("DATABASE_URL"); url != "" {
		cfg, err := pgx.ParseConfig(url)
		if err != nil {
			return nil, fmt.Errorf("parse DATABASE_URL: %w", err)
		}
		return cfg, nil
	}

	user := os.Getenv("DB_USER")
	pass := os.Getenv("DB_PASSWORD")
	host := os.Getenv("DB_HOST")
	port := os.Getenv("DB_PORT")
	name := os.Getenv("DB_NAME")
	cert := os.Getenv("DB_SSLROOTCERT")

	if user == "" || pass == "" || host == "" || name == "" {
		return nil, fmt.Errorf("missing connection config: set DATABASE_URL, or DB_USER+DB_PASSWORD+DB_HOST+DB_NAME")
	}
	if port == "" {
		port = "5432"
	}
	if cert == "" {
		cert = "./dbsystem.pub"
	}

	dsn := fmt.Sprintf("postgres://%s@%s:%s/%s?sslmode=verify-full&sslrootcert=%s",
		user, host, port, name, cert)

	cfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	cfg.Password = pass

	return cfg, nil
}

// EnvBool reads a boolean env var. Unset/empty returns def; the value must be
// exactly "true" or "false" otherwise.
func EnvBool(name string, def bool) (bool, error) {
	v := os.Getenv(name)
	if v == "" {
		return def, nil
	}
	switch v {
	case "true":
		return true, nil
	case "false":
		return false, nil
	default:
		return false, fmt.Errorf("%s: invalid value %q (must be true or false)", name, v)
	}
}

// SinkFlags resolves which write targets are enabled from WRITE_PG/WRITE_CH.
func SinkFlags() (writePG bool, writeCH bool, err error) {
	writePG, err = EnvBool("WRITE_PG", true)
	if err != nil {
		return false, false, err
	}
	writeCH, err = EnvBool("WRITE_CH", false)
	if err != nil {
		return false, false, err
	}

	if !writePG && !writeCH {
		return false, false, fmt.Errorf("no write target enabled: set WRITE_PG=true or WRITE_CH=true")
	}
	if writeCH && os.Getenv("CLICKHOUSE_URL") == "" {
		return false, false, fmt.Errorf("WRITE_CH=true requires CLICKHOUSE_URL")
	}

	return writePG, writeCH, nil
}
