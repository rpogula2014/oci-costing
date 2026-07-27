// oci-pull-advisor: snapshots OCI Cloud Advisor (optimizer) recommendations and
// history for the tenancy and writes a dated snapshot to ClickHouse. Meant to
// run daily from the same CronJob as oci-pull-bills.
//
// Usage:
//
//	oci-pull-advisor              # snapshot dated today (UTC)
//	oci-pull-advisor 2026-07-17   # snapshot dated for a specific day
//
// Env:
//
//	OCI_AUTH         auth mode chain (workload_identity | resource_principal |
//	                 instance_principal | api_key); default auto, same as oci-pull-bills
//	OCI_PROFILE      OCI config profile for the api_key fallback (default DEFAULT)
//	CLICKHOUSE_URL   ClickHouse DSN (database in the DSN; tables stay unqualified)
package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/joho/godotenv"

	"oci-costing/internal/chsink"
	"oci-costing/internal/ocireports"
	"oci-costing/internal/optimizer"
)

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	_ = godotenv.Load() // local dev: load .env if present (OKE provides env directly)

	profile := envOr("OCI_PROFILE", "DEFAULT")

	day := time.Now().UTC()
	if len(os.Args) >= 2 {
		d, err := time.Parse("2006-01-02", os.Args[1])
		if err != nil {
			log.Fatalf("bad date %q (want YYYY-MM-DD): %v", os.Args[1], err)
		}
		day = d
	}

	log.Printf("=== oci-pull-advisor start: snapshot_date=%s (OCI_AUTH=%s) ===",
		day.Format("2006-01-02"), envOr("OCI_AUTH", "auto"))

	provider, mode, err := ocireports.ConfigProvider(ocireports.Options{Profile: profile})
	if err != nil {
		log.Fatalf("resolve OCI config provider: %v", err)
	}
	log.Printf("auth mode: %s", mode)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	snap, err := optimizer.Fetch(ctx, provider, log.Printf)
	if err != nil {
		log.Fatalf("advisor fetch: %v", err)
	}
	if snap == nil {
		log.Printf("=== oci-pull-advisor done: tenancy not enrolled, nothing loaded ===")
		return
	}

	conn, err := chsink.Open(ctx)
	if err != nil {
		log.Fatalf("open clickhouse: %v", err)
	}
	defer conn.Close()

	recN, histN, err := chsink.AdvisorLoad(ctx, conn, day, snap)
	if err != nil {
		log.Fatalf("load advisor snapshot: %v", err)
	}

	log.Printf("=== oci-pull-advisor done: %d recommendations, %d history rows loaded for %s ===",
		recN, histN, day.Format("2006-01-02"))
}
