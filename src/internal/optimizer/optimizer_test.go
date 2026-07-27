package optimizer

import (
	"context"
	"strings"
	"testing"

	"github.com/oracle/oci-go-sdk/v65/optimizer"
	"github.com/shopspring/decimal"
)

func sp(s string) *string   { return &s }
func fp(f float64) *float64 { return &f }

// fakeAPI is an in-memory advisorAPI. Each List* result is a slice of pages; the
// fake hands out one page per call and sets OpcNextPage while pages remain, so
// the production paging loop is exercised without any OCI/HTTP dependency.
type fakeAPI struct {
	enroll  []optimizer.EnrollmentStatusSummary
	cats    [][]optimizer.CategorySummary
	recs    [][]optimizer.RecommendationSummary
	actions [][]optimizer.ResourceActionSummary
	hist    [][]optimizer.HistorySummary
	calls   map[string]int
}

func (f *fakeAPI) bump(name string) int {
	if f.calls == nil {
		f.calls = map[string]int{}
	}
	i := f.calls[name]
	f.calls[name]++
	return i
}

func nextPage[T any](pages [][]T, i int) ([]T, *string) {
	if i >= len(pages) {
		return nil, nil
	}
	var next *string
	if i < len(pages)-1 {
		next = sp("page")
	}
	return pages[i], next
}

func (f *fakeAPI) ListEnrollmentStatuses(_ context.Context, _ optimizer.ListEnrollmentStatusesRequest) (optimizer.ListEnrollmentStatusesResponse, error) {
	f.bump("enroll")
	return optimizer.ListEnrollmentStatusesResponse{
		EnrollmentStatusCollection: optimizer.EnrollmentStatusCollection{Items: f.enroll},
	}, nil
}

func (f *fakeAPI) ListCategories(_ context.Context, _ optimizer.ListCategoriesRequest) (optimizer.ListCategoriesResponse, error) {
	items, next := nextPage(f.cats, f.bump("cats"))
	return optimizer.ListCategoriesResponse{
		CategoryCollection: optimizer.CategoryCollection{Items: items},
		OpcNextPage:        next,
	}, nil
}

func (f *fakeAPI) ListRecommendations(_ context.Context, _ optimizer.ListRecommendationsRequest) (optimizer.ListRecommendationsResponse, error) {
	items, next := nextPage(f.recs, f.bump("recs"))
	return optimizer.ListRecommendationsResponse{
		RecommendationCollection: optimizer.RecommendationCollection{Items: items},
		OpcNextPage:              next,
	}, nil
}

func (f *fakeAPI) ListResourceActions(_ context.Context, _ optimizer.ListResourceActionsRequest) (optimizer.ListResourceActionsResponse, error) {
	items, next := nextPage(f.actions, f.bump("actions"))
	return optimizer.ListResourceActionsResponse{
		ResourceActionCollection: optimizer.ResourceActionCollection{Items: items},
		OpcNextPage:              next,
	}, nil
}

func (f *fakeAPI) ListHistories(_ context.Context, _ optimizer.ListHistoriesRequest) (optimizer.ListHistoriesResponse, error) {
	items, next := nextPage(f.hist, f.bump("hist"))
	return optimizer.ListHistoriesResponse{
		HistoryCollection: optimizer.HistoryCollection{Items: items},
		OpcNextPage:       next,
	}, nil
}

// Finding 7(a): the paging loop MUST follow OpcNextPage across every list API so
// no recommendations are silently truncated. Two pages per list here; the loop
// must aggregate both and stop only when OpcNextPage is nil.
func TestFetchSnapshotFollowsAllPages(t *testing.T) {
	api := &fakeAPI{
		enroll: []optimizer.EnrollmentStatusSummary{{Status: optimizer.OptimizerEnrollmentStatusActive}},
		cats:   [][]optimizer.CategorySummary{{{Id: sp("c1"), Name: sp("cost-management")}}},
		recs:   [][]optimizer.RecommendationSummary{{{Id: sp("r1"), Name: sp("Right-size"), CategoryId: sp("c1")}}},
		actions: [][]optimizer.ResourceActionSummary{
			{{Id: sp("a1"), RecommendationId: sp("r1"), CategoryId: sp("c1")}},
			{{Id: sp("a2"), RecommendationId: sp("r1"), CategoryId: sp("c1")}},
		},
		hist: [][]optimizer.HistorySummary{
			{{Id: sp("h1")}},
			{{Id: sp("h2")}, {Id: sp("h3")}},
		},
	}

	snap, err := fetchSnapshot(context.Background(), api, "ocid.tenancy", nil)
	if err != nil {
		t.Fatalf("fetchSnapshot: %v", err)
	}
	if len(snap.Recs) != 2 {
		t.Errorf("recs: want 2 (both action pages), got %d", len(snap.Recs))
	}
	if len(snap.Hist) != 3 {
		t.Errorf("hist: want 3 (both history pages), got %d", len(snap.Hist))
	}
	if api.calls["actions"] != 2 || api.calls["hist"] != 2 {
		t.Errorf("expected 2 paged calls each, got actions=%d hist=%d", api.calls["actions"], api.calls["hist"])
	}
}

