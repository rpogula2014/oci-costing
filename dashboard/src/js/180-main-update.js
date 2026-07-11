/* ── main update ─────────────────────────────────────────────────── */
function markActive(){
  let n=0;
  for(const d of Object.keys(DIMS)){ const on=S.f[d]!==''; $('f-'+d).classList.toggle('active',on); if(on)n++; }
  const t=S.text!==''; $('f-text').classList.toggle('active',t); if(t)n++;
  $('clear').textContent = n ? `Reset (${n})` : 'Reset';
}
function update(){
  markActive();
  const rows=filteredRows();
  const g=groupSeries(rows);
  $('range-label').textContent = rows.length
    ? `${DATA.days[Math.min(...rows.map(r=>r[0]))]} → ${DATA.days[Math.max(...rows.map(r=>r[0]))]}`
    : 'no data for filter';
  renderTextMatches(rows);
  renderKPIs(rows,g);
  renderTrend(g);
  renderRank(g);
  renderMovers(g);
  renderResMovers(rows);
  renderCompare(rows);
  renderUntag(rows);
  renderIdle(rows);
  renderDetail(rows);
  syncHash();
}
