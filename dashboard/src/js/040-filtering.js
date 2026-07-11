/* ── filtering ───────────────────────────────────────────────────── */
function filteredRows(){
  let minDay = 0;
  const last = DATA.days.length-1;
  if (S.range==='mtd'){ const m = DATA.days[last].slice(0,7); minDay = DATA.days.findIndex(d=>d.startsWith(m)); }
  else if (S.range!=='all'){ const cut = new Date(D0[last]); cut.setUTCDate(cut.getUTCDate()-(+S.range)+1);
    minDay = DATA.days.findIndex(d => new Date(d+'T00:00:00Z') >= cut); if(minDay<0) minDay=0; }
  let textSet = null;
  if (S.text){
    const q = S.text.toLowerCase();
    textSet = new Set();
    DATA.dicts.rname.forEach((v,i)=>{ if(v.toLowerCase().includes(q)) textSet.add(i); });
  }
  const out = [];
  for (const r of DATA.rows){
    if (r[0] < minDay) continue;
    if (textSet && !textSet.has(r[7])) continue;
    let ok = true;
    for (const d of Object.keys(DIMS)){
      if (S.f[d] === '') continue;
      if (r[DIMS[d]] !== +S.f[d]) { ok=false; break; }
    }
    if (ok) out.push(r);
  }
  return out;
}
