/* ── OCID lookup ─────────────────────────────────────────────────── */
const ocidTotals = new Map();
for (const [oi,,c] of OCIDS.series.map(r=>[r[0],r[1],r[2]])) ocidTotals.set(oi,(ocidTotals.get(oi)||0)+c);
let ocidSel = -1;
$('ocid-q').addEventListener('input', ()=>{ ocidSel=-1; renderOcidMatches(); });
function renderOcidMatches(){
  const q = $('ocid-q').value.trim().toLowerCase();
  const M = $('ocid-matches'), V = $('ocid-view');
  if (q.length < 4){ M.innerHTML = q ? '<span class="eyebrow">keep typing (min 4 chars)…</span>' : ''; V.innerHTML=''; return; }
  const hits = [];
  OCIDS.list.forEach((o,i)=>{
    if (o.toLowerCase().includes(q) || (OCIDS.info[i][3]||'').toLowerCase().includes(q))
      hits.push([i, ocidTotals.get(i)||0]);
  });
  hits.sort((a,b)=>b[1]-a[1]);
  if (!hits.length){ M.innerHTML='<span class="eyebrow">no match (note: $0-only resources are not indexed)</span>'; V.innerHTML=''; return; }
  M.innerHTML = hits.slice(0,8).map(([i,t])=>{
    const inf=OCIDS.info[i];
    return `<div class="rrow" style="grid-template-columns:1fr 110px;cursor:pointer;padding:4px 6px;border-radius:6px"
      onmouseover="this.style.background='var(--ring)'" onmouseout="this.style.background=''"
      onclick="selectOcid(${i})">
      <span class="nm num" title="${escHtml(OCIDS.list[i])}">${inf[3]?disp(inf[3])+' · ':''}…${escHtml(OCIDS.list[i].slice(-28))}</span>
      <span class="val num">${fmt$(t)}</span></div>`;
  }).join('') + (hits.length>8?`<div class="eyebrow" style="margin-top:4px">+ ${hits.length-8} more — refine search</div>`:'');
  if (hits.length===1) selectOcid(hits[0][0]); else if (ocidSel<0) V.innerHTML='';
}
function selectOcid(oi){
  ocidSel = oi;
  const inf = OCIDS.info[oi];
  const per = new Map();
  let first=1e9, last=-1;
  for (const [o,di,c] of OCIDS.series){ if(o!==oi) continue;
    if(di<first)first=di; if(di>last)last=di;
    const bk = bucketKey(di); per.set(bk,(per.get(bk)||0)+c); }
  const buckets=[...per.keys()].sort();
  const total=[...per.values()].reduce((a,b)=>a+b,0);
  const chips = [['Cost center',inf[0]],['Environment',inf[1]],['Resource type',inf[2]],['Resource name',inf[3]]]
    .map(([k,v])=>`<span class="chip" title="${k}">${k}: <b>${disp(v)}</b></span>`).join(' ');
  const W=1120,H=150,PL=64,PR=10,PT=8,PB=22, iw=W-PL-PR, ih=H-PT-PB;
  const maxV=Math.max(...per.values(),0.01);
  const step=niceStep(maxV/3), yMax=Math.ceil(maxV/step)*step;
  const bw=iw/buckets.length, barW=Math.max(2,Math.min(40,bw*0.66));
  let svg=`<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Cost per ${S.gran} for selected OCID">`;
  for(let v=0;v<=yMax;v+=step){ const y=PT+ih-(v/yMax)*ih;
    svg+=`<line class="gridline" x1="${PL}" x2="${W-PR}" y1="${y}" y2="${y}"/>`;
    svg+=`<text class="ticktxt num" x="${PL-8}" y="${y+3.5}" text-anchor="end">${fmt$(v)}</text>`; }
  buckets.forEach((bk,bi)=>{ const v=per.get(bk); const h=(v/yMax)*ih;
    svg+=`<rect class="barseg" x="${PL+bi*bw+(bw-barW)/2}" y="${PT+ih-h}" width="${barW}" height="${Math.max(h,0.75)}" rx="3" fill="var(--s1)"><title>${bucketLabel(bk)} — ${fmt$2(v)}</title></rect>`;
    const le=Math.ceil(buckets.length/14);
    if(bi%le===0) svg+=`<text class="ticktxt" x="${PL+bi*bw+bw/2}" y="${H-6}" text-anchor="middle">${bucketLabel(bk)}</text>`; });
  svg+='</svg>';
  $('ocid-view').innerHTML=`
    <div style="border-top:1px solid var(--grid);margin:10px 0;padding-top:10px">
      <div class="num" style="font-size:11.5px;color:var(--ink-3);word-break:break-all">${escHtml(OCIDS.list[oi])}</div>
      <div style="display:flex;gap:14px;align-items:baseline;flex-wrap:wrap;margin:8px 0">
        <span class="num" style="font-size:22px;font-weight:650">${fmt$2(total)}</span>
        <span class="eyebrow">total · ${DATA.days[first]} → ${DATA.days[last]}</span>
      </div>
      <div style="margin-bottom:10px">${chips}</div>
      ${svg}
    </div>`;
}
const _updOrig = update;
update = function(){ _updOrig(); if(ocidSel>=0) selectOcid(ocidSel); };

fillFilters();
applyHash();
setTab(activeTab);
update();
