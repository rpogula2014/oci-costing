// Package ocireports downloads OCI cost/usage/FOCUS report CSV files from the
// tenancy reporting bucket via the Object Storage API.
//
// Originally derived from https://github.com/paolobellardone/oci-reports-download
// (MIT License, Copyright (c) 2024 PaoloB). See NOTICE at repo root.
// Significant rewrites since then:
//   - exposed as a library function (no cobra, no os.Exit / log.Fatal)
//   - OCI_AUTH-driven auth chain: Workload Identity → RP → IP → api-key
//   - caller-supplied context, Options struct, structured logger
//   - path-traversal guard on object names
//
// Constants (namespace "bling", report-type prefixes, tenancy-OCID-as-bucket-name)
// are public OCI conventions documented at:
//   https://docs.oracle.com/en-us/iaas/Content/Billing/Tasks/accessingusagereports.htm
package ocireports

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"os/user"
	"path/filepath"
	"strings"

	"github.com/oracle/oci-go-sdk/v65/common"
	"github.com/oracle/oci-go-sdk/v65/common/auth"
	"github.com/oracle/oci-go-sdk/v65/objectstorage"
)

const (
	reportingNamespace = "bling"
	costPrefix         = "reports/cost-csv/"
	usagePrefix        = "reports/usage-csv/"
	focusPrefix        = "FOCUS Reports/"
)

// ReportType is one of "cost", "usage", "focus".
type ReportType string

const (
	ReportCost  ReportType = "cost"
	ReportUsage ReportType = "usage"
	ReportFocus ReportType = "focus"
)

// Options for Download.
type Options struct {
	ReportType ReportType // required
	Interval   string     // substring match on TimeCreated date (YYYY, YYYY-MM, YYYY-MM-DD). Empty = all
	OutputDir  string     // local dir to write files into (default cwd)
	Logf       func(string, ...any)

	// Profile and ConfigFilePath only apply when OCI_AUTH=api_key (local dev).
	// Ignored in OKE / production where Workload Identity provides credentials.
	Profile        string // OCI config profile (default "DEFAULT")
	ConfigFilePath string // override path to ~/.oci/config; empty = $HOME/.oci/config
}

func (o *Options) defaults() error {
	if o.ReportType == "" {
		return errors.New("ReportType required")
	}
	switch o.ReportType {
	case ReportCost, ReportUsage, ReportFocus:
	default:
		return fmt.Errorf("invalid ReportType %q", o.ReportType)
	}
	if o.Profile == "" {
		o.Profile = "DEFAULT"
	}
	if o.OutputDir == "" {
		o.OutputDir = "."
	}
	if o.ConfigFilePath == "" {
		o.ConfigFilePath = filepath.Join(homeFolder(), ".oci", "config")
	}
	if o.Logf == nil {
		o.Logf = func(string, ...any) {}
	}
	return nil
}

func prefixFor(t ReportType) string {
	switch t {
	case ReportCost:
		return costPrefix
	case ReportUsage:
		return usagePrefix
	case ReportFocus:
		return focusPrefix
	}
	return ""
}

// resolveConfigProvider picks an OCI config provider based on $OCI_AUTH:
//
//   workload_identity    OKE Workload Identity — fail hard if unavailable
//   resource_principal   Generic Resource Principal (Functions, etc.)
//   instance_principal   Plain OCI compute VM identity
//   api_key              ~/.oci/config (local dev)
//   auto / unset         Try wi → rp → ip → api_key in order
//
// In OKE manifests, set OCI_AUTH=workload_identity to forbid silent fallback to
// node identity (instance principal) if WI breaks.
func resolveConfigProvider(opts Options) (common.ConfigurationProvider, string, error) {
	tryWI := func() (common.ConfigurationProvider, string, error) {
		p, err := auth.OkeWorkloadIdentityConfigurationProvider()
		if err != nil {
			return nil, "", err
		}
		if _, err := p.TenancyOCID(); err != nil {
			return nil, "", err
		}
		return p, "oke-workload-identity", nil
	}
	tryRP := func() (common.ConfigurationProvider, string, error) {
		p, err := auth.ResourcePrincipalConfigurationProvider()
		if err != nil {
			return nil, "", err
		}
		if _, err := p.TenancyOCID(); err != nil {
			return nil, "", err
		}
		return p, "resource-principal", nil
	}
	tryIP := func() (common.ConfigurationProvider, string, error) {
		p, err := auth.InstancePrincipalConfigurationProvider()
		if err != nil {
			return nil, "", err
		}
		if _, err := p.TenancyOCID(); err != nil {
			return nil, "", err
		}
		return p, "instance-principal", nil
	}
	tryAPI := func() (common.ConfigurationProvider, string, error) {
		p := common.CustomProfileConfigProvider(opts.ConfigFilePath, opts.Profile)
		if _, err := p.TenancyOCID(); err != nil {
			return nil, "", err
		}
		return p, fmt.Sprintf("api-key (profile=%s)", opts.Profile), nil
	}

	mode := strings.ToLower(strings.TrimSpace(os.Getenv("OCI_AUTH")))
	exclusive := map[string]func() (common.ConfigurationProvider, string, error){
		"workload_identity":  tryWI,
		"resource_principal": tryRP,
		"instance_principal": tryIP,
		"api_key":            tryAPI,
		"api-key":            tryAPI,
	}
	if fn, ok := exclusive[mode]; ok {
		p, name, err := fn()
		if err != nil {
			return nil, "", fmt.Errorf("OCI_AUTH=%s required but failed: %w", mode, err)
		}
		return p, name, nil
	}
	if mode != "" && mode != "auto" {
		return nil, "", fmt.Errorf("OCI_AUTH=%q: unknown (workload_identity|resource_principal|instance_principal|api_key|auto)", mode)
	}

	// auto: try each in turn, fall through on miss.
	for _, fn := range []func() (common.ConfigurationProvider, string, error){tryWI, tryRP, tryIP, tryAPI} {
		p, name, err := fn()
		if err == nil {
			return p, name, nil
		}
		log.Printf("auth: %v", err)
	}
	return nil, "", fmt.Errorf("no usable OCI auth method (tried workload_identity, resource_principal, instance_principal, api_key)")
}

