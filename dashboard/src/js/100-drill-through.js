/* ── drill-through: click an entity → toggle its filter ─────────── */
function drillTo(dim, idx, scroll=true){
  const v=String(idx);
  S.f[dim] = S.f[dim]===v ? '' : v;
  $('f-'+dim).value = S.f[dim];
  update();
  if(scroll && S.f[dim]!==''){
    if(activeTab!=='investigate') setTab('investigate');
    $('detail-card').scrollIntoView({behavior:'smooth'});
  }
}
