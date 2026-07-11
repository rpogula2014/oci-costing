#!/usr/bin/env node
// Assemble finops-deep-dive.html from source pieces + data payloads:
//   src/template.html  — document shell with __STYLES__/__DATA__/__APP__ markers
//   src/styles.css     — all CSS
//   src/js/*.js        — app modules, concatenated in filename order
//   data/*.json        — ClickHouse extracts (produced by extract.sh)
// Output is a single self-contained HTML file. Edit src/, never the output.
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = dirname(fileURLToPath(import.meta.url));
const OUT = join(DIR, 'finops-deep-dive.html');

const readRows = f => readFileSync(join(DIR, 'data', f), 'utf8').trim().split('\n').map(JSON.parse);

// ── main daily payload (dictionary-encoded) ─────────────────────────
const lines = readRows('finops_daily.json');
const dims = ['env','cc','comp','cpt','svc','rtype','rname','ocid'];
const dicts = {}, idx = {};
for (const d of dims) { dicts[d] = []; idx[d] = new Map(); }
const enc = (d, v) => {
  v = v || '';
  if (!idx[d].has(v)) { idx[d].set(v, dicts[d].length); dicts[d].push(v); }
  return idx[d].get(v);
};
const days = [...new Set(lines.map(r => r.d))].sort();
const dayIdx = new Map(days.map((d, i) => [d, i]));
const rows = lines.map(r => [dayIdx.get(r.d), enc('env',r.env), enc('cc',r.cc), enc('comp',r.comp),
  enc('cpt',r.cpt), enc('svc',r.svc), enc('rtype',r.rtype), enc('rname',r.rname), enc('ocid',r.ocid),
  Math.round(r.cost * 10000) / 10000]);
const dataPayload = 'const DATA=' + JSON.stringify({ days, dicts, rows }) + ';\n';

// ── per-OCID payload ────────────────────────────────────────────────
const olines = readRows('finops_ocid.json');
const list = [], oidx = new Map(), info = [], series = [];
for (const r of olines) {
  if (!oidx.has(r.ocid)) { oidx.set(r.ocid, list.length); list.push(r.ocid); info.push(['','','','']); }
  const oi = oidx.get(r.ocid);
  info[oi] = [r.cc || '', r.env || '', r.rtype || '', r.rname || ''];   // last row = latest
  const di = dayIdx.get(r.d);
  if (di === undefined) continue;                                        // day absent from main set
  series.push([oi, di, Math.round(r.cost * 10000) / 10000]);
}
const ocidPayload = 'const OCIDS=' + JSON.stringify({ list, info, series }) + ';\n';

// ── assemble ────────────────────────────────────────────────────────
const styles = readFileSync(join(DIR, 'src/styles.css'), 'utf8');
const app = readdirSync(join(DIR, 'src/js')).filter(f => f.endsWith('.js')).sort()
  .map(f => readFileSync(join(DIR, 'src/js', f), 'utf8'))
  .join('\n');

let html = readFileSync(join(DIR, 'src/template.html'), 'utf8');
for (const [marker, content] of [
  ['<!--__STYLES__-->', () => styles],
  ['<!--__DATA__-->',   () => dataPayload + ocidPayload],
  ['<!--__APP__-->',    () => app],
]) {
  if (!html.includes(marker)) throw new Error(`template missing marker ${marker}`);
  html = html.replace(marker, content);   // fn form: no $-pattern surprises
}
html = html.replace(/(<span>Snapshot: )[\d-]+(<\/span>)/, `$1${days[days.length - 1]}$2`);
writeFileSync(OUT, html);

const total = rows.reduce((a, r) => a + r[9], 0);
console.log(`rows ${rows.length} | ocids ${list.length} | total $${total.toFixed(2)} | ` +
  `days ${days[0]} → ${days[days.length - 1]} | html ${(html.length / 1024 / 1024).toFixed(1)}MB`);
