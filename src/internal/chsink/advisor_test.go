package chsink

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"

	"oci-costing/internal/optimizer"
)

// fakeBatch records appended rows and whether it was sent. Embedding driver.Batch
// (nil) satisfies the full interface; only the two methods AdvisorLoad uses are
// overridden.
type fakeBatch struct {
	driver.Batch
	rows int
	sent bool
}

func (b *fakeBatch) Append(v ...any) error { b.rows++; return nil }
func (b *fakeBatch) Send() error           { b.sent = true; return nil }

// fakeConn records the ordered sequence of DELETE (Exec) and INSERT (PrepareBatch)
// operations plus the snapshot_date arg passed to each DELETE.
type fakeConn struct {
	driver.Conn
	ops       []string    // "delete:<table>" / "batch:<table>" in call order
	deleteDay []time.Time // snapshot_date arg for each Exec
	batches   []*fakeBatch
}

func (c *fakeConn) Exec(_ context.Context, query string, args ...any) error {
	c.ops = append(c.ops, "delete:"+table(query))
	if len(args) > 0 {
		if d, ok := args[0].(time.Time); ok {
			c.deleteDay = append(c.deleteDay, d)
		}
	}
	return nil
}

func (c *fakeConn) PrepareBatch(_ context.Context, query string, _ ...driver.PrepareBatchOption) (driver.Batch, error) {
	c.ops = append(c.ops, "batch:"+table(query))
	b := &fakeBatch{}
	c.batches = append(c.batches, b)
	return b, nil
}

// table extracts the target table name from an INSERT/DELETE statement.
func table(q string) string {
	if strings.Contains(q, "advisor_recommendations") {
		return "advisor_recommendations"
	}
	if strings.Contains(q, "advisor_history") {
		return "advisor_history"
	}
	return "?"
}

func sampleSnap() *optimizer.Snapshot {
	return &optimizer.Snapshot{
		Recs: []optimizer.RecRow{{ResourceActionID: "a1"}, {ResourceActionID: "a2"}},
		Hist: []optimizer.HistRow{{HistoryID: "h1"}},
	}
}

// Finding 7(d): a same-day re-run must replace, not duplicate — AdvisorLoad
// deletes the day's rows in BOTH tables before inserting, and does so on every
// run. Finding 7(f): because dedup is by snapshot_date delete-then-insert, a
// second run of identical data yields the same counts, never doubled.
func TestAdvisorLoadIsIdempotentDeleteThenInsert(t *testing.T) {
	conn := &fakeConn{}
	day := time.Date(2026, 7, 17, 13, 45, 0, 0, time.UTC)

	recN, histN, err := AdvisorLoad(context.Background(), conn, day, sampleSnap())
	if err != nil {
		t.Fatalf("AdvisorLoad: %v", err)
	}
	if recN != 2 || histN != 1 {
		t.Errorf("counts: want 2/1, got %d/%d", recN, histN)
	}

	// Order: both DELETEs must precede both INSERT batches (delete-then-insert).
	want := []string{
		"delete:advisor_recommendations",
		"delete:advisor_history",
		"batch:advisor_recommendations",
		"batch:advisor_history",
	}
	if strings.Join(conn.ops, ",") != strings.Join(want, ",") {
		t.Fatalf("op order = %v, want %v", conn.ops, want)
	}

	// snapshot_date must be truncated to the UTC day (drops the 13:45 time-of-day).
	wantDay := time.Date(2026, 7, 17, 0, 0, 0, 0, time.UTC)
	for _, d := range conn.deleteDay {
		if !d.Equal(wantDay) {
			t.Errorf("DELETE snapshot_date = %v, want truncated %v", d, wantDay)
		}
	}

	// Batches must actually be sent, with the right row counts.
	if len(conn.batches) != 2 || conn.batches[0].rows != 2 || conn.batches[1].rows != 1 {
		t.Fatalf("batch rows: %+v", conn.batches)
	}
	for i, b := range conn.batches {
		if !b.sent {
			t.Errorf("batch %d not sent", i)
		}
	}

	// Second same-day run: another pair of DELETEs fires first, proving each run
	// clears the day before inserting — so repeated runs never accumulate.
	if _, _, err := AdvisorLoad(context.Background(), conn, day, sampleSnap()); err != nil {
		t.Fatalf("AdvisorLoad rerun: %v", err)
	}
	deletes := 0
	for _, op := range conn.ops {
		if strings.HasPrefix(op, "delete:") {
			deletes++
		}
	}
	if deletes != 4 {
		t.Errorf("want 4 DELETEs across 2 runs (2 each), got %d", deletes)
	}
}
