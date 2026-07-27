// Package optimizer snapshots OCI Cloud Advisor (optimizer service) data for a
// tenancy: it calls ListCategories, ListRecommendations, ListResourceActions and
// ListHistories, enriches each resource action with its recommendation/category
// context, and returns flat rows ready for a ClickHouse insert.
//
// Advisor is live-only (no history of its own past states); persisting a dated
// snapshot is what lets savings opportunity and realized savings be trended.
package optimizer

import (
	"context"
	"fmt"
	"time"

	"github.com/oracle/oci-go-sdk/v65/common"
	"github.com/oracle/oci-go-sdk/v65/optimizer"
	"github.com/shopspring/decimal"
)

// RecRow is one resource action enriched with recommendation + category context,
// shaped for the advisor_recommendations table.
type RecRow struct {
	ResourceActionID    string
	RecommendationID    string
	ResourceID          string
	ResourceName        string
	ResourceType        string
	CompartmentID       string
	Region              string
	RecommendationName  string
	Category            string
	Importance          string
	Status              string
	TimeStatusBegin     *time.Time
	EstimatedCostSaving *decimal.Decimal
	CapturedCostSaving  *decimal.Decimal
	Currency            string
	ActionType          string
	ActionURL           string
	RecommendedShape    string
	RecommendedCPU      *float64
	RecommendedMemory   *float64
	AggregationInterval *uint16
}

// HistRow is one ListHistories record, shaped for the advisor_history table.
type HistRow struct {
	HistoryID           string
	RecommendationID    string
	ResourceID          string
	ResourceType        string
	CompartmentID       string
	ResourceActionID    string
	RecommendationName  string
	Status              string
	TimeCreated         *time.Time
	EstimatedCostSaving *decimal.Decimal
	CapturedCostSaving  *decimal.Decimal
	Currency            string
}

// Snapshot is the result of one Advisor pull.
type Snapshot struct {
	Recs []RecRow
	Hist []HistRow
}

type logf func(string, ...any)

// advisorAPI is the subset of optimizer.OptimizerClient used here. It is a test
// seam: the concrete SDK client (value receivers) satisfies it, and a fake can
// drive fetchSnapshot without any OCI call.
type advisorAPI interface {
	ListEnrollmentStatuses(context.Context, optimizer.ListEnrollmentStatusesRequest) (optimizer.ListEnrollmentStatusesResponse, error)
	ListCategories(context.Context, optimizer.ListCategoriesRequest) (optimizer.ListCategoriesResponse, error)
	ListRecommendations(context.Context, optimizer.ListRecommendationsRequest) (optimizer.ListRecommendationsResponse, error)
	ListResourceActions(context.Context, optimizer.ListResourceActionsRequest) (optimizer.ListResourceActionsResponse, error)
	ListHistories(context.Context, optimizer.ListHistoriesRequest) (optimizer.ListHistoriesResponse, error)
}

// Fetch pulls a full Advisor snapshot for the tenancy behind provider. It first
// checks enrollment; if the tenancy is not ACTIVE it returns (nil, nil) so the
// caller can skip cleanly rather than treating it as an error.
func Fetch(ctx context.Context, provider common.ConfigurationProvider, log logf) (*Snapshot, error) {
	tenancy, err := provider.TenancyOCID()
	if err != nil {
		return nil, fmt.Errorf("tenancy ocid: %w", err)
	}
	client, err := optimizer.NewOptimizerClientWithConfigurationProvider(provider)
	if err != nil {
		return nil, fmt.Errorf("optimizer client: %w", err)
	}
	return fetchSnapshot(ctx, client, tenancy, log)
}

