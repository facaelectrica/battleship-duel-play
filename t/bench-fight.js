// (user Oct 30 18:03: "to test the real frame rate, you need two players, two battleships, two submarines and two planes,
// everything flying and shooting at each other, with planes blowing up") the standard benchmark from Version 370 on.
// Paste into a live page of the game (no head.js) or run through Claude in Chrome:
//   await __fight('battle')      the Battle world
//   await __fight('open')        the Open World, the fight in the middle of the sea
// Two players at one keyboard (split screen: player 1 flies the plane, player 2 drives the battleship). Both battleships out and
// firing, both subs out at depth firing torpedoes, both planes in the air with their machine guns on, bombing, one plane shot
// down every 8 s and relaunched when it's back in its hangar. Settles 6 s, then measures `secs` seconds: frames a second, the
// worst frame, the perf panel's averages (ms a frame) and the counts at the end.
window.__fight = async (world = 'battle', secs = 20) => {
  const g = __game, wait = ms => new Promise(r => setTimeout(r, ms));
  g.ui.title = false; g.ui.resume = false; g.paused = false; g.hold = false;
  g.setCtl(['kb', 'kb2']);
  g.setMode(world === 'open' ? 'land' : 'duel');
  await wait(1500);
  const S0 = g.ships[0], S1 = g.ships[1];
  const mid = world === 'open' ? (S0.x + S1.x) / 2 : 3550, xs = [mid - 350, mid + 350];
  for (const p of [0, 1]) {
    g.placeOut(p, 'sub', xs[p] + (p ? 120 : -120)); g.depth(p, g.subs[p].y + 120);
    g.placeOut(p, 'ship', xs[p]);
  }
  const launch = p => {
    g.select(p, 'plane');
    const pl = g.planeOf ? g.planeOf(p) : null;
  };
  const planes = () => [0, 1].map(p => g.plane ? g.plane(p) : null);
  const fly = p => {
    g.select(p, 'plane');
    const pl = g.planesP[p];
    if (pl.ground || pl.state !== 'fly') Object.assign(pl, { ground: null, state: 'fly', rot: 0, gear: 0, gWant: 0, auto: null, turn: null, eng: 'on' });
    Object.assign(pl, { x: mid + (p ? 500 : -500), y: g.ships[p].y - 420 - p * 60, facing: p ? -1 : 1, pitch: 0, spd: 330, vx: (p ? -1 : 1) * 330, vy: 0 });
    pl.loiter = { x: mid }; pl.mg = true;
    if (p === 1) g.select(1, 'ship');                       // (player 2 watches from the battleship)
  };
  fly(0); fly(1);
  const t0 = performance.now(); let lastDown = t0, nextDown = 0, downs = 0, n = 0, worst = 0, prev = performance.now();
  const S = {}, add = (k, v) => { S[k] = (S[k] || 0) + (+v || 0); };
  let measuring = false, tm = 0;
  await new Promise(res => {
    const f = () => {
      const now = performance.now(), dt = now - prev; prev = now;
      const T = (now - t0) / 1000;
      // everyone shooting
      if ((n % 50) === 0) for (const p of [0, 1]) { try { const gu = g.sgun(p); gu.elev = 28 + Math.random() * 14; gu.power = 0.45 + Math.random() * 0.2; g.fire(p); } catch (e) { } }
      if ((n % 150) === 7) for (const p of [0, 1]) { try { g.torpedo(p, false); } catch (e) { } }
      if ((n % 120) === 30) for (const p of [0, 1]) { try { g.act(p, 'bomb'); } catch (e) { } }
      for (const p of [0, 1]) { const pl = g.planesP[p]; if (pl.state === 'fly') { pl.mg = true; if (!pl.loiter) pl.loiter = { x: mid }; } else if (pl.state === 'hangar') fly(p); }
      // a plane shot down every 8 s, the two in turn
      if (now - lastDown > 8000) { lastDown = now; const pl = g.planesP[nextDown]; if (pl.state === 'fly') { g.downPlane(nextDown); downs++; } nextDown ^= 1; }
      if (!measuring && T > 6) { measuring = true; tm = now; n = 0; worst = 0; for (const k in S) delete S[k]; }
      n++;
      if (measuring) {
        if (dt > worst) worst = dt;
        const P = g.perfNow();
        add('phys', P.phys); add('smoke', P.smoke); add('render', P.render); add('steps', P.steps);
        for (const k in P.parts) add(k, P.parts[k]);
      }
      if (measuring && now - tm > secs * 1000) res(); else requestAnimationFrame(f);
    };
    requestAnimationFrame(f);
  });
  const el = (performance.now() - tm) / 1000, row = { world, fps: +(n / el).toFixed(1), worstMs: Math.round(worst), downs };
  for (const k in S) row[k] = +(S[k] / n).toFixed(2);
  row.counts = g.counts();
  row.planes = [0, 1].map(p => g.planesP[p].state);
  return row;
};