// Download lists and downloads report objects matching opts. Returns count of
// files downloaded.
func Download(ctx context.Context, opts Options) (int, error) {
	if err := opts.defaults(); err != nil {
		return 0, err
	}

	cfgProv, authMode, err := resolveConfigProvider(opts)
	if err != nil {
		return 0, fmt.Errorf("auth: %w", err)
	}
	opts.Logf("auth: %s", authMode)
	tenancyOCID, err := cfgProv.TenancyOCID()
	if err != nil {
		return 0, fmt.Errorf("read tenancy: %w", err)
	}
	osClient, err := objectstorage.NewObjectStorageClientWithConfigurationProvider(cfgProv)
	if err != nil {
		return 0, fmt.Errorf("os client: %w", err)
	}

	if err := os.MkdirAll(opts.OutputDir, 0o755); err != nil {
		return 0, fmt.Errorf("mkdir output: %w", err)
	}

	prefix := prefixFor(opts.ReportType)
	req := objectstorage.ListObjectsRequest{
		NamespaceName: common.String(reportingNamespace),
		BucketName:    common.String(tenancyOCID),
		Fields:        common.String("name,size,timeCreated"),
		Prefix:        common.String(prefix),
	}

	downloaded := 0
	for {
		rsp, err := osClient.ListObjects(ctx, req)
		if err != nil {
			return downloaded, fmt.Errorf("list objects: %w", err)
		}
		for _, obj := range rsp.ListObjects.Objects {
			if opts.Interval != "" {
				if obj.TimeCreated == nil {
					continue
				}
				if !strings.Contains(obj.TimeCreated.Format("2006-01-02"), opts.Interval) {
					continue
				}
			}
			if err := downloadOne(ctx, osClient, tenancyOCID, prefix, *obj.Name, opts); err != nil {
				return downloaded, err
			}
			downloaded++
		}
		if rsp.ListObjects.NextStartWith == nil {
			break
		}
		req.Start = rsp.ListObjects.NextStartWith
	}
	return downloaded, nil
}

func downloadOne(ctx context.Context, c objectstorage.ObjectStorageClient, tenancy, prefix, name string, opts Options) error {
	opts.Logf("download %s", name)
	res, err := c.GetObject(ctx, objectstorage.GetObjectRequest{
		NamespaceName: common.String(reportingNamespace),
		BucketName:    common.String(tenancy),
		ObjectName:    common.String(name),
	})
	if err != nil {
		return fmt.Errorf("get %s: %w", name, err)
	}
	defer res.Content.Close()

	relName := strings.TrimPrefix(name, prefix)
	outPath := filepath.Join(opts.OutputDir, relName)

	// Defense against malicious object names containing ".." segments that
	// could escape OutputDir via filepath.Join. Object names are Oracle-
	// controlled today, but this is cheap insurance for future bucket sources.
	absOut, err := filepath.Abs(opts.OutputDir)
	if err != nil {
		return fmt.Errorf("abs output dir: %w", err)
	}
	absPath, err := filepath.Abs(outPath)
	if err != nil {
		return fmt.Errorf("abs out path: %w", err)
	}
	rel, err := filepath.Rel(absOut, absPath)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return fmt.Errorf("rejected object name escapes output dir: %q", name)
	}

	if dir := filepath.Dir(outPath); dir != opts.OutputDir {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return fmt.Errorf("mkdir %s: %w", dir, err)
		}
	}

	out, err := os.Create(outPath)
	if err != nil {
		return fmt.Errorf("create %s: %w", outPath, err)
	}
	defer out.Close()

	written, err := io.Copy(out, res.Content)
	if err != nil {
		return fmt.Errorf("write %s: %w", outPath, err)
	}
	if res.ContentLength != nil && written != *res.ContentLength {
		return fmt.Errorf("short read %s: wrote %d, expected %d", outPath, written, *res.ContentLength)
	}
	return nil
}

func homeFolder() string {
	if u, err := user.Current(); err == nil && u.HomeDir != "" {
		return u.HomeDir
	}
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	return os.Getenv("USERPROFILE")
}
