/* ── tooltip ─────────────────────────────────────────────────────── */
const tip = $('tip');
function showTip(html,x,y){ tip.innerHTML=html; tip.style.display='block';
  const r=tip.getBoundingClientRect();
  tip.style.left=Math.min(x+14, innerWidth-r.width-10)+'px';
  tip.style.top =Math.min(y+14, innerHeight-r.height-10)+'px'; }
function hideTip(){ tip.style.display='none'; }