// fetchSnapshot is the OCI-independent core of Fetch, taking the advisorAPI seam.
func fetchSnapshot(ctx context.Context, api advisorAPI, tenancy string, log logf) (*Snapshot, error) {
	if log == nil {
		log = func(string, ...any) {}
	}

	active, err := isEnrolled(ctx, api, tenancy)
	if err != nil {
		return nil, fmt.Errorf("enrollment status: %w", err)
	}
	if !active {
		log("Cloud Advisor not enrolled (status != ACTIVE) for tenancy %s — skipping", tenancy)
		return nil, nil
	}

	cats, err := listCategories(ctx, api, tenancy)
	if err != nil {
		return nil, fmt.Errorf("list categories: %w", err)
	}
	recs, err := listRecommendations(ctx, api, tenancy)
	if err != nil {
		return nil, fmt.Errorf("list recommendations: %w", err)
	}
	actions, err := listResourceActions(ctx, api, tenancy)
	if err != nil {
		return nil, fmt.Errorf("list resource actions: %w", err)
	}
	hist, err := listHistories(ctx, api, tenancy)
	if err != nil {
		return nil, fmt.Errorf("list histories: %w", err)
	}
	log("advisor pull: %d categories, %d recommendations, %d resource actions, %d history records",
		len(cats), len(recs), len(actions), len(hist))

	// Enrichment maps: resource actions only carry ids, not names/importance.
	catName := make(map[string]string, len(cats))
	for _, c := range cats {
		catName[str(c.Id)] = str(c.Name)
	}
	type recMeta struct{ name, importance, categoryID string }
	recByID := make(map[string]recMeta, len(recs))
	for _, r := range recs {
		recByID[str(r.Id)] = recMeta{str(r.Name), string(r.Importance), str(r.CategoryId)}
	}

	snap := &Snapshot{Recs: make([]RecRow, 0, len(actions)), Hist: make([]HistRow, 0, len(hist))}

	for _, a := range actions {
		rm := recByID[str(a.RecommendationId)]
		category := catName[str(a.CategoryId)]
		if category == "" {
			category = catName[rm.categoryID]
		}
		row := RecRow{
			ResourceActionID:    str(a.Id),
			RecommendationID:    str(a.RecommendationId),
			ResourceID:          str(a.ResourceId),
			ResourceName:        str(a.Name),
			ResourceType:        str(a.ResourceType),
			CompartmentID:       str(a.CompartmentId),
			RecommendationName:  rm.name,
			Category:            category,
			Importance:          rm.importance,
			Status:              string(a.Status),
			TimeStatusBegin:     sdkTime(a.TimeStatusBegin),
			EstimatedCostSaving: money(a.EstimatedCostSaving),
			Currency:            metaStr(a.ExtendedMetadata, "currencyCode"),
			Region:              metaStr(a.ExtendedMetadata, "region"),
			RecommendedShape:    metaStr(a.ExtendedMetadata, "instanceRecommendedShape"),
			RecommendedCPU:      metaFloat(a.ExtendedMetadata, "instanceRecommendedCPU"),
			RecommendedMemory:   metaFloat(a.ExtendedMetadata, "instanceRecommendedMemory"),
			AggregationInterval: metaUint16(a.ExtendedMetadata, "aggregationInterval"),
			CapturedCostSaving:  metaMoney(a.ExtendedMetadata, "capturedCostSaving"),
		}
		if a.Action != nil {
			row.ActionType = string(a.Action.Type)
			row.ActionURL = str(a.Action.Url)
		}
		snap.Recs = append(snap.Recs, row)
	}

	for _, h := range hist {
		snap.Hist = append(snap.Hist, HistRow{
			HistoryID:           str(h.Id),
			RecommendationID:    str(h.RecommendationId),
			ResourceID:          str(h.ResourceId),
			ResourceType:        str(h.ResourceType),
			CompartmentID:       str(h.CompartmentId),
			ResourceActionID:    str(h.ResourceActionId),
			RecommendationName:  str(h.RecommendationName),
			Status:              string(h.Status),
			TimeCreated:         sdkTime(h.TimeCreated),
			EstimatedCostSaving: money(h.EstimatedCostSaving),
			CapturedCostSaving:  metaMoney(h.ExtendedMetadata, "capturedCostSaving"),
			Currency:            metaStr(h.ExtendedMetadata, "currencyCode"),
		})
	}

	return snap, nil
}

func isEnrolled(ctx context.Context, c advisorAPI, tenancy string) (bool, error) {
	resp, err := c.ListEnrollmentStatuses(ctx, optimizer.ListEnrollmentStatusesRequest{
		CompartmentId: &tenancy,
	})
	if err != nil {
		return false, err
	}
	for _, it := range resp.Items {
		if it.Status == optimizer.OptimizerEnrollmentStatusActive {
			return true, nil
		}
	}
	return false, nil
}

