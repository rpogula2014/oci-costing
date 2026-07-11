/* ── untagged watch (line, SVG) ──────────────────────────────────── */
function renderUntag(rows){
  const per=new Map();
  for(const r of rows){ const bk=bucketKey(r[0]);
    if(!per.has(bk)) per.set(bk,{u:0,t:0});
    const o=per.get(bk); o.t+=r[9];
    if(DATA.dicts.cc[r[2]]==='') o.u+=r[9];
  }
  const buckets=[...per.keys()].sort();
  if(buckets.length<2){ $('untag').innerHTML='<span class="eyebrow">not enough periods</span>'; $('untag-kpi').innerHTML=''; return; }
  /* headline: untagged share of latest complete bucket vs previous */
  {
    const n=buckets.length, useLast=n>=3?n-2:n-1;
    const c=per.get(buckets[useLast]), p=per.get(buckets[useLast-1]);
    const cp=c.t?c.u/c.t*100:0, pp=p.t?p.u/p.t*100:0, d=cp-pp;
    const cls=d>0.05?'up':d<-0.05?'down':'';
    const arrow=d>0.05?'▲':d<-0.05?'▼':'—';
    $('untag-kpi').innerHTML=
      `<span class="v num ${cls}" style="font-size:22px;font-weight:600">${cp.toFixed(1)}%</span>
       <span style="margin-left:8px">of spend untagged in ${bucketLabel(buckets[useLast])} (${fmt$(c.u)})</span>
       <span class="num ${cls}" style="margin-left:12px">${arrow} ${Math.abs(d).toFixed(1)} pts</span>
       <span style="margin-left:4px">vs ${bucketLabel(buckets[useLast-1])} (${pp.toFixed(1)}%)</span>`;
  }
  const W=1160,H=170,PL=64,PR=10,PT=10,PB=24, iw=W-PL-PR, ih=H-PT-PB;
  const vals=buckets.map(b=>per.get(b));
  const maxP=Math.max(...vals.map(v=>v.t?v.u/v.t*100:0),10);
  const step=niceStep(maxP/3), yMax=Math.ceil(maxP/step)*step;
  const X=i=>PL+iw*(buckets.length===1?0.5:i/(buckets.length-1));
  const Y=p=>PT+ih-(p/yMax)*ih;
  let s=`<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Untagged share of spend per period">`;
  for(let v=0;v<=yMax;v+=step){ s+=`<line class="gridline" x1="${PL}" x2="${W-PR}" y1="${Y(v)}" y2="${Y(v)}"/>`;
    s+=`<text class="ticktxt num" x="${PL-8}" y="${Y(v)+3.5}" text-anchor="end">${v}%</text>`; }
  const pts=vals.map((v,i)=>`${X(i)},${Y(v.t?v.u/v.t*100:0)}`).join(' ');
  s+=`<polyline points="${pts}" fill="none" stroke="var(--s6)" stroke-width="2" stroke-linejoin="round"/>`;
  vals.forEach((v,i)=>{ const p=v.t?v.u/v.t*100:0;
    s+=`<circle cx="${X(i)}" cy="${Y(p)}" r="3.5" fill="var(--s6)" stroke="var(--surface-1)" stroke-width="2"
        data-i="${i}" class="upt"/>`;
    const le=Math.ceil(buckets.length/14);
    if(i%le===0) s+=`<text class="ticktxt" x="${X(i)}" y="${H-6}" text-anchor="middle">${bucketLabel(buckets[i])}</text>`; });
  s+='</svg>';
  $('untag').innerHTML=s;
  $('untag').querySelectorAll('.upt').forEach(el=>{
    el.addEventListener('mousemove',e=>{ const i=+el.dataset.i,v=vals[i];
      showTip(`<div class="t">${bucketLabel(buckets[i])}</div>
        <div class="r"><span class="k">untagged</span><span class="num">${fmt$2(v.u)}</span></div>
        <div class="r"><span class="k">share</span><span class="num">${(v.t?v.u/v.t*100:0).toFixed(1)}%</span></div>`,e.clientX,e.clientY); });
    el.addEventListener('mouseleave',hideTip);
  });
}
