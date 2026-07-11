/* ── KPIs ────────────────────────────────────────────────────────── */
function renderKPIs(rows,g){
  const total=rows.reduce((a,r)=>a+r[9],0);
  const nDays=new Set(rows.map(r=>r[0])).size||1;
  const untag=rows.filter(r=>DATA.dicts.cc[r[2]]==='').reduce((a,r)=>a+r[9],0);
  /* MoM from monthly buckets regardless of view granularity */
  const mm=new Map();
  for(const r of rows){ const k=DATA.days[r[0]].slice(0,7); mm.set(k,(mm.get(k)||0)+r[9]); }
  const mks=[...mm.keys()].sort();
  let momTxt='—', momCls='';
  if(mks.length>=3){ const a=mm.get(mks[mks.length-3]), b=mm.get(mks[mks.length-2]);
    const pc=(b-a)/a*100; momTxt=(pc>=0?'+':'')+pc.toFixed(1)+'%'; momCls=pc>=0?'up':'down'; }
  const last7=(()=>{ const mx=Math.max(...rows.map(r=>r[0]));
    const s7=rows.filter(r=>r[0]>mx-7).reduce((a,r)=>a+r[9],0); return s7/Math.min(7,nDays); })();
  /* month-end forecast: linear extrapolation of latest (possibly partial) month */
  const fc=(()=>{
    if(!mks.length) return null;
    const lm=mks[mks.length-1];
    const [y,m]=lm.split('-').map(Number);
    const daysInM=new Date(Date.UTC(y,m,0)).getUTCDate();
    const lastDay=+DATA.days[Math.max(...rows.map(r=>r[0]))].slice(8,10);
    const v=(mm.get(lm)||0)/lastDay*daysInM;
    const prevM=mks.length>=2?mks[mks.length-2]:null;
    return {m:lm, v, partial:lastDay<daysInM, prevM, prevV:prevM?mm.get(prevM):null};
  })();
  const topShare=(()=>{ const t=[...g.totals.entries()].sort((a,b)=>b[1]-a[1])[0];
    return t?{n:disp(t[0]),p:t[1]/(total||1)*100}:{n:'—',p:0}; })();
  const latestM=mks[mks.length-1], latestV=mm.get(latestM)||0;
  const kpis=[
    {e:'Total (filtered range)', v:fmt$(total), c:`${nDays} days of data`},
    {e:'Latest month', v:fmt$(latestV), c:latestM+' · may be partial', cls:''},
    {e:'MoM (complete months)', v:momTxt, c:mks.length>=3?`${mks[mks.length-3]} → ${mks[mks.length-2]}`:'needs 2 complete months', cls:momCls},
    (fc&&fc.partial&&fc.prevV
      ? {e:'Forecast '+fc.m, v:fmt$(fc.v),
         c:'vs '+fc.prevM+' actual '+fmt$(fc.prevV)+' ('+((fc.v-fc.prevV)>=0?'+':'')+((fc.v-fc.prevV)/fc.prevV*100).toFixed(1)+'%)',
         cls:fc.v>fc.prevV?'up':'down'}
      : {e:'Run-rate (last 7d avg)', v:fmt$(last7)+'/d', c:'≈ '+fmt$(last7*30)+'/mo', cls:''}),
    {e:'Untagged (no cost center)', v:fmt$(untag), c:(total?(untag/total*100).toFixed(1):0)+'% of spend', cls:untag/total>0.15?'up':''},
    (()=>{ let p=0,np=0;
      for(const r of rows){ const c=ENV_CLASS[DATA.dicts.env[r[1]]]; if(c==='prod')p+=r[9]; else if(c==='nonprod')np+=r[9]; }
      const share=(p+np)?np/(p+np)*100:0;
      return {e:'Non-prod share (of tagged)', v:share.toFixed(0)+'%', c:'non-prod '+fmt$(np)+' vs prod '+fmt$(p), cls:share>40?'up':''};
    })(),
    {e:'Top '+DIM_LABEL[S.groupBy].toLowerCase(), v:topShare.p.toFixed(0)+'%', c:topShare.n},
  ];
  $('kpis').innerHTML=kpis.map(k=>`<div class="kpi"><div class="eyebrow">${k.e}</div>
    <div class="v num ${k.cls||''}">${k.v}</div><div class="c">${k.c}</div></div>`).join('');
}
