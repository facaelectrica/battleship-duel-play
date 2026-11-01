// (60-fps chat, Oct 31) the GPU's side of a frame, in the user's Chrome: eval after storm.js / heavy.js
// __upCount(secs): uploads a frame by caller; __gpuProf(secs): GPU ms a frame by program (a timer query round each draw);
// __finishMeasure(secs): how long the GPU still works after the frame's script (gl.finish), the script's ms
window.__glOf = () => { const c = [...document.querySelectorAll('canvas')].find(c => c.getContext('webgl2')); return c.getContext('webgl2'); };
window.__upCount = async (secs = 4) => {
  const gl = __glOf(), P = WebGL2RenderingContext.prototype, o1 = P.texSubImage2D, o2 = P.texImage2D, acc = new Map();
  const rec = (kind, a) => { const st = (new Error().stack || '').split('\n').slice(2, 6).map(l => (l.match(/at (\S+)/) || [])[1]).filter(Boolean).join('<'); const k = kind + ' ' + st; acc.set(k, (acc.get(k) || 0) + 1); };
  P.texSubImage2D = function (...a) { if (this === gl) rec('sub', a); return o1.apply(this, a); }; P.texImage2D = function (...a) { if (this === gl) rec('img', a); return o2.apply(this, a); };
  let nf = 0; const t0 = performance.now(); await new Promise(done => { const f = () => { nf++; if (performance.now() - t0 > secs * 1000) return done(); requestAnimationFrame(f); }; requestAnimationFrame(f); });
  P.texSubImage2D = o1; P.texImage2D = o2;
  const tot = [...acc.values()].reduce((a, b) => a + b, 0);
  return 'uploads/frame ' + (tot / nf).toFixed(1) + '\n' + [...acc.entries()].sort((a, b) => b[1] - a[1]).slice(0, 12).map(([k, v]) => (v / nf).toFixed(1) + ' ' + k).join('\n');
};
window.__gpuProf = async (secs = 5) => {
  const gl = __glOf(), X = gl.getExtension('EXT_disjoint_timer_query_webgl2'), P = WebGL2RenderingContext.prototype, orig = {}; let prog = null; const ids = new Map(), names = [];
  const pid = p => { if (!p) return -1; let i = ids.get(p); if (i === undefined) { i = names.length; ids.set(p, i); const n = gl.getProgramParameter(p, gl.ACTIVE_UNIFORMS), u = []; for (let k = 0; k < n; k++) u.push(gl.getActiveUniform(p, k).name); names.push(u.join(',').slice(0, 80)); } return i; };
  const pend = [], acc = new Map(), cnt = new Map();
  orig.beginQuery = P.beginQuery; orig.endQuery = P.endQuery; orig.useProgram = P.useProgram; P.useProgram = function (p) { if (this === gl) prog = p; return orig.useProgram.call(this, p); };
  const wrap = (name, keyf) => { orig[name] = P[name]; P[name] = function (...a) { if (this !== gl) return orig[name].apply(this, a); const q = gl.createQuery(); orig.beginQuery.call(gl, X.TIME_ELAPSED_EXT, q); const r = orig[name].apply(this, a); orig.endQuery.call(gl, X.TIME_ELAPSED_EXT); pend.push([q, keyf(a)]); return r; }; };
  for (const n of ['drawArrays', 'drawElements', 'drawArraysInstanced', 'drawElementsInstanced']) wrap(n, () => 'p' + pid(prog));
  for (const n of ['texImage2D', 'texSubImage2D', 'clear', 'blitFramebuffer']) wrap(n, () => n);
  const drain = () => { for (let i = pend.length - 1; i >= 0; i--) { const [q, k] = pend[i]; if (gl.getQueryParameter(q, gl.QUERY_RESULT_AVAILABLE)) { const v = gl.getQueryParameter(q, gl.QUERY_RESULT) / 1e6; acc.set(k, (acc.get(k) || 0) + v); cnt.set(k, (cnt.get(k) || 0) + 1); gl.deleteQuery(q); pend.splice(i, 1); } } };
  let nf = 0; const t0 = performance.now(); await new Promise(done => { const f = () => { drain(); nf++; if (performance.now() - t0 > secs * 1000) return done(); requestAnimationFrame(f); }; requestAnimationFrame(f); });
  for (const n in orig) P[n] = orig[n];
  await new Promise(r => setTimeout(r, 300)); drain();
  const tot = [...acc.values()].reduce((a, b) => a + b, 0);
  return 'gpu ms/frame ' + (tot / nf).toFixed(2) + '\n' + [...acc.entries()].sort((a, b) => b[1] - a[1]).slice(0, 16).map(([k, v]) => (v / nf).toFixed(2) + 'ms x' + ((cnt.get(k) || 0) / nf).toFixed(0) + ' ' + k + (k[0] === 'p' ? ' ' + names[+k.slice(1)] : '')).join('\n');
};
window.__finishMeasure = async (secs = 6) => {
  const gl = __glOf(), w = [], fr = []; let nf = 0, scr = 0; const t0 = performance.now(); let lt = t0;
  await new Promise(done => { const f = () => { const t = performance.now(); fr.push(t - lt); lt = t; const a = performance.now(); gl.finish(); const px = new Uint8Array(4); gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px); w.push(performance.now() - a); const P = __game.perfNow(); scr += (P.render || 0) + (P.phys || 0); nf++; if (performance.now() - t0 > secs * 1000) return done(); requestAnimationFrame(f); }; requestAnimationFrame(f); });
  w.sort((a, b) => a - b); fr.sort((a, b) => a - b); const q = (r, p) => +r[Math.floor(p * (r.length - 1))].toFixed(2);
  return { fps: +(nf / secs).toFixed(1), gpuLeftP50: q(w, .5), gpuLeftP90: q(w, .9), gapP50: q(fr, .5), script: +(scr / nf).toFixed(2) };
};
