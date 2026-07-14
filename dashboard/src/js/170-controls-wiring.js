/* ── controls wiring ─────────────────────────────────────────────── */
/* Dependent filters: each select only offers values present in rows matching
   the selections of filters to its LEFT; changing one refreshes those to its right. */
const DIM_ORDER = Object.keys(DIMS);
function availableFor(d){
  const left = DIM_ORDER.slice(0, DIM_ORDER.indexOf(d)).filter(x=>S.f[x]!=='');
  if(!left.length) return null; // null = all values available
  const set = new Set();
  for(const r of DATA.rows){
    let ok = true;
    for(const x of left){ if(r[DIMS[x]] !== +S.f[x]){ ok=false; break; } }
    if(ok) set.add(r[DIMS[d]]);
  }
  return set;
}
function renderFilterOptions(d){
  const sel=$('f-'+d);
  const avail = availableFor(d);
  const byIdx = DATA.dicts[d].map((v,i)=>[i,v])
    .filter(([i])=>!avail || avail.has(i))
    .sort((a,b)=>disp(a[1]).localeCompare(disp(b[1])));
  sel.innerHTML=`<option value="">All</option>`+byIdx.map(([i,v])=>`<option value="${i}">${disp(v)}</option>`).join('');
  sel.value=S.f[d];
  if(sel.value!==S.f[d]){ S.f[d]=''; sel.value=''; } // selection no longer valid under left filters
}
function refreshFiltersFrom(pos){
  for(let k=pos;k<DIM_ORDER.length;k++) renderFilterOptions(DIM_ORDER[k]);
}
function fillFilters(){
  for(const d of DIM_ORDER){
    renderFilterOptions(d);
    $('f-'+d).onchange=()=>{ S.f[d]=$('f-'+d).value; refreshFiltersFrom(DIM_ORDER.indexOf(d)+1); update(); };
  }
}
$('gran-seg').querySelectorAll('button').forEach(b=>b.onclick=()=>{
  $('gran-seg').querySelectorAll('button').forEach(x=>x.classList.remove('on'));
  b.classList.add('on'); S.gran=b.dataset.g; update();
});
$('groupby').onchange=e=>{ S.groupBy=e.target.value; update(); };
$('range').onchange=e=>{ S.range=e.target.value; update(); };
$('detail-g').addEventListener('change',()=>{ detExpanded.clear(); renderDetailRows(); syncHash(); });
$('detail-g2').addEventListener('change',()=>{ detExpanded.clear(); renderDetailRows(); syncHash(); });
let _detT=null;
$('detail-q').addEventListener('input',()=>{ clearTimeout(_detT); _detT=setTimeout(renderDetailRows,150); });
document.querySelectorAll('#detail-head .sortable').forEach(th=>th.addEventListener('click',()=>{
  const k=th.dataset.sk;
  if(detSort.key===k) detSort.dir*=-1; else { detSort.key=k; detSort.dir = k==='cost' ? -1 : 1; }
  renderDetailRows();
}));
let _textT=null;
$('f-text').addEventListener('input',()=>{ clearTimeout(_textT);
  _textT=setTimeout(()=>{ S.text=$('f-text').value.trim(); update(); },200); });
$('clear').onclick=()=>{ for(const d of Object.keys(DIMS)){ S.f[d]=''; }
  refreshFiltersFrom(0);
  S.range='all'; $('range').value='all'; S.text=''; $('f-text').value=''; update(); };
$('theme-btn').onclick=()=>{
  const t=document.documentElement.dataset.theme==='dark'?'light':'dark';
  document.documentElement.dataset.theme=t;
  try{localStorage.setItem('finops-theme',t)}catch(e){}
  update();
};
try{ const t=localStorage.getItem('finops-theme'); if(t) document.documentElement.dataset.theme=t; }catch(e){}
