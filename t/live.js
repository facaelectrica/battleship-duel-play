// (60-fps chat, Oct 31) the fight with the simulation worker live, on a fresh page opened with ?simworker=1:
//   eval(await (await fetch('<this file>')).text()); await __liveRun('battle', 20)
// waits for the worker, sets the fight up on both sides (sw-check's SETUP), runs __swLive and averages the perf parts after 4 s
window.__liveRun = async (world = 'battle', secs = 20) => {
  const g = __game, wait = ms => new Promise(r => setTimeout(r, ms));
  for (let i = 0; i < 60 && !(g.sw && g.sw.state && g.sw.state.ready); i++) await wait(250);
  const src = await (await fetch('https://rawcdn.githack.com/facaelectrica/battleship-duel-play/37ae8ffa481c0f8a9c90e43f4188f03e8a3ec42f/t/sw-check.js')).text();
  (0, eval)(src);
  const seededSrc = src.match(/const seeded = (seed => \{[^\n]*\});/)[1];
  const S = `const seeded = ${seededSrc}; Math.random = seeded(7);
    g.ui.title = false; g.ui.resume = false; g.setCtl(['kb', 'kb2']); g.setMode('${world === 'open' ? 'land' : 'duel'}'); g.paused = true; g.hold = true;
    g.stepQuiet(1 / 120, 60);
    const S0 = g.ships[0], S1 = g.ships[1], mid = (S0.x + S1.x) / 2, xs = [mid - 350, mid + 350];
    for (const p of [0, 1]) { g.placeOut(p, 'sub', xs[p] + (p ? 120 : -120)); g.depth(p, g.subs[p].y + 120); g.placeOut(p, 'ship', xs[p]); }
    self.__fly = p => {
      g.select(p, 'plane'); const pl = T.planes[p];
      if (pl.ground || pl.state !== 'fly') Object.assign(pl, { ground: null, state: 'fly', rot: 0, gear: 0, gWant: 0, auto: null, turn: null, eng: 'on' });
      Object.assign(pl, { x: mid + (p ? 500 : -500), y: g.ships[p].y - 420 - p * 60, facing: p ? -1 : 1, pitch: 0, spd: 330, vx: (p ? -1 : 1) * 330, vy: 0 });
      pl.loiter = { x: mid }; pl.mg = true; if (p === 1) g.select(1, 'ship');
    };
    __fly(0); __fly(1); self.__n = 0; self.__mid = mid; return 1;`;
  new Function('g', 'T', S)(g, g.swT); await g.sw.run(S);
  const acc = {}; let nf = 0, on = true; const t0 = performance.now();
  const samp = () => { if (!on) return; if (performance.now() - t0 > 4000) { nf++; const P = g.perfNow().parts || {}; for (const k in P) acc[k] = (acc[k] || 0) + P[k]; } requestAnimationFrame(samp); };
  requestAnimationFrame(samp);
  const r = await __swLive(secs); on = false;
  const parts = Object.fromEntries(Object.entries(acc).filter(([k]) => !/Q$/.test(k)).map(([k, v]) => [k, +(v / nf).toFixed(2)]).filter(([k, v]) => v >= 0.15).sort((a, b) => b[1] - a[1]));
  return { fps: r.fps, worst: r.worstMs, render: r.renderMs, guest: r.guestMs, apply: +(+r.applyMs).toFixed(2), tick: +(+r.tickMs).toFixed(2), parts };
};
// the GPU's own time a frame (EXT_disjoint_timer_query_webgl2): a query from one animation frame to the next spans one frame of the
// game's GL work; the average and the worst over the run
window.__gpuTimer = () => {
  const gl = __game.GLR.gl, ext = gl.getExtension('EXT_disjoint_timer_query_webgl2'); if (!ext) return null;
  const st = { on: true, n: 0, sum: 0, max: 0, pend: [], cur: null };
  const f = () => {
    if (st.cur) { gl.endQuery(ext.TIME_ELAPSED_EXT); st.pend.push(st.cur); st.cur = null; }
    while (st.pend.length && gl.getQueryParameter(st.pend[0], gl.QUERY_RESULT_AVAILABLE)) {
      const q = st.pend.shift(); if (!gl.getParameter(ext.GPU_DISJOINT_EXT)) { const ms = gl.getQueryParameter(q, gl.QUERY_RESULT) / 1e6; st.n++; st.sum += ms; if (ms > st.max) st.max = ms; } gl.deleteQuery(q);
    }
    if (!st.on) return;
    st.cur = gl.createQuery(); gl.beginQuery(ext.TIME_ELAPSED_EXT, st.cur);
    requestAnimationFrame(f);
  };
  requestAnimationFrame(f);
  return { stop: () => { st.on = false; return { gpuMs: +(st.sum / Math.max(1, st.n)).toFixed(2), gpuWorst: +st.max.toFixed(1), frames: st.n }; } };
};
// the GPU's time by program: every draw call a query of its own, tagged with the program in use (named from GLR / GSM / WGL fields)
window.__gpuByProg = () => {
  const G = __game.GLR, gl = G.gl, ext = gl.getExtension('EXT_disjoint_timer_query_webgl2'); if (!ext) return null;
  const names = new Map();
  const nameOf = p => { if (names.has(p)) return names.get(p); let nm = null;
    for (const [o, pre] of [[G, 'GLR.'], [window.__game.GSM || {}, 'GSM.'], [window.__game.WGL || {}, 'WGL.']]) for (const k in o) { try { if (o[k] === p) nm = pre + k; else if (o[k] && typeof o[k] === 'object' && !(o[k] instanceof WebGLProgram)) for (const k2 in o[k]) if (o[k][k2] === p) nm = pre + k + '.' + k2; } catch (e) { } }
    if (!nm) { const L = (new Error().stack || '').split('\n').slice(2).map(l => (l.match(/at (?:[\w.]+\.)?([\w$]+) /) || [])[1]).filter(f => f && !/^(useProgram|nameOf)$/.test(f)); nm = 'p:' + (L.slice(0, 2).join('<') || names.size); }
    names.set(p, nm); return nm; };
  let cur = 'none', fb = 'screen', q = null, tag = ''; const acc = {}, pend = [];
  const uP = gl.useProgram.bind(gl); gl.useProgram = p => { cur = p ? nameOf(p) : 'none'; return uP(p); };
  const bF = gl.bindFramebuffer.bind(gl); gl.bindFramebuffer = (t, f) => { fb = f ? 'fbo' : 'screen'; return bF(t, f); };
  const start = t => { if (q) { gl.endQuery(ext.TIME_ELAPSED_EXT); pend.push([q, tag]); } q = gl.createQuery(); tag = t; gl.beginQuery(ext.TIME_ELAPSED_EXT, q); };
  const wrap = (fn, lab) => { const o = gl[fn].bind(gl); gl[fn] = (...a) => { start(lab ? lab : cur + '@' + fb); return o(...a); }; };
  for (const f of ['drawArrays', 'drawArraysInstanced', 'drawElements', 'drawElementsInstanced']) wrap(f);
  wrap('clear', 'clear'); wrap('blitFramebuffer', 'blit'); wrap('texSubImage2D', 'upload'); wrap('texImage2D', 'upload');
  let on = true, frames = 0;
  const poll = () => { while (pend.length && gl.getQueryParameter(pend[0][0], gl.QUERY_RESULT_AVAILABLE)) { const [qq, t] = pend.shift(); if (!gl.getParameter(ext.GPU_DISJOINT_EXT)) acc[t] = (acc[t] || 0) + gl.getQueryParameter(qq, gl.QUERY_RESULT) / 1e6; gl.deleteQuery(qq); } if (on) { frames++; requestAnimationFrame(poll); } };
  requestAnimationFrame(poll);
  return { stop: () => { on = false; return Object.fromEntries(Object.entries(acc).map(([k, v]) => [k, +(v / frames).toFixed(2)]).filter(([k, v]) => v >= 0.1).sort((a, b) => b[1] - a[1])); } };
};
