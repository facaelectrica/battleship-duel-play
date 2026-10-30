// (engine migration, the end checks) paste into the live game's page (Pages or the artifact), or run through Claude in Chrome:
//   await __bench('battle')   -> one row with the worker off, one with it on (?worker=1's switch, live)
// each row: frames a second over 5 s after 4 s of settling, and the perf panel's averages (ms a frame): script parts, the
// physics steps a frame and the world's update by part. Scenes: battle (two burning ships firing), open (OPEN WORLD at the
// harbour), openfar (OPEN WORLD zoomed all the way out)
window.__bench = async (scene, workers = [false, true]) => {
  const g = __game, wait = ms => new Promise(r => setTimeout(r, ms)), rows = [];
  const setup = () => {
    g.ui.title = false; g.ui.resume = false; g.paused = false; g.hold = false;
    if (scene === 'battle') {
      g.setMode('duel'); g.placeOut(0, 'ship', 3200); g.placeOut(1, 'ship', 3900);
      for (const p of [0, 1]) for (const k of [3, 4]) g.damage(p, k, 1);
    } else { g.setCtl(['kb', 'none']); g.setMode('land'); if (scene === 'openfar') { g.zoomStep(0, -99); g.cutTo(0); } }
  };
  const fire = () => { if (scene !== 'battle') return; for (const p of [0, 1]) { try { const gu = g.gun(p); gu.elev = 30 + Math.random() * 12; gu.power = 0.5; g.fire(p); } catch (e) { } } };
  setup();
  for (const w of workers) {
    g.smokeWorker(w);
    await wait(4000);
    const S = {}, add = (k, v) => { S[k] = (S[k] || 0) + (v || 0); };
    let n = 0; const t0 = performance.now();
    await new Promise(res => {
      const f = () => {
        n++; const P = g.perfNow();
        add('script', P.phys + P.smoke + P.render); add('phys', P.phys); add('smoke', P.smoke); add('render', P.render); add('steps', P.steps);
        for (const k of ['uWater', 'uVehicles', 'uLand', 'uOpenWorld', 'sky', 'objects', 'distort', 'overlays', 'topui']) add(k, P.parts[k]);
        if (n % 120 === 1) fire();
        if (performance.now() - t0 < 5000) requestAnimationFrame(f); else res();
      };
      requestAnimationFrame(f);
    });
    const secs = (performance.now() - t0) / 1000, row = { scene, worker: w, fps: +(n / secs).toFixed(1) };
    for (const k in S) row[k] = +(S[k] / n).toFixed(2);
    rows.push(row);
  }
  console.table(rows);
  return rows;
};
