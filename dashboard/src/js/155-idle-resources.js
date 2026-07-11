/* ── idle / suspect resources: flat cost for months = nobody touched it ──
   Compares per-month DAILY rates (month totals differ ~10% just from month
   length). Thresholds tuned on 2026-01..06 data: 30% admits real orphans
   (LBs at 25%), $2000 ceiling keeps the flat migration VM in scope. */
const IDLE_MAX_MO=2000, IDLE_MIN_MO=1, IDLE_SPREAD=0.30, IDLE_MIN_MONTHS=3;
function renderIdle(rows){
  const daysInM=mo=>{const[y,m]=mo.split('-').map(Number);return new Date(Date.UTC(y,m,0)).getUTCDate();};
  const per=new Map();   // rname idx → {m: month→cost, rtype, svc, cc}
  let lastDi=-1;
  for(const r of rows){
    if(r[0]>lastDi) lastDi=r[0];
    const mo=DATA.days[r[0]].slice(0,7);
    if(!per.has(r[7])) per.set(r[7],{m:new Map(),rtype:r[6],svc:r[5],cc:r[2]});
    const o=per.get(r[7]); o.m.set(mo,(o.m.get(mo)||0)+r[9]);
  }
  if(lastDi<0){ $('idle-body').innerHTML='<tr><td colspan="8">no data</td></tr>'; $('idle-hint').textContent=''; return; }
  /* complete months only: drop latest month if data stops before month end */
  const lastDay=DATA.days[lastDi];
  const partial=+lastDay.slice(8,10) < daysInM(lastDay.slice(0,7));
  const months=[...new Set(rows.map(r=>DATA.days[r[0]].slice(0,7)))].sort();
  const complete=partial?months.slice(0,-1):months;
  if(complete.length<IDLE_MIN_MONTHS){
    $('idle-body').innerHTML=`<tr><td colspan="8">need ≥${IDLE_MIN_MONTHS} complete months in range</td></tr>`;
    $('idle-hint').textContent=''; return;
  }
  const win=complete.slice(-6);
  const items=[];
  for(const [rn,o] of per){
    /* walk back from the most recent complete month while present; daily rate per month */
    const vals=[];
    for(let i=win.length-1;i>=0;i--){
      const v=o.m.get(win[i]);
      if(v===undefined||v<=0.01) break;
      vals.unshift(v/daysInM(win[i]));
    }
    if(vals.length<IDLE_MIN_MONTHS) continue;
    const mean=vals.reduce((a,b)=>a+b,0)/vals.length;
    const meanMo=mean*30.4;
    if(meanMo<IDLE_MIN_MO||meanMo>IDLE_MAX_MO) continue;
    const spread=(Math.max(...vals)-Math.min(...vals))/mean;
    if(spread>IDLE_SPREAD) continue;
    items.push({rn,meanMo,spread,n:vals.length,rtype:o.rtype,svc:o.svc,cc:o.cc});
  }
  items.sort((a,b)=>b.meanMo-a.meanMo);
  const shown=items.slice(0,20);
  $('idle-hint').textContent=`daily rate flat ±${IDLE_SPREAD*100}% for ≥${IDLE_MIN_MONTHS} complete months, $${IDLE_MIN_MO}–$${IDLE_MAX_MO}/mo · ${items.length} found`+(items.length>20?' · top 20':'')+' · click row to filter';
  $('idle-body').innerHTML = shown.length ? shown.map(x=>`<tr class="drill" data-rn="${x.rn}" style="cursor:pointer" title="click to filter">
    <td>${disp(DATA.dicts.rname[x.rn])}</td><td>${disp(DATA.dicts.rtype[x.rtype])}</td><td>${disp(DATA.dicts.svc[x.svc])}</td><td>${disp(DATA.dicts.cc[x.cc])}</td>
    <td class="r num">${fmt$(x.meanMo)}</td><td class="r num">${(x.spread*100).toFixed(0)}%</td><td class="r num">${x.n}</td><td class="r num">${fmt$(x.meanMo*12)}</td></tr>`).join('')
    : '<tr><td colspan="8">none matched the idle heuristic</td></tr>';
  $('idle-body').querySelectorAll('tr.drill').forEach(tr=>tr.addEventListener('click',()=>drillTo('rname',+tr.dataset.rn)));
}
