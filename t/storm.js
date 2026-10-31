// (60-fps chat, Oct 31) the storm fight's helpers, on top of live.js (loaded first by __stormSetup):
//   eval(await (await fetch('<this file>')).text()); await __stormSetup(); then __sample(8)
// __stormSetup: the worker fight (live.js SETUP), a few seconds running, then the storm pinned (each weather value held)
// __sample(secs): the perf parts and the sky's own parts (FT) averaged over the frames, the frame rate, no tool work in the frames
window.__stormSetup = async (storm = true) => {
  for (let i = 0; i < 60 && typeof __game === 'undefined'; i++) await new Promise(r => setTimeout(r, 250));
  (0, eval)(await (await fetch('https://rawcdn.githack.com/facaelectrica/battleship-duel-play/fab8514f09e080cc59abe580209b0adf5fd762e4/t/live.js')).text());
  await __liveRun('battle', -1);
  __swLive(4);
  await new Promise(r => setTimeout(r, 1500));
  if (storm) await __game.sw.run("Object.assign(g.env, { time: 18.6, weather: 0.92, rain: 0.8, wind: 0.8, sea: 0.9 }); g.W.manual = { time: 1, weather: 1, rain: 1, wind: 1, sea: 1, fog: 1 }; g.computeEnv(); return 1;");
  await new Promise(r => setTimeout(r, 3500));
  return JSON.stringify(__game.env);
};
window.__sample = async (secs = 8) => {
  const g = __game, acc = {}, ft = {}; let nf = 0; const fr = []; let lt = performance.now(); const t0 = lt;
  await new Promise(res => { const f = () => { const t = performance.now(); fr.push(t - lt); lt = t; nf++; const P = g.perfNow().parts || {}; for (const k in P) acc[k] = (acc[k] || 0) + P[k]; const F = g.nsky.FT; for (const k in F) ft[k] = (ft[k] || 0) + F[k]; if (t - t0 > secs * 1000) return res(); requestAnimationFrame(f); }; requestAnimationFrame(f); });
  const avg = o => Object.fromEntries(Object.entries(o).filter(([k]) => !/Q$/.test(k)).map(([k, v]) => [k, +(v / nf).toFixed(2)]).filter(([k, v]) => v >= 0.25).sort((a, b) => b[1] - a[1]));
  fr.sort((a, b) => a - b); const q = p => +fr[Math.floor(p * (fr.length - 1))].toFixed(1);
  return { fps: +(nf / secs).toFixed(1), p50: q(0.5), p90: q(0.9), max: q(1), parts: avg(acc), sky: avg(ft) };
};
