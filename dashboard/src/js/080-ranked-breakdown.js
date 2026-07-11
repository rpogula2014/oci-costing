/* ── ranked breakdown ────────────────────────────────────────────── */
function renderRank(g){
  const total=[...g.totals.values()].reduce((a,b)=>a+b,0)||1;
  const rows=g.ranked.slice(0,12);
  const max=rows.length?rows[0][1]:1;
  $('rank-title').textContent=`By ${DIM_LABEL[S.groupBy].toLowerCase()}`;
  $('rank').innerHTML=rows.map(([n,v])=>{
    const sl=slotOf[S.groupBy].get(n)??7;
    const idx=DATA.dicts[S.groupBy].indexOf(n);
    const on=idx>=0&&S.f[S.groupBy]===String(idx);
    return `<div class="rrow${idx>=0?' drill':''}"${idx>=0?` data-idx="${idx}" style="cursor:pointer" title="${on?'click to clear filter':'click to filter + jump to detail'}"`:''}>
      <span class="nm" title="${disp(n)}">${disp(n)}${on?' ●':''}</span>
      <span class="track"><span class="fill" style="width:${Math.max(v/max*100,0.5)}%;background:var(${SLOTS[sl]})"></span></span>
      <span class="val num">${fmt$(v)}</span>
      <span class="pct num">${(v/total*100).toFixed(1)}%</span>
    </div>`;
  }).join('') + (g.ranked.length>12?`<div class="eyebrow" style="margin-top:6px">+ ${g.ranked.length-12} more in table below</div>`:'');
  $('rank').querySelectorAll('.drill').forEach(el=>el.addEventListener('click',()=>drillTo(S.groupBy,+el.dataset.idx)));
}
