/* ── shareable URL state (#gran=…&g=…&f.env=…) ───────────────────── */
function syncHash(){
  const p=new URLSearchParams();
  if(S.gran!=='week') p.set('gran',S.gran);
  if(S.groupBy!=='cc') p.set('g',S.groupBy);
  if(S.range!=='all') p.set('r',S.range);
  if(S.text) p.set('q',S.text);
  for(const d of Object.keys(DIMS)) if(S.f[d]!=='') p.set('f.'+d,S.f[d]);
  const dg=$('detail-g').value, dg2=$('detail-g2').value;
  if(dg) p.set('dg',dg);
  if(dg2) p.set('dg2',dg2);
  if(activeTab!=='overview') p.set('tab',activeTab);
  if(S.cmp.touched){
    if(S.cmp.a) p.set('ca',S.cmp.a);
    if(S.cmp.b) p.set('cb',S.cmp.b);
    if(S.cmp.dim!=='cc') p.set('cd',S.cmp.dim);
  }
  const s=p.toString();
  try{ history.replaceState(null,'',s?'#'+s:location.pathname+location.search); }catch(e){}
}
function applyHash(){
  if(location.hash.length<2) return;
  const p=new URLSearchParams(location.hash.slice(1));
  const gran=p.get('gran');
  if(['day','week','month'].includes(gran)){ S.gran=gran;
    $('gran-seg').querySelectorAll('button').forEach(b=>b.classList.toggle('on',b.dataset.g===gran)); }
  const g=p.get('g');
  if(g&&DIMS[g]!==undefined){ S.groupBy=g; $('groupby').value=g; }
  const r=p.get('r');
  if(r){ $('range').value=r; if($('range').value===r) S.range=r; else $('range').value=S.range; }
  const q=p.get('q');
  if(q){ S.text=q; $('f-text').value=q; }
  for(const d of Object.keys(DIMS)){
    const v=p.get('f.'+d);
    if(v!=null && DATA.dicts[d][+v]!==undefined){ S.f[d]=v; $('f-'+d).value=v; }
  }
  for(const [k,id] of [['dg','detail-g'],['dg2','detail-g2']]){
    const v=p.get(k);
    if(v!=null){ $(id).value=v; if($(id).value!==v) $(id).value=''; }
  }
  const t=p.get('tab');
  if(['overview','investigate','hygiene'].includes(t)) activeTab=t;
  if(p.get('ca')){ S.cmp.a=p.get('ca'); S.cmp.touched=true; }
  if(p.get('cb')){ S.cmp.b=p.get('cb'); S.cmp.touched=true; }
  const cd=p.get('cd');
  if(cd&&DIMS[cd]!==undefined){ S.cmp.dim=cd; S.cmp.touched=true; }
}
