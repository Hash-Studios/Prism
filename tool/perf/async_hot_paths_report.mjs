#!/usr/bin/env node
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {dirname, resolve} from 'node:path';

const input = resolve(process.argv[2] ?? '.dart_tool/async-hot-paths/results.json');
const output = resolve(process.argv[3] ?? 'tool/perf/results/async-hot-paths');
const data = JSON.parse(readFileSync(input, 'utf8'));
const f = n => n.toFixed(1);
const median = xs => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];
const spread = xs => `${f(median(xs))} (${f(Math.min(...xs))}–${f(Math.max(...xs))})`;
const rows = data.results.map(row => `| ${row.path} | ${f(row.before.p50)} → ${f(row.after.p50)} | ${f(row.before.p90)} → ${f(row.after.p90)} |`);
const runRows = data.results.flatMap(row => ['p50', 'p90'].map(p =>
  `| ${row.path}: ${p} | ${spread(row.runs.map(run => run.before[p]))} | ${spread(row.runs.map(run => run.after[p]))} |`));
mkdirSync(dirname(output), {recursive: true});
writeFileSync(`${output}.json`, `${JSON.stringify(data, null, 2)}\n`);
writeFileSync(`${output}.md`, `# Async hot-path benchmark

These are controlled local repository measurements with simulated I/O, not production or device latency.
The old and new implementations complete the same work. All measured requests succeeded.

## Results

Each percentile uses 100 samples per side, pooled from five runs. Units: milliseconds. Lower is better.

| Path | p50 before → after | p90 before → after |
|---|---:|---:|
${rows.join('\n')}

The [graphs](async-hot-paths.html) use a shared scale. The [raw samples](async-hot-paths.json) include all runs and profiles.

## Repeatability

Each cell is the median of five run percentiles, followed by the minimum and maximum. Units: milliseconds.

| Path and percentile | Before median (range) | After median (range) |
|---|---:|---:|
${runRows.join('\n')}

## Method

- Baseline: \`${data.base}\`. The runner extracts the three old source files without changing the working tree.
- Candidate source hashes are in the JSON. Both versions run in the same Flutter test process with the same dependencies.
- Each side has five runs of 20 samples. The first side alternates for each sample. Five unreported warmup/profile requests precede each side.
- Each dependency call waits 8–20 ms. Its delay depends only on the sample and dependency key, not execution order.
- Analytics completes three provider calls. Favourite counts returns 150 correctly parsed records through five queries.
- Search performs 12 dependency calls and returns eight profiles in registry order. Every sample checks outputs, counts, and completion.
- Lookup concurrency stays at four or fewer. Samples time complete public method calls, including result checks.
- Percentiles use the nearest-rank method. A failed request aborts the benchmark; failed runs do not produce new samples.
- Runtime: FVM Flutter test (debug/JIT), Linux, ${data.cpus} visible CPUs. Initial load averages: ${data.loadAverage.map(f).join(', ')}.
- The shared host was busy. Paired samples reduce drift but do not remove scheduling noise. These results do not establish production speedups.

## Limiter and limits

The controlled limiter is time spent at the simulated async boundary in \`Boundary.read\`, not real network or database bandwidth.
Independent awaits overlap those waits. The final dependency, later bounded batches, Dart work, and host scheduling still limit latency.
No reads or provider calls are removed. The unreported profiles record wall time and Linux user/system CPU ticks at 100 ticks/second.
Peak in-flight counts are in the raw data. These counters and output assertions establish that the work completed in the timed region.

This benchmark excludes Flutter rendering, native plugins, Firebase RPCs, real transaction contention, retries, and production caches.
It covers three representative paths, not all changed paths. Live p50/p90 and app-wide latency remain unmeasured.
The backend transaction tests establish one read round, not a millisecond latency improvement.

## Reproduce

\`\`\`sh
node tool/perf/async_hot_paths.mjs ${data.base}
node tool/perf/async_hot_paths_report.mjs
\`\`\`
`);

