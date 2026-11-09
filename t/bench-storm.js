// (Nov 9, user: "just two planes circling around in a default zoom is not really stress testing" - "zoom out too ... launch bombs to burn the trees ... land
// vehicles ... crash, launch missiles, burn") the heavy benchmark: Battle, two players, a storm, both zoomed fully out over the islands. Both battleships
// and subs out and firing, player 1 flying a plane (bombs, guns, shot down every 8 s and relaunched), player 2 in a helicopter firing rockets; bombs
// landing among the island plants (tearing, snapping) and trees set alight. Settles `warm` seconds, measures `secs`: frames a second, the worst frame,
// the long ones, the perf panel's parts, the most picture memory seen. Run with ?simworker=0. The Chrome tool stops at 45 s: start it and read later -
//   __storm(25).then(r => window.__res = r)
window.__storm = async (secs = 25, warm = 8) => {
  const g = __game, wait = ms => new Promise(r => setTimeout(r, ms));
  g.menuSel.mode = 'duel'; g.ui.title = false; g.ui.resume = false; g.paused = false; g.hold = false;
  g.setCtl(['kb', 'kb2']); g.setMode('duel'); await wait(1500);
  g.swT.ev("envSet(0,'weather',1); envSet(0,'fog',0.3); envSet(0,'rain',1); envSet(0,'sea',1); envSet(0,'wind',0.8)");
  const mid = (g.ships[0].x + g.ships[1].x) / 2, xs = [mid - 350, mid + 350];
  for (const p of [0, 1]) { g.placeOut(p, 'sub', xs[p] + (p ? 120 : -120)); g.depth(p, g.subs[p].y + 120); g.placeOut(p, 'ship', xs[p]); }
  const out = () => { g.zoomStep(0, -99); g.zoomStep(1, -99); };
  const fly = () => { g.select(0, 'plane'); const pl = g.planesP[0]; if (pl.ground || pl.state !== 'fly') Object.assign(pl, { ground: null, state: 'fly', rot: 0, gear: 0, gWant: 0, auto: null, turn: null, eng: 'on' }); Object.assign(pl, { x: mid - 500, y: g.ships[0].y - 420, facing: 1, pitch: 0, spd: 330, vx: 330, vy: 0 }); pl.loiter = { x: mid }; pl.mg = true; out(); };
  fly(); try { g.select(1, 'heli'); } catch (e) { } out();
  const trees = g.veglab.trees().filter(t => Math.abs(t.x - mid) < 3000), pick = () => trees[Math.floor(Math.random() * trees.length)];
  const t0 = performance.now(); let n = 0, last = t0, prev = t0, worst = 0, m = 0, tm = 0, maxMem = 0; const long = [], acc = {};
  while (true) {
    await new Promise(r => requestAnimationFrame(r)); n++;
    const now = performance.now(), dt = now - prev; prev = now;
    if (n % 50 === 0) for (const p of [0, 1]) { try { const gu = g.sgun(p); gu.elev = 28 + Math.random() * 14; gu.power = 0.45 + Math.random() * 0.2; g.fire(p); } catch (e) { } }
    if (n % 150 === 7) for (const p of [0, 1]) { try { g.torpedo(p, false); } catch (e) { } }
    if (n % 120 === 30) { try { g.act(0, 'bomb'); } catch (e) { } }
    if (n % 30 === 15) { try { g.act(1, 'rocket'); } catch (e) { } try { g.act(1, 'fire'); } catch (e) { } }
    if (n % 40 === 20 && trees.length) { const t = pick(); try { g.veglab.blast(t.x + (Math.random() - 0.5) * 60, (t.gy || 0) - 15); } catch (e) { } }
    if (n % 90 === 45 && trees.length) for (let i = 0; i < 3; i++) { try { g.veglab.ignite(pick()); } catch (e) { } }
    const pl = g.planesP[0]; if (pl.state === 'fly') pl.mg = true; else if (pl.state === 'hangar') fly();
    if (now - last > 8000) { last = now; if (pl.state === 'fly') g.downPlane(0); }
    if (n % 60 === 0) { const R = g.swT.ev('picReport()'); maxMem = Math.max(maxMem, R.MB + R.gpuMB); }
    if (!tm && now - t0 > warm * 1000) { tm = now; m = 0; worst = 0; long.length = 0; for (const k in acc) delete acc[k]; }
    if (tm) { m++; if (dt > worst) worst = dt; if (dt > 200) long.push(Math.round(dt)); const P = g.perfNow(); for (const k in P.parts || {}) acc[k] = (acc[k] || 0) + P.parts[k]; if (now - tm > secs * 1000) break; }
  }
  const R = g.swT.ev('picReport()');
  return { fps: +(m / ((performance.now() - tm) / 1000)).toFixed(1), worst: Math.round(worst), long, z: g.cam.view.map(v => +v.z.toFixed(3)), maxMemMB: Math.round(maxMem), tight: R.tight, dropped: R.dropped,
    parts: Object.entries(acc).sort((a, b) => b[1] - a[1]).slice(0, 10).map(([k, v]) => k + ' ' + (v / m).toFixed(1)), burning: g.veglab.trees().filter(t => t.burnT > 0).length };
};
