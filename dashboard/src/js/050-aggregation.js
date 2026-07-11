/* ── aggregation ─────────────────────────────────────────────────── */
function groupSeries(rows){
  /* returns {buckets:[k...], names:[...(≤7 + Other)], matrix[bucket][series]} */
  const dim = S.groupBy, di = DIMS[dim];
  const bset = new Map();
  const totals = new Map();
  for (const r of rows){
    const bk = bucketKey(r[0]);
    if (!bset.has(bk)) bset.set(bk, new Map());
    const name = DATA.dicts[dim][r[di]];
    const m = bset.get(bk); m.set(name,(m.get(name)||0)+r[9]);
    totals.set(name,(totals.get(name)||0)+r[9]);
  }
  const buckets = [...bset.keys()].sort();
  const ranked = [...totals.entries()].sort((a,b)=>b[1]-a[1]);
  const top = ranked.slice(0,7).map(e=>e[0]);
  const hasOther = ranked.length>7;
  const names = hasOther ? [...top,'Other'] : top;
  const matrix = buckets.map(bk => {
    const m = bset.get(bk); const row = names.map(()=>0);
    for (const [n,v] of m){ const i = top.indexOf(n); row[i>=0?i:names.length-1]+=v; }
    return row;
  });
  return {buckets, names, matrix, totals, ranked};
}
