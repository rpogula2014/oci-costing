/* ── tabs ────────────────────────────────────────────────────────── */
let activeTab='overview';
function setTab(t){
  activeTab=t;
  document.querySelectorAll('.tabbar button').forEach(b=>b.classList.toggle('on',b.dataset.t===t));
  document.querySelectorAll('[data-tab]').forEach(el=>el.classList.toggle('tab-off',el.dataset.tab!==t));
  syncHash();
}
document.querySelectorAll('.tabbar button').forEach(b=>b.onclick=()=>setTab(b.dataset.t));
