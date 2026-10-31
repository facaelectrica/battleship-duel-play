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
