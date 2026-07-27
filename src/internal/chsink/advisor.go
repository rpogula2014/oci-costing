package chsink

import (
	"context"
	"fmt"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"

	"oci-costing/internal/optimizer"
)

// AdvisorLoad writes a Cloud Advisor snapshot for snapshotDate into
// advisor_recommendations and advisor_history. It is idempotent: the day's rows
// are deleted first (lightweight DELETE) so a same-day re-run replaces rather
// than duplicates, keeping the read side a plain MergeTree scan.
func AdvisorLoad(ctx context.Context, conn driver.Conn, snapshotDate time.Time, snap *optimizer.Snapshot) (int, int, error) {
	day := snapshotDate.UTC().Truncate(24 * time.Hour)

	if err := conn.Exec(ctx, "DELETE FROM advisor_recommendations WHERE snapshot_date = ?", day); err != nil {
		return 0, 0, fmt.Errorf("clear advisor_recommendations for %s: %w", day.Format("2006-01-02"), err)
	}
	if err := conn.Exec(ctx, "DELETE FROM advisor_history WHERE snapshot_date = ?", day); err != nil {
		return 0, 0, fmt.Errorf("clear advisor_history for %s: %w", day.Format("2006-01-02"), err)
	}

	recN, err := loadRecommendations(ctx, conn, day, snap.Recs)
	if err != nil {
		return 0, 0, err
	}
	histN, err := loadHistory(ctx, conn, day, snap.Hist)
	if err != nil {
		return recN, 0, err
	}
	return recN, histN, nil
}

func loadRecommendations(ctx context.Context, conn driver.Conn, day time.Time, rows []optimizer.RecRow) (int, error) {
	batch, err := conn.PrepareBatch(ctx, `INSERT INTO advisor_recommendations (
		snapshot_date, resource_action_id, recommendation_id, resource_id, resource_name,
		resource_type, compartment_id, region, recommendation_name, category, importance,
		status, time_status_begin, estimated_cost_saving, captured_cost_saving, currency,
		action_type, action_url, recommended_shape, recommended_cpu, recommended_memory,
		aggregation_interval)`)
	if err != nil {
		return 0, fmt.Errorf("prepare advisor_recommendations batch: %w", err)
	}
	for i, r := range rows {
		if err := batch.Append(
			day, r.ResourceActionID, r.RecommendationID, r.ResourceID, r.ResourceName,
			r.ResourceType, r.CompartmentID, r.Region, r.RecommendationName, r.Category, r.Importance,
			r.Status, r.TimeStatusBegin, r.EstimatedCostSaving, r.CapturedCostSaving, r.Currency,
			r.ActionType, r.ActionURL, r.RecommendedShape, r.RecommendedCPU, r.RecommendedMemory,
			r.AggregationInterval,
		); err != nil {
			return 0, fmt.Errorf("append advisor_recommendations row %d: %w", i, err)
		}
	}
	if err := batch.Send(); err != nil {
		return 0, fmt.Errorf("send advisor_recommendations batch: %w", err)
	}
	return len(rows), nil
}

func loadHistory(ctx context.Context, conn driver.Conn, day time.Time, rows []optimizer.HistRow) (int, error) {
	batch, err := conn.PrepareBatch(ctx, `INSERT INTO advisor_history (
		snapshot_date, history_id, recommendation_id, resource_id, resource_type,
		compartment_id, resource_action_id, recommendation_name, status, time_created,
		estimated_cost_saving, captured_cost_saving, currency)`)
	if err != nil {
		return 0, fmt.Errorf("prepare advisor_history batch: %w", err)
	}
	for i, h := range rows {
		if err := batch.Append(
			day, h.HistoryID, h.RecommendationID, h.ResourceID, h.ResourceType,
			h.CompartmentID, h.ResourceActionID, h.RecommendationName, h.Status, h.TimeCreated,
			h.EstimatedCostSaving, h.CapturedCostSaving, h.Currency,
		); err != nil {
			return 0, fmt.Errorf("append advisor_history row %d: %w", i, err)
		}
	}
	if err := batch.Send(); err != nil {
		return 0, fmt.Errorf("send advisor_history batch: %w", err)
	}
	return len(rows), nil
}