const chartData = data.results.map(row => ({name: row.path.split(' (')[0], before: row.before, after: row.after}));
writeFileSync(`${output}.html`, `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Async hot-path latency</title>
<style>
:root{font-family:var(--font-sans,system-ui);color:var(--foreground,CanvasText);color-scheme:light dark}
body{margin:0;background:transparent}h2,h3,p{margin:0}h2{font-size:18px;font-weight:500}h3{font-size:15px;font-weight:500}
.note{color:var(--muted-foreground,GrayText);font-size:13px;margin:8px 0 18px}
.panels{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:24px}
svg{width:100%;height:340px;display:block}svg text{fill:var(--foreground,CanvasText);font-size:12px;font-family:var(--font-sans,system-ui)}
.axis{stroke:var(--border,GrayText);stroke-width:1;fill:none}.before{fill:var(--chart-2,GrayText)}.after{fill:var(--chart-1,Highlight)}
</style></head><body><main id="async-latency">
<h2>Local latency with simulated I/O</h2>
<p class="note">100 samples per version · 5 interleaved runs · milliseconds, lower is better<br>Actual repository code, simulated 8–20 ms dependency delays. Not production or device latency.</p>
<div class="panels"><section><h3>p50</h3><svg data-percentile="p50" role="img" aria-label="Before and after median repository latency"></svg></section>
<section><h3>p90</h3><svg data-percentile="p90" role="img" aria-label="Before and after 90th percentile repository latency"></svg></section></div>
<p class="note">Before: original code · After: concurrent code · Shared axis scale · 0 failed requests<br>Analytics: 3 providers · Favourites: 150 walls · Search: 8 registry profiles</p>
</main><script>
const data = ${JSON.stringify(chartData)};
const root = document.getElementById('async-latency');
const max = Math.ceil(Math.max(...data.flatMap(d=>[d.before.p50,d.after.p50,d.before.p90,d.after.p90]))/20)*20;
const ns = 'http://www.w3.org/2000/svg';
function draw(svg){
  const width = svg.getBoundingClientRect().width;
  svg.setAttribute('viewBox','0 0 '+width+' 340');svg.replaceChildren();
  const left=64,right=width-46,span=right-left,p=svg.dataset.percentile;
  function el(tag,attrs,text){const node=document.createElementNS(ns,tag);for(const [k,v] of Object.entries(attrs))node.setAttribute(k,v);if(text!==undefined)node.textContent=text;svg.append(node);return node;}
  el('text',{x:0,y:17,class:'axis-title','data-axis':'y'},'Repository path');
  for(let i=0;i<4;i++){const x=left+span*i/3;el('line',{x1:x,x2:x,y1:35,y2:293,class:'axis'});el('text',{x,y:312,'text-anchor':'middle'},Math.round(max*i/3));}
  data.forEach((d,i)=>{const y=43+i*84;el('text',{x:0,y},d.name);['before','after'].forEach((side,j)=>{
    const value=d[side][p],barY=y+10+j*24;
    el('text',{x:left-7,y:barY+13,'text-anchor':'end'},side==='before'?'Before':'After');
    const mark=el('rect',{x:left,y:barY,width:value/max*span,height:18,class:side});
    const title=document.createElementNS(ns,'title');title.textContent=d.name+' '+side+' '+p+': '+value.toFixed(1)+' ms';mark.append(title);
    el('text',{x:left+value/max*span+5,y:barY+13},value.toFixed(1));
  });});
  el('text',{x:(left+right)/2,y:335,'text-anchor':'middle',class:'axis-title','data-axis':'x'},'Latency (ms)');
}
for(const svg of root.querySelectorAll('svg'))new ResizeObserver(()=>draw(svg)).observe(svg);
</script></body></html>\n`);
console.log(`Report: ${output}.md`);
console.log(`Graphs: ${output}.html`);