// Finding 7(b): a non-ACTIVE enrollment must skip cleanly — return (nil, nil) and
// issue zero list calls, never a hard error or a partial write.
func TestFetchSnapshotSkipsWhenNotEnrolled(t *testing.T) {
	api := &fakeAPI{
		enroll: []optimizer.EnrollmentStatusSummary{{Status: optimizer.OptimizerEnrollmentStatusEnum("INACTIVE")}},
	}
	snap, err := fetchSnapshot(context.Background(), api, "ocid.tenancy", nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if snap != nil {
		t.Errorf("want nil snapshot on inactive enrollment, got %+v", snap)
	}
	for _, k := range []string{"cats", "recs", "actions", "hist"} {
		if api.calls[k] != 0 {
			t.Errorf("list %q must not be called when not enrolled, got %d", k, api.calls[k])
		}
	}
}

// Finding 7(e): resource actions carry only ids; enrichment fills name/category/
// importance from the recommendation and category maps. When a row's own
// CategoryId is empty it must fall back to the recommendation's category, and
// null names / nil ExtendedMetadata must degrade to empty values without panic.
func TestFetchSnapshotEnrichesAndToleratesNullMetadata(t *testing.T) {
	api := &fakeAPI{
		enroll: []optimizer.EnrollmentStatusSummary{{Status: optimizer.OptimizerEnrollmentStatusActive}},
		cats:   [][]optimizer.CategorySummary{{{Id: sp("c1"), Name: sp("cost-management")}}},
		recs: [][]optimizer.RecommendationSummary{{{
			Id: sp("r1"), Name: sp("Right-size compute"),
			Importance: optimizer.ImportanceEnum("CRITICAL"), CategoryId: sp("c1"),
		}}},
		actions: [][]optimizer.ResourceActionSummary{{{
			Id:                  sp("a1"),
			RecommendationId:    sp("r1"),
			ResourceId:          sp("ocid1.instance.oc1..x"),
			CategoryId:          nil, // empty -> must fall back to recommendation's category
			Name:                nil, // null name -> ""
			ExtendedMetadata:    nil, // nil map -> no panic, empty currency/region
			Status:              optimizer.StatusEnum("PENDING"),
			EstimatedCostSaving: fp(254.46),
			Action:              &optimizer.Action{Type: optimizer.ActionTypeEnum("KB_ARTICLE"), Url: sp("https://kb")},
		}}},
	}

	snap, err := fetchSnapshot(context.Background(), api, "ocid.tenancy", nil)
	if err != nil {
		t.Fatalf("fetchSnapshot: %v", err)
	}
	if len(snap.Recs) != 1 {
		t.Fatalf("want 1 rec row, got %d", len(snap.Recs))
	}
	r := snap.Recs[0]
	if r.RecommendationName != "Right-size compute" {
		t.Errorf("recommendation name not enriched: %q", r.RecommendationName)
	}
	if r.Category != "cost-management" {
		t.Errorf("category fallback failed: want cost-management, got %q", r.Category)
	}
	if r.Importance != "CRITICAL" {
		t.Errorf("importance not enriched: %q", r.Importance)
	}
	if r.ResourceName != "" || r.Currency != "" || r.Region != "" {
		t.Errorf("null fields should be empty, got name=%q currency=%q region=%q", r.ResourceName, r.Currency, r.Region)
	}
	if r.EstimatedCostSaving == nil || !r.EstimatedCostSaving.Equal(decimal.RequireFromString("254.46")) {
		t.Errorf("estimated saving = %v, want 254.46", r.EstimatedCostSaving)
	}
	if r.ActionType != "KB_ARTICLE" || r.ActionURL != "https://kb" {
		t.Errorf("action not mapped: type=%q url=%q", r.ActionType, r.ActionURL)
	}
}

// Finding 7(c): Advisor returns savings as floats, sometimes in scientific
// notation; ingest must store a currency/scale-10 decimal, never E-notation.
func TestMoneyNormalizesFloats(t *testing.T) {
	if money(nil) != nil {
		t.Error("money(nil) should be nil")
	}
	sci := money(fp(1.936e-11)) // 0.00000000001936 -> rounds to 0 at scale 10
	if sci == nil {
		t.Fatal("money(sci) nil")
	}
	if s := sci.String(); strings.ContainsAny(s, "eE") {
		t.Errorf("scientific notation leaked into storage value: %q", s)
	}
	if !sci.IsZero() {
		t.Errorf("1.936e-11 should round to 0 at scale 10, got %s", sci.String())
	}
	if got := money(fp(254.46)); got == nil || !got.Equal(decimal.RequireFromString("254.46")) {
		t.Errorf("254.46 mangled: %v", got)
	}
	if got := money(fp(0.0430657123456789)); got == nil || !got.Equal(decimal.RequireFromString("0.0430657123")) {
		t.Errorf("scale-10 rounding wrong: %v", got)
	}
}

// Finding 7(e): metadata helpers must tolerate nil maps, missing keys and wrong
// types without panicking, and accept both float and string encodings.
func TestMetaHelpersTolerateMissingAndMalformed(t *testing.T) {
	if metaStr(nil, "k") != "" {
		t.Error("metaStr(nil) should be empty")
	}
	m := map[string]interface{}{"s": "USD", "f": 3.5, "fs": "168", "neg": "-5", "trunc": "3.9", "b": true}
	if metaStr(m, "s") != "USD" {
		t.Error("metaStr string")
	}
	if metaStr(m, "missing") != "" {
		t.Error("metaStr missing -> empty")
	}
	if metaStr(m, "b") != "" {
		t.Error("metaStr wrong-type -> empty")
	}
	if got := metaFloat(m, "f"); got == nil || *got != 3.5 {
		t.Errorf("metaFloat float64: %v", got)
	}
	if got := metaFloat(m, "fs"); got == nil || *got != 168 {
		t.Errorf("metaFloat string: %v", got)
	}
	if metaFloat(nil, "f") != nil || metaFloat(m, "missing") != nil {
		t.Error("metaFloat nil/missing -> nil")
	}
	if got := metaUint16(m, "fs"); got == nil || *got != 168 {
		t.Errorf("metaUint16: %v", got)
	}
	if got := metaUint16(m, "trunc"); got == nil || *got != 3 {
		t.Errorf("metaUint16 truncation: %v", got)
	}
	if metaUint16(m, "neg") != nil {
		t.Error("metaUint16 negative -> nil")
	}
}

// Finding 7(c/e): capturedCostSaving arrives nested in ExtendedMetadata as either
// float or string (incl. E-notation) and must normalize the same way.
func TestMetaMoney(t *testing.T) {
	if metaMoney(nil, "capturedCostSaving") != nil {
		t.Error("metaMoney(nil) -> nil")
	}
	fm := map[string]interface{}{"capturedCostSaving": 12.5}
	if got := metaMoney(fm, "capturedCostSaving"); got == nil || !got.Equal(decimal.RequireFromString("12.5")) {
		t.Errorf("metaMoney float: %v", got)
	}
	sm := map[string]interface{}{"capturedCostSaving": "1.936E-11"}
	got := metaMoney(sm, "capturedCostSaving")
	if got == nil {
		t.Fatal("metaMoney string nil")
	}
	if s := got.String(); strings.ContainsAny(s, "eE") {
		t.Errorf("E-notation leaked from metaMoney: %q", s)
	}
	bad := map[string]interface{}{"capturedCostSaving": true}
	if metaMoney(bad, "capturedCostSaving") != nil {
		t.Error("metaMoney wrong-type -> nil")
	}
	if metaMoney(fm, "missing") != nil {
		t.Error("metaMoney missing -> nil")
	}
}