func listCategories(ctx context.Context, c advisorAPI, tenancy string) ([]optimizer.CategorySummary, error) {
	var out []optimizer.CategorySummary
	var page *string
	for {
		resp, err := c.ListCategories(ctx, optimizer.ListCategoriesRequest{
			CompartmentId:          &tenancy,
			CompartmentIdInSubtree: common.Bool(true),
			Page:                   page,
		})
		if err != nil {
			return nil, err
		}
		out = append(out, resp.Items...)
		if resp.OpcNextPage == nil {
			return out, nil
		}
		page = resp.OpcNextPage
	}
}

func listRecommendations(ctx context.Context, c advisorAPI, tenancy string) ([]optimizer.RecommendationSummary, error) {
	var out []optimizer.RecommendationSummary
	var page *string
	for {
		resp, err := c.ListRecommendations(ctx, optimizer.ListRecommendationsRequest{
			CompartmentId:          &tenancy,
			CompartmentIdInSubtree: common.Bool(true),
			Page:                   page,
		})
		if err != nil {
			return nil, err
		}
		out = append(out, resp.Items...)
		if resp.OpcNextPage == nil {
			return out, nil
		}
		page = resp.OpcNextPage
	}
}

func listResourceActions(ctx context.Context, c advisorAPI, tenancy string) ([]optimizer.ResourceActionSummary, error) {
	var out []optimizer.ResourceActionSummary
	var page *string
	for {
		resp, err := c.ListResourceActions(ctx, optimizer.ListResourceActionsRequest{
			CompartmentId:          &tenancy,
			CompartmentIdInSubtree: common.Bool(true),
			Page:                   page,
		})
		if err != nil {
			return nil, err
		}
		out = append(out, resp.Items...)
		if resp.OpcNextPage == nil {
			return out, nil
		}
		page = resp.OpcNextPage
	}
}

func listHistories(ctx context.Context, c advisorAPI, tenancy string) ([]optimizer.HistorySummary, error) {
	var out []optimizer.HistorySummary
	var page *string
	for {
		resp, err := c.ListHistories(ctx, optimizer.ListHistoriesRequest{
			CompartmentId:          &tenancy,
			CompartmentIdInSubtree: common.Bool(true),
			Page:                   page,
		})
		if err != nil {
			return nil, err
		}
		out = append(out, resp.Items...)
		if resp.OpcNextPage == nil {
			return out, nil
		}
		page = resp.OpcNextPage
	}
}

func str(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func sdkTime(t *common.SDKTime) *time.Time {
	if t == nil {
		return nil
	}
	tt := t.Time
	return &tt
}

// money converts an Advisor float saving to a decimal at scale 10 (matching the
// ClickHouse Decimal(20,10) columns), which also eliminates scientific notation.
func money(f *float64) *decimal.Decimal {
	if f == nil {
		return nil
	}
	d := decimal.NewFromFloat(*f).Round(10)
	return &d
}

func metaStr(m map[string]interface{}, key string) string {
	if m == nil {
		return ""
	}
	if v, ok := m[key].(string); ok {
		return v
	}
	return ""
}

func metaFloat(m map[string]interface{}, key string) *float64 {
	if m == nil {
		return nil
	}
	switch v := m[key].(type) {
	case float64:
		return &v
	case string:
		if d, err := decimal.NewFromString(v); err == nil {
			f, _ := d.Float64()
			return &f
		}
	}
	return nil
}

func metaUint16(m map[string]interface{}, key string) *uint16 {
	f := metaFloat(m, key)
	if f == nil || *f < 0 {
		return nil
	}
	u := uint16(*f)
	return &u
}

// metaMoney reads a saving that Advisor nests in ExtendedMetadata (e.g.
// capturedCostSaving), which may arrive as a float or a string.
func metaMoney(m map[string]interface{}, key string) *decimal.Decimal {
	if m == nil {
		return nil
	}
	switch v := m[key].(type) {
	case float64:
		return money(&v)
	case string:
		if d, err := decimal.NewFromString(v); err == nil {
			d = d.Round(10)
			return &d
		}
	}
	return nil
}
