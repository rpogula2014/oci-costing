package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
	"oci-costing/internal/chsink"
	"oci-costing/internal/config"
	"oci-costing/internal/loader"
	"oci-costing/internal/output"
)

const perFileTimeout = 30 * time.Minute

func usage() {
	fmt.Fprintf(os.Stderr, "Usage:\n"+
		"  oci-costing focus <file.csv.gz|folder>   Load FOCUS cost report\n"+
		"  oci-costing oci   <file.csv.gz|folder>   Load OCI proprietary cost report\n")
}

func main() {
	if len(os.Args) < 3 {
		usage()
		os.Exit(1)
	}

	cmd := os.Args[1]
	target := os.Args[2]

	switch cmd {
	case "oci":
		loader.OCICostMain(target)
		return
	case "focus":
		// fall through
	default:
		fmt.Fprintf(os.Stderr, "Unknown subcommand: %q\n", cmd)
		usage()
		os.Exit(1)
	}

	_ = godotenv.Load()

	writePG, writeCH, err := config.SinkFlags()
	if err != nil {
		log.Fatalf("Sink config: %v", err)
	}

	tagsConfigPath := filepath.Join(filepath.Dir(os.Args[0]), "tags.yaml")
	if envPath := os.Getenv("TAGS_CONFIG"); envPath != "" {
		tagsConfigPath = envPath
	}
	tagsCfg, err := config.LoadTagsConfig(tagsConfigPath)
	if err != nil {
		log.Printf("WARN: tags.yaml not found at %s, tags/* columns will be skipped", tagsConfigPath)
		tagsCfg = &config.TagsConfig{}
	} else {
		log.Printf("Loaded %d tag definitions from %s", len(tagsCfg.Tags), tagsConfigPath)
	}

	var pgConn *pgx.Conn
	if writePG {
		cfg, err := config.BuildConnConfig()
		if err != nil {
			log.Fatalf("Config: %v", err)
		}
		connCtx, connCancel := context.WithTimeout(context.Background(), time.Minute)
		pgConn, err = pgx.ConnectConfig(connCtx, cfg)
		connCancel()
		if err != nil {
			log.Fatalf("Connect failed: %v", err)
		}
		defer pgConn.Close(context.Background())
		log.Printf("Connected to Postgres")
	}

	var chConn driver.Conn
	if writeCH {
		connCtx, connCancel := context.WithTimeout(context.Background(), time.Minute)
		chConn, err = chsink.Open(connCtx)
		connCancel()
		if err != nil {
			log.Fatalf("ClickHouse connect failed: %v", err)
		}
		defer chConn.Close()
		log.Printf("Connected to ClickHouse")
	}

	info, err := os.Stat(target)
	if err != nil {
		log.Fatalf("Cannot access %s: %v", target, err)
	}

	var files []string
	if info.IsDir() {
		err := filepath.WalkDir(target, func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() && d.Name() == "archive" {
				return filepath.SkipDir
			}
			if !d.IsDir() && strings.HasSuffix(d.Name(), ".csv.gz") {
				files = append(files, path)
			}
			return nil
		})
		if err != nil {
			log.Fatalf("Walk folder: %v", err)
		}
		if len(files) == 0 {
			log.Fatalf("No .csv.gz files found in %s", target)
		}
	} else {
		files = []string{target}
	}

	log.Printf("Found %d file(s) to process", len(files))

	results := make([]output.FileResult, 0, len(files))
	failures := 0

	for _, filePath := range files {
		filename := filepath.Base(filePath)

		fileCtx, cancel := context.WithTimeout(context.Background(), perFileTimeout)

		// Per-sink presence check (only enabled sinks are consulted).
		pgHas, chHas := false, false
		var checkErr error
		if writePG {
			pgHas, checkErr = loader.FocusIsAlreadyLoaded(fileCtx, pgConn, filename)
		}
		if checkErr == nil && writeCH {
			chHas, checkErr = chsink.FocusIsAlreadyLoaded(fileCtx, chConn, filename)
		}
		if checkErr != nil {
			cancel()
			log.Printf("FAIL %s: check existing: %v", filename, checkErr)
			results = append(results, output.FileResult{Path: filePath, Status: "FAIL"})
			failures++
			continue
		}

		// All enabled sinks already have it -> skip + archive.
		if (!writePG || pgHas) && (!writeCH || chHas) {
			cancel()
			results = append(results, output.FileResult{Path: filePath, Status: "SKIP"})
			if err := loader.ArchiveFile(filePath, target); err != nil {
				log.Printf("WARN: archive skip %s: %v", filename, err)
			}
			continue
		}

		// Load into each enabled sink lacking it, ClickHouse first then Postgres.
		// Any enabled-sink failure aborts the remaining loads (fail-soft, no archive).
		rows := 0
		var loadErr error
		if writeCH && !chHas {
			if n, err := chsink.FocusLoadFile(fileCtx, chConn, filePath, filename, tagsCfg); err != nil {
				loadErr = fmt.Errorf("clickhouse: %w", err)
			} else {
				rows = n
			}
		}
		if loadErr == nil && writePG && !pgHas {
			if n, err := loader.FocusLoadFile(fileCtx, pgConn, filePath, filename, tagsCfg); err != nil {
				loadErr = fmt.Errorf("postgres: %w", err)
			} else {
				rows = n
			}
		}
		cancel()
		if loadErr != nil {
			log.Printf("FAIL %s: %v", filename, loadErr)
			results = append(results, output.FileResult{Path: filePath, Status: "FAIL"})
			failures++
			continue
		}

		results = append(results, output.FileResult{Path: filePath, Status: "DONE", Rows: rows})
		if err := loader.ArchiveFile(filePath, target); err != nil {
			log.Printf("WARN: archive done %s: %v", filename, err)
		}
	}

	output.PrintTree(target, results)
	if failures > 0 {
		os.Exit(2)
	}
}
