/* ── detail table + export ───────────────────────────────────────── */
let detailRows=[], allDetailRows=[];
const detExpanded=new Set();
const detSort={key:'cost',dir:-1};
function renderDetail(rows){
  const agg=new Map();
  for(const r of rows){ const bk=bucketKey(r[0]);
    const key=[bk,r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8]].join('|');
    agg.set(key,(agg.get(key)||0)+r[9]); }
  allDetailRows=[...agg.entries()].map(([k,v])=>{ const p=k.split('|');
    return {period:p[0],env:DATA.dicts.env[+p[1]],cc:DATA.dicts.cc[+p[2]],comp:DATA.dicts.comp[+p[3]],
            cpt:DATA.dicts.cpt[+p[4]],svc:DATA.dicts.svc[+p[5]],rtype:DATA.dicts.rtype[+p[6]],rname:DATA.dicts.rname[+p[7]],ocid:DATA.dicts.ocid[+p[8]],cost:v}; });
  renderDetailRows();
}
function renderDetailRows(){
  const q=($('detail-q').value||'').trim().toLowerCase();
  const src=q? allDetailRows.filter(r=>
      [r.period,r.env,r.cc,r.comp,r.cpt,r.svc,r.rtype,r.rname,r.ocid].some(v=>(v||'').toLowerCase().includes(q)))
    : allDetailRows;
  const k=detSort.key, d=detSort.dir;
  src.sort(k==='cost' ? (a,b)=>d*(a.cost-b.cost)
                      : (a,b)=>d*String(a[k]).localeCompare(String(b[k])) || b.cost-a.cost);
  detailRows=src.slice(0,500);
  document.querySelectorAll('#detail-head .sortable').forEach(th=>{
    th.querySelector('.sarrow').textContent = th.dataset.sk===k ? (d>0?' \u25b4':' \u25be') : '';
  });
  $('detail-hint').textContent=(q?`${detailRows.length} of ${src.length} matching`:`top ${detailRows.length} of ${allDetailRows.length}`)+` ${S.gran}-grain rows`;
  const rowT=r=>`<tr>
    <td class="num">${r.period}</td><td>${disp(r.env)}</td><td>${disp(r.cc)}</td>
    <td><span class="chip">${disp(r.comp)}</span></td><td>${escHtml(r.cpt)}</td><td>${escHtml(r.svc)}</td><td>${disp(r.rtype)}</td><td>${disp(r.rname)}</td><td class="num" style="font-size:11px" title="${escHtml(r.ocid)}">${r.ocid?'…'+escHtml(r.ocid.slice(-16)):'—'}</td>
    <td class="r num">${fmt$2(r.cost)}</td></tr>`;
  const g=$('detail-g').value;
  const g2r=$('detail-g2').value;
  const g2 = (g2r && g2r!==g) ? g2r : '';
  const keyOf=(r,dim)=> dim==='period' ? r.period : ((r[dim]===''||r[dim]==null) ? '(untagged)' : r[dim]);
  const gidOf=k=>'g_'+btoa(unescape(encodeURIComponent(k))).replace(/[^a-zA-Z0-9]/g,'');
  const groupBy=(rows,dim)=>{
    const m=new Map();
    for(const r of rows){ const k=keyOf(r,dim); if(!m.has(k)) m.set(k,[]); m.get(k).push(r); }
    return m;
  };
  if(!g){
    $('detail').innerHTML=detailRows.map(rowT).join('');
  } else {
    let html='';
    for(const [key,rows] of groupBy(detailRows,g)){
      const gid=gidOf(key);
      const open=detExpanded.has(gid);
      const sub=rows.reduce((a,r)=>a+r.cost,0);
      html+=`<tr class="grp" data-gid="${gid}"><td colspan="9"><span class="chev">${open?'▾':'▸'}</span>${escHtml(key)} <span class="eyebrow" style="margin-left:8px">${rows.length} row${rows.length>1?'s':''}</span></td><td class="r num">${fmt$2(sub)}</td></tr>`;
      if(!open) continue;
      if(!g2){ html+=rows.map(rowT).join(''); continue; }
      for(const [k2,rows2] of groupBy(rows,g2)){
        const gid2=gidOf(key+'␟'+k2);
        const open2=detExpanded.has(gid2);
        const sub2=rows2.reduce((a,r)=>a+r.cost,0);
        html+=`<tr class="grp" data-gid="${gid2}"><td colspan="9" style="padding-left:32px"><span class="chev">${open2?'▾':'▸'}</span>${escHtml(k2)} <span class="eyebrow" style="margin-left:8px">${rows2.length} row${rows2.length>1?'s':''}</span></td><td class="r num">${fmt$2(sub2)}</td></tr>`;
        if(open2) html+=rows2.map(rowT).join('');
      }
    }
    $('detail').innerHTML=html;
    document.querySelectorAll('#detail tr.grp').forEach(tr=>tr.addEventListener('click',()=>{
      const id=tr.dataset.gid;
      detExpanded.has(id)?detExpanded.delete(id):detExpanded.add(id);
      renderDetailRows();
    }));
  }
}
function exportCSV(){
  const head='period,environment,cost_center,component_type,compartment,service,resource_type,resource_name,resource_ocid,cost';
  const esc=s=>{if(/^[=+\-@\t\r]/.test(s))s="'"+s;return /[",\n]/.test(s)?'"'+s.replace(/"/g,'""')+'"':s;};
  const body=detailRows.map(r=>[r.period,r.env,r.cc,r.comp,r.cpt,r.svc,r.rtype,r.rname,r.ocid,r.cost.toFixed(4)].map(x=>esc(String(x))).join(','));
  const b=new Blob([[head,...body].join('\r\n')],{type:'text/csv'});
  const a=document.createElement('a'); a.href=URL.createObjectURL(b); a.download='oci-finops-detail.csv';
  document.body.appendChild(a); a.click(); a.remove();
}
