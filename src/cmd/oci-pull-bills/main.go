// oci-pull-bills: orchestrator — downloads OCI cost reports (in-process via
// internal/ocireports) and loads them by exec'ing oci-load-bills.
//
// Usage:
//   oci-pull-bills                  # yesterday + today
//   oci-pull-bills 2026-04-01       # specific date
//   oci-pull-bills 2026-04          # entire month
//
// Env:
//   OCI_LOAD_BILLS_BIN  (default /oci-load-bills)
//   OCI_PROFILE      (default FOCUSREPORTS-NEW)
//   OCI_DATA_DIR     (default /data)
package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"oci-costing/internal/ocireports"
)

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func runStreaming(label, bin string, args ...string) error {
	log.Printf("[%s] exec: %s %v", label, bin, args)
	cmd := exec.Command(bin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	return cmd.Run()
}

func download(ctx context.Context, rt ociReportsType, interval, outDir, profile string) error {
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return fmt.Errorf("mkdir %s: %w", outDir, err)
	}
	n, err := ocireports.Download(ctx, ocireports.Options{
		ReportType: ocireports.ReportType(rt),
		Interval:   interval,
		Profile:    profile,
		OutputDir:  outDir,
		Logf:       func(f string, a ...any) { log.Printf("[download:%s/%s] "+f, append([]any{rt, interval}, a...)...) },
	})
	if err != nil {
		return err
	}
	log.Printf("[download:%s/%s] %d files", rt, interval, n)
	return nil
}

type ociReportsType string

const (
	rFocus ociReportsType = "focus"
	rCost  ociReportsType = "cost"
)

func main() {
	loadBillsBin := envOr("OCI_LOAD_BILLS_BIN", "/oci-load-bills")
	// OCI_PROFILE only applies to the local api-key fallback; in OKE the auth
	// chain uses Workload Identity and this value is ignored.
	profile := envOr("OCI_PROFILE", "DEFAULT")
	dataDir := envOr("OCI_DATA_DIR", "/data")

	focusDir := filepath.Join(dataDir, "focus")
	costDir := filepath.Join(dataDir, "cost")

	var intervals []string
	if len(os.Args) >= 2 {
		intervals = []string{os.Args[1]}
	} else {
		now := time.Now().UTC()
		intervals = []string{
			now.AddDate(0, 0, -1).Format("2006-01-02"),
			now.Format("2006-01-02"),
		}
	}

	log.Printf("=== oci-pull-bills start: intervals=%v data=%s (OCI_AUTH=%s) ===", intervals, dataDir, envOr("OCI_AUTH", "auto"))

	// Per-call ctx; one slow list shouldn't poison the rest.
	dlFailures := 0
	for _, d := range intervals {
		for _, pair := range []struct {
			rt  ociReportsType
			dir string
		}{
			{rFocus, focusDir},
			{rCost, costDir},
		} {
			ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
			if err := download(ctx, pair.rt, d, pair.dir, profile); err != nil {
				log.Printf("WARN download %s/%s failed: %v", pair.rt, d, err)
				dlFailures++
			}
			cancel()
		}
	}

	// Loaders are idempotent; run regardless of download outcome.
	loadExit := 0
	if err := runStreaming("load-focus", loadBillsBin, "focus", focusDir); err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			loadExit |= ee.ExitCode()
		} else {
			log.Printf("ERROR load-focus: %v", err)
			loadExit |= 1
		}
	}
	if err := runStreaming("load-oci", loadBillsBin, "oci", costDir); err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			loadExit |= ee.ExitCode()
		} else {
			log.Printf("ERROR load-oci: %v", err)
			loadExit |= 1
		}
	}

	log.Printf("=== oci-pull-bills done: download_failures=%d load_exit=%d ===", dlFailures, loadExit)

	switch {
	case loadExit&1 != 0:
		os.Exit(1)
	case loadExit != 0 || dlFailures > 0:
		os.Exit(2)
	}
}
