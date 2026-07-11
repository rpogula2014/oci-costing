/* ── compare periods (A vs B by dimension) ───────────────────────── */
S.cmp={a:'',b:'',dim:'cc',touched:false};
let _cmpRows=[];
function renderCompare(rows){
  _cmpRows=rows;
  const bset=new Set(); for(const r of rows) bset.add(bucketKey(r[0]));
  const buckets=[...bset].sort();
  const selA=$('cmp-a'), selB=$('cmp-b');
  if(buckets.length<2){
    selA.innerHTML=selB.innerHTML='';
    $('cmp-body').innerHTML='<tr><td colspan="5">Need ≥2 periods in range</td></tr>';
    $('cmp-hint').textContent=''; return;
  }
  const n=buckets.length, useLast=n>=3?n-2:n-1;
  if(!buckets.includes(S.cmp.a)) S.cmp.a=buckets[useLast-1];
  if(!buckets.includes(S.cmp.b)) S.cmp.b=buckets[useLast];
  const opts=buckets.map(b=>`<option value="${b}">${bucketLabel(b)}</option>`).join('');
  selA.innerHTML=opts; selB.innerHTML=opts;
  selA.value=S.cmp.a; selB.value=S.cmp.b;
  $('cmp-dim').value=S.cmp.dim;
  const dim=S.cmp.dim, di=DIMS[dim];
  $('cmp-name-h').textContent=DIM_LABEL[dim];
  $('cmp-a-h').textContent=bucketLabel(S.cmp.a);
  $('cmp-b-h').textContent=bucketLabel(S.cmp.b);
  const per=new Map();
  let tA=0,tB=0;
  for(const r of rows){
    const bk=bucketKey(r[0]);
    const inA=bk===S.cmp.a, inB=bk===S.cmp.b;
    if(!inA&&!inB) continue;
    if(!per.has(r[di])) per.set(r[di],{a:0,b:0});
    const o=per.get(r[di]);
    if(inA){ o.a+=r[9]; tA+=r[9]; }
    if(inB){ o.b+=r[9]; tB+=r[9]; }
  }
  const items=[...per.entries()].map(([i,o])=>({i,...o,d:o.b-o.a}))
    .sort((x,y)=>Math.abs(y.d)-Math.abs(x.d));
  const shown=items.slice(0,30);
  $('cmp-hint').textContent=`${DIM_LABEL[dim].toLowerCase()} · sorted by |Δ|`+(items.length>30?` · top 30 of ${items.length}`:'')+' · click row to filter';
  const rowT=x=>{
    const pc=x.a>0.01?(x.d/x.a*100):null;
    const cls=x.d>0?'up':'down';
    return `<tr class="drill" data-idx="${x.i}" style="cursor:pointer" title="click to filter">
      <td>${disp(DATA.dicts[dim][x.i])}</td>
      <td class="r num">${fmt$(x.a)}</td><td class="r num">${fmt$(x.b)}</td>
      <td class="r num ${cls}">${x.d>=0?'+':''}${fmt$(x.d)}</td>
      <td class="r num ${cls}">${pc===null?'new':x.b<=0.01?'gone':(pc>=0?'+':'')+pc.toFixed(1)+'%'}</td></tr>`;
  };
  const td=tB-tA, tpc=tA>0.01?(td/tA*100):null;
  const tcls=td>0?'up':'down';
  $('cmp-body').innerHTML=
    `<tr style="font-weight:600"><td>Total</td>
      <td class="r num">${fmt$(tA)}</td><td class="r num">${fmt$(tB)}</td>
      <td class="r num ${tcls}">${td>=0?'+':''}${fmt$(td)}</td>
      <td class="r num ${tcls}">${tpc===null?'—':(tpc>=0?'+':'')+tpc.toFixed(1)+'%'}</td></tr>`
    + shown.map(rowT).join('');
  $('cmp-body').querySelectorAll('tr.drill').forEach(tr=>tr.addEventListener('click',()=>drillTo(dim,+tr.dataset.idx)));
}
$('cmp-a').addEventListener('change',e=>{ S.cmp.a=e.target.value; S.cmp.touched=true; renderCompare(_cmpRows); syncHash(); });
$('cmp-b').addEventListener('change',e=>{ S.cmp.b=e.target.value; S.cmp.touched=true; renderCompare(_cmpRows); syncHash(); });
$('cmp-dim').addEventListener('change',e=>{ S.cmp.dim=e.target.value; S.cmp.touched=true; renderCompare(_cmpRows); syncHash(); });
