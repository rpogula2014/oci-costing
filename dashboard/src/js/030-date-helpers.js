/* ── date helpers ────────────────────────────────────────────────── */
const D0 = DATA.days.map(s => new Date(s+'T00:00:00Z'));
function bucketKey(di){
  const dt = D0[di];
  if (S.gran==='day')   return DATA.days[di];
  if (S.gran==='month') return DATA.days[di].slice(0,7);
  const t = new Date(dt); const dow = (t.getUTCDay()+6)%7; t.setUTCDate(t.getUTCDate()-dow);
  return t.toISOString().slice(0,10); /* ISO week start (Mon) */
}
function bucketLabel(k){
  if (S.gran==='month'){ const [y,m]=k.split('-'); return new Date(Date.UTC(y,m-1,1)).toLocaleString('en-US',{month:'short',timeZone:'UTC'}) + ' ’'+String(y).slice(2); }
  const d = new Date(k+'T00:00:00Z');
  return d.toLocaleString('en-US',{month:'short',day:'numeric',timeZone:'UTC'});
}
