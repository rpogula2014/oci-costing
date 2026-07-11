/* ── text-search match strip ─────────────────────────────────────── */
function renderTextMatches(rows){
  const el=$('text-matches');
  if(!S.text){ el.innerHTML=''; return; }
  const per=new Map();
  for(const r of rows){ const n=DATA.dicts.rname[r[7]]; per.set(n,(per.get(n)||0)+r[9]); }
  const ranked=[...per.entries()].sort((a,b)=>b[1]-a[1]);
  if(!ranked.length){ el.innerHTML='<span class="eyebrow">no resource names match “'+escHtml(S.text)+'”</span>'; return; }
  el.innerHTML='<span class="eyebrow" style="margin-right:8px">'+ranked.length+' resource name'+(ranked.length>1?'s':'')+' match:</span>'+
    ranked.slice(0,10).map(([n,v])=>`<span class="chip" style="margin:2px 4px 2px 0">${disp(n)} <b class="num">${fmt$(v)}</b></span>`).join('')+
    (ranked.length>10?`<span class="eyebrow"> + ${ranked.length-10} more — group by resource name to see all</span>`:'');
}
