/* ── resource-level movers: per-resource anomaly scan ────────────── */
function renderResMovers(rows){
  const bset=new Set(); for(const r of rows) bset.add(bucketKey(r[0]));
  const buckets=[...bset].sort();
  if(buckets.length<2){ $('rmovers').innerHTML='<tr><td colspan="7">Need ≥2 periods</td></tr>'; $('rmovers-hint').textContent=''; return; }
  const n=buckets.length, useLast = n>=3 ? n-2 : n-1;
  const bCur=buckets[useLast], bPrev=buckets[useLast-1];
  const per=new Map();
  for(const r of rows){
    const bk=bucketKey(r[0]); if(bk!==bCur&&bk!==bPrev) continue;
    if(!per.has(r[7])) per.set(r[7],{p:0,c:0,svc:r[5],cc:r[2]});
    const o=per.get(r[7]); if(bk===bCur) o.c+=r[9]; else o.p+=r[9];
  }
  const items=[...per.entries()].map(([i,o])=>({i,...o,d:o.c-o.p}))
    .filter(x=>Math.abs(x.d)>=1)
    .sort((a,b)=>Math.abs(b.d)-Math.abs(a.d)).slice(0,12);
  $('rmovers-hint').textContent=`${bucketLabel(bPrev)} → ${bucketLabel(bCur)}${useLast===n-2?' (excl. partial latest)':''} · per-resource, |Δ| ≥ $1 · click row to filter`;
  if(!items.length){ $('rmovers').innerHTML='<tr><td colspan="7">no significant movers</td></tr>'; return; }
  $('rmovers').innerHTML=items.map(x=>{
    const pc = x.p>0.01 ? (x.d/x.p*100) : null;
    const cls = x.d>0?'up':'down';
    const gone = x.c<=0.01;
    return `<tr class="drill" data-rn="${x.i}" style="cursor:pointer" title="click to filter to this resource">
      <td>${disp(DATA.dicts.rname[x.i])}</td><td>${disp(DATA.dicts.svc[x.svc])}</td><td>${disp(DATA.dicts.cc[x.cc])}</td>
      <td class="r num">${fmt$(x.p)}</td><td class="r num">${fmt$(x.c)}</td>
      <td class="r num ${cls}">${x.d>=0?'+':''}${fmt$(x.d)}</td>
      <td class="r num ${cls}">${pc===null?'new':gone?'gone':(pc>=0?'+':'')+pc.toFixed(1)+'%'}</td></tr>`;
  }).join('');
  $('rmovers').querySelectorAll('tr.drill').forEach(tr=>tr.addEventListener('click',()=>drillTo('rname',+tr.dataset.rn)));
}
