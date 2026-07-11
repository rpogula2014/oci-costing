/* ── controls wiring ─────────────────────────────────────────────── */
function fillFilters(){
  for(const d of Object.keys(DIMS)){
    const sel=$('f-'+d);
    const byIdx = DATA.dicts[d].map((v,i)=>[i,v]).sort((a,b)=>disp(a[1]).localeCompare(disp(b[1])));
    sel.innerHTML=`<option value="">All</option>`+byIdx.map(([i,v])=>`<option value="${i}">${disp(v)}</option>`).join('');
    sel.onchange=()=>{ S.f[d]=sel.value; update(); };
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
$('clear').onclick=()=>{ for(const d of Object.keys(DIMS)){ S.f[d]=''; $('f-'+d).value=''; }
  S.range='all'; $('range').value='all'; S.text=''; $('f-text').value=''; update(); };
$('theme-btn').onclick=()=>{
  const t=document.documentElement.dataset.theme==='dark'?'light':'dark';
  document.documentElement.dataset.theme=t;
  try{localStorage.setItem('finops-theme',t)}catch(e){}
  update();
};
try{ const t=localStorage.getItem('finops-theme'); if(t) document.documentElement.dataset.theme=t; }catch(e){}
