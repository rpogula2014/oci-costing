"use strict";
/* ── palette / state ─────────────────────────────────────────────── */
const SLOTS = ['--s1','--s2','--s3','--s4','--s5','--s6','--s7','--s8'];
const DIMS = { env:1, cc:2, comp:3, cpt:4, svc:5, rtype:6, rname:7 };
const DIM_LABEL = { env:'Environment', cc:'Cost center', comp:'Component type', cpt:'Compartment', svc:'Service', rtype:'Resource type', rname:'Resource name' };
/* env tag → prod/nonprod for the non-prod-share KPI; unlisted values (incl. untagged) excluded */
const ENV_CLASS = { prod:'prod', dev:'nonprod', xat:'nonprod' };
const S = { gran:'week', groupBy:'cc', range:'all', f:{ env:'', cc:'', comp:'', cpt:'', svc:'', rtype:'', rname:'' }, text:'' };
const $ = id => document.getElementById(id);
const fmt$ = v => '$' + v.toLocaleString('en-US',{minimumFractionDigits:0, maximumFractionDigits:0});
const fmt$2 = v => '$' + v.toLocaleString('en-US',{minimumFractionDigits:2, maximumFractionDigits:2});
const cssVar = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const escHtml = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const disp = v => v === '' ? '(untagged)' : escHtml(v);

/* stable color assignment: entity → slot by overall-spend order, fixed forever */
const slotOf = {};
for (const d of Object.keys(DIMS)) {
  const tot = new Map();
  for (const r of DATA.rows) { const v = DATA.dicts[d][r[DIMS[d]]]; tot.set(v,(tot.get(v)||0)+r[9]); }
  const order = [...tot.entries()].sort((a,b)=>b[1]-a[1]).map(e=>e[0]);
  slotOf[d] = new Map(order.map((v,i)=>[v, i<7?i:7])); /* 8th slot = Other bucket */
}
