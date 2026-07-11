/* ── stacked bar chart (SVG) ─────────────────────────────────────── */
function renderTrend(g){
  const W=1160,H=300,PL=64,PR=10,PT=12,PB=26;
  const iw=W-PL-PR, ih=H-PT-PB;
  const maxT = Math.max(...g.matrix.map(r=>r.reduce((a,b)=>a+b,0)),1);
  const step = niceStep(maxT/4);
  const yMax = Math.ceil(maxT/step)*step;
  const bw = iw/g.buckets.length;
  const barW = Math.max(2, Math.min(46, bw*0.66));
  let s = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Spend over time, stacked by ${DIM_LABEL[S.groupBy]}">`;
  for(let v=0;v<=yMax;v+=step){
    const y=PT+ih-(v/yMax)*ih;
    s+=`<line class="gridline" x1="${PL}" x2="${W-PR}" y1="${y}" y2="${y}"/>`;
    s+=`<text class="ticktxt num" x="${PL-8}" y="${y+3.5}" text-anchor="end">${fmt$(v)}</text>`;
  }
  s+=`<line class="axisline" x1="${PL}" x2="${W-PR}" y1="${PT+ih}" y2="${PT+ih}"/>`;
  const cols=[];
  g.buckets.forEach((bk,bi)=>{
    const x=PL+bi*bw+(bw-barW)/2;
    let y=PT+ih; const segs=[];
    g.matrix[bi].forEach((v,si)=>{
      if(v<=0) return;
      const h=(v/yMax)*ih; y-=h;
      /* 2px surface gap between stacked segments; 4px rounded cap only on stack top */
      segs.push({y,h:Math.max(h-2,0.75),si,v});
    });
    segs.forEach((sg,k)=>{
      const isTop = k===segs.length-1;
      const rx = isTop?3:0;
      s+=`<rect class="barseg" x="${x}" y="${sg.y}" width="${barW}" height="${sg.h}" rx="${rx}" fill="var(${SLOTS[sg.si]})"/>`;
      if(isTop) s+=`<rect class="barseg" x="${x}" y="${sg.y+3}" width="${barW}" height="${Math.max(sg.h-3,0)}" fill="var(${SLOTS[sg.si]})"/>`;
    });
    const lblEvery=Math.ceil(g.buckets.length/14);
    if(bi%lblEvery===0) s+=`<text class="ticktxt" x="${PL+bi*bw+bw/2}" y="${H-8}" text-anchor="middle">${bucketLabel(bk)}</text>`;
    cols.push({x:PL+bi*bw,bi});
  });
  cols.forEach(c=>{ s+=`<rect class="hover-col" data-bi="${c.bi}" x="${c.x}" y="${PT}" width="${bw}" height="${ih}"/>`; });
  s+='</svg>';
  $('trend').innerHTML=s;
  $('trend').querySelectorAll('.hover-col').forEach(el=>{
    el.addEventListener('mousemove',e=>{
      const bi=+el.dataset.bi, row=g.matrix[bi];
      const tot=row.reduce((a,b)=>a+b,0);
      let h=`<div class="t">${bucketLabel(g.buckets[bi])} — ${fmt$2(tot)}</div>`;
      row.forEach((v,si)=>{ if(v>0.005) h+=`<div class="r"><span><i style="background:var(${SLOTS[si]})"></i><span class="k">${disp(g.names[si])}</span></span><span class="num">${fmt$2(v)}</span></div>`; });
      showTip(h,e.clientX,e.clientY);
    });
    el.addEventListener('mouseleave',hideTip);
  });
  $('trend-legend').innerHTML=g.names.map((n,i)=>`<span class="it"><i style="background:var(${SLOTS[i]})"></i>${disp(n)}</span>`).join('');
  $('trend-hint').textContent=`${g.buckets.length} ${S.gran} buckets · stacked by ${DIM_LABEL[S.groupBy].toLowerCase()}`;
}
function niceStep(x){ const p=Math.pow(10,Math.floor(Math.log10(x||1))); const n=x/p;
  return (n<=1?1:n<=2?2:n<=5?5:10)*p; }
