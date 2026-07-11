/* ── movers (latest complete bucket vs previous) ─────────────────── */
function renderMovers(g){
  if(g.buckets.length<2){ $('movers').innerHTML='<tr><td colspan="5">Need ≥2 periods</td></tr>'; $('movers-hint').textContent=''; return; }
  /* last bucket may be partial → compare the two most recent COMPLETE buckets when possible */
  const n=g.buckets.length;
  const useLast = n>=3 ? n-2 : n-1;
  const cur=g.matrix[useLast], prev=g.matrix[useLast-1];
  $('movers-hint').textContent=`${bucketLabel(g.buckets[useLast-1])} → ${bucketLabel(g.buckets[useLast])}${useLast===n-2?' (excl. partial latest)':''}`;
  const items=g.names.map((nm,i)=>({nm,p:prev[i],c:cur[i],d:cur[i]-prev[i]}))
    .filter(x=>x.p>0.01||x.c>0.01)
    .sort((a,b)=>Math.abs(b.d)-Math.abs(a.d)).slice(0,8);
  $('movers').innerHTML=items.map(x=>{
    const pc = x.p>0.01 ? (x.d/x.p*100) : null;
    const cls = x.d>0?'up':'down';
    const idx=DATA.dicts[S.groupBy].indexOf(x.nm);
    return `<tr${idx>=0?` class="drill" data-idx="${idx}" style="cursor:pointer" title="click to filter"`:''}><td>${disp(x.nm)}</td><td class="r num">${fmt$(x.p)}</td><td class="r num">${fmt$(x.c)}</td>
      <td class="r num ${cls}">${x.d>=0?'+':''}${fmt$(x.d)}</td>
      <td class="r num ${cls}">${pc===null?'new':(pc>=0?'+':'')+pc.toFixed(1)+'%'}</td></tr>`;
  }).join('');
  $('movers').querySelectorAll('tr.drill').forEach(tr=>tr.addEventListener('click',()=>drillTo(S.groupBy,+tr.dataset.idx,false)));
}
