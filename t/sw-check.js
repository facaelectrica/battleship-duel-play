// (sim-worker) the gate and the live run, pasted into a page of the sim-worker build opened with ?simworker=test (or =1):
//   await __swGate(240)    the worker and the page step the same fight 240 ticks from the same tables: are the tables the same?
//   await __swLive(20)     then the page becomes the worker's guest for 20 s of the fight: fps, apply ms, the worker's tick ms
// (the same as tools/sw-same.mjs, for the user's Chrome; a seeded Math.random on both sides from the set-up on)
(() => {
  const seeded = seed => { let s = seed | 0; return () => { let t = (s = (s + 0x6D2B79F5) | 0); t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; };
  const SEED = `const seeded = ${seeded.toString()};`;
  const SETUP = world => `${SEED} Math.random = seeded(7);
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
  // one tick of the fight's shooting (n: the tick)
  const SHOOT = `const n = __n++;
    if ((n % 100) === 0) for (const p of [0, 1]) { try { const gu = g.sgun(p); gu.elev = 28 + (n * 7 % 14); gu.power = 0.45 + (n % 20) / 100; g.fire(p); } catch (e) { } }
    if ((n % 300) === 14) for (const p of [0, 1]) { try { g.torpedo(p, false); } catch (e) { } }
    if ((n % 240) === 60) for (const p of [0, 1]) { try { g.bomb(p); } catch (e) { } }
    for (const p of [0, 1]) { const pl = T.planes[p]; if (pl.state === 'fly') { pl.mg = true; if (!pl.loiter) pl.loiter = { x: __mid }; } else if (pl.state === 'hangar') __fly(p); }
    if (n % 960 === 480) { const q = (n / 960 | 0) & 1; if (T.planes[q].state === 'fly') g.downPlane(q); }`;
  const STEP = N => `for (let k = 0; k < ${N}; k++) { ${SHOOT} g.stepQuiet(1 / 120, 1); } return [g.time, T.REG.tick];`;
  const both = async code => { const g = __game; return [new Function('g', 'T', code)(g, g.swT), await g.sw.run(code)]; };
  const cmp = (A, B, skip = []) => {
    const out = { tables: 0, same: 0, values: 0, differ: 0, by: {}, first: [], rng: [] };
    const walk = (a, b, path, tb) => {
      if (a && typeof a === 'object' && b && typeof b === 'object') { for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) walk(a[k], b[k], path + '.' + k, tb); return; }
      out.values++;
      if (a === b || (typeof a === 'number' && typeof b === 'number' && Number.isNaN(a) && Number.isNaN(b))) return;
      out.differ++; out.by[tb] = (out.by[tb] || 0) + 1;
      if (out.first.length < 30) out.first.push(path + ': ' + JSON.stringify(a)?.slice(0, 60) + ' vs ' + JSON.stringify(b)?.slice(0, 60));
    };
    for (const k of new Set([...Object.keys(A.tables), ...Object.keys(B.tables)])) { if (skip.includes(k)) continue; out.tables++; const d0 = out.differ; walk(A.tables[k] ?? null, B.tables[k] ?? null, k, k); if (out.differ === d0) out.same++; }
    for (const k of new Set([...Object.keys(A.rng), ...Object.keys(B.rng)])) if (A.rng[k] !== B.rng[k]) out.rng.push(k);
    return out;
  };
  window.__swCmp = cmp;
  // (after a check: the page's sound and clock back)
  const unprep = () => { const g = __game; if (window.__swCtx) { g.SFX.ctx = window.__swCtx; window.__swCtx = null; } if (window.__swNow) { performance.now = window.__swNow; window.__swNow = null; } };
  // the same start on both sides: the fight set up, the page's tables loaded into the worker, both reseeded; the page's smoke air
  // on the page (as the worker has it: no smoke worker there)
  const prep = async (world, log) => {
    const g = __game;
    if (!g.sw.state.ready) { g.sw.start(); for (let i = 0; i < 600 && !g.sw.state.ready && !g.sw.state.fail; i++) await new Promise(r => setTimeout(r, 100)); }
    log.push(['worker', g.sw.state]);
    if (!g.sw.state.ready) return false;
    g.smokeWorker(false);
    // (the page's sounds draw from the shared Math.random - the game still does too in places - so they'd shift the page's
    // game against the worker's, which plays none: muted for the check; the camera's shake goes by the wall clock: frozen)
    if (g.SFX.ctx) { window.__swCtx = g.SFX.ctx; g.SFX.ctx = null; }
    if (!window.__swNow) { window.__swNow = performance.now; performance.now = () => 1000; }
    await g.sw.run('performance.now = () => 1000; return 1;');
    await both(SETUP(world));
    await g.sw.ask('load', { s: JSON.stringify(g.swT.tablesSave()) });
    await both(`${SEED} Math.random = seeded(99); return 1;`);
    return true;
  };
  // tick by tick from the shared start: the first tick whose tables differ, and in which tables (main chat 19:05)
  window.__swFirst = async (max = 60, world = 'battle') => {
    const g = __game, log = [];
    if (!await prep(world, log)) return log;
    const same0 = cmp(JSON.parse(JSON.stringify(g.swT.tablesSave())), JSON.parse(await g.sw.tables()));
    log.push(['tick 0', same0.differ, same0.by, same0.rng, same0.first.slice(0, 10)]);
    for (let t = 1; t <= max; t++) {
      await both(STEP(1));
      const r = cmp(JSON.parse(JSON.stringify(g.swT.tablesSave())), JSON.parse(await g.sw.tables()));
      if (r.differ || r.rng.length) { log.push(['first different tick', t, r.differ, r.by, r.rng, r.first]); break; }
      if (t === max) log.push(['same through tick', t]);
    }
    unprep(); console.log(JSON.stringify(log, null, 1));
    return log;
  };
  window.__swGate = async (ticks = 240, world = 'battle') => {
    const g = __game, t0 = performance.now(), log = [];
    if (!await prep(world, log)) return log;
    for (let d = 0; d < ticks; d += 60) log.push(['step', await both(STEP(Math.min(60, ticks - d)))]);
    const r = cmp(JSON.parse(JSON.stringify(g.swT.tablesSave())), JSON.parse(await g.sw.tables()));
    log.push(['gate', r.differ === 0 && !r.rng.length ? 'SAME GAME' : 'DIFFERENT', r]);
    // the mirror: the page takes the worker's snapshots (whole, then 4 deltas of 2 ticks) and must hold the worker's state
    if (g.sw.mirror) {
      log.push(['mirror whole', await g.sw.mirror(true)]);
      for (let i = 0; i < 4; i++) { await g.sw.run(STEP(2)); log.push(['delta', await g.sw.mirror(false)]); }
      const m = cmp(JSON.parse(JSON.stringify(g.swT.tablesSave())), JSON.parse(await g.sw.tables()), ['camera', 'smokeAir']);
      log.push(['mirror', m.differ === 0 ? 'SAME' : 'DIFFERENT', m]);
    }
    unprep(); log.push(["ms", Math.round(performance.now() - t0)]);
    console.log(log);
    return log;
  };
  // live: the worker on its own clock, the page its guest, the fight's shooting sent as commands (and plane fields set in the worker)
  window.__swLive = async (secs = 20) => {
    const g = __game, wait = ms => new Promise(r => setTimeout(r, ms));
    g.paused = false; g.hold = false;
    await g.sw.live();
    let n = 0, worst = 0, prev = performance.now(); const t0 = prev, S = { phys: 0, render: 0 };
    await new Promise(res => {
      const f = () => {
        const now = performance.now(), dt = now - prev; prev = now; n++;
        if (now - t0 > 2000 && dt > worst) worst = dt;
        const P = g.perfNow(); S.phys += P.phys; S.render += P.render;
        if (n % 30 === 0) g.sw.run(`for (let k = 0; k < 1; k++) { ${SHOOT} } return 1;`).catch(() => { });
        if (now - t0 < secs * 1000) requestAnimationFrame(f); else res();
      };
      requestAnimationFrame(f);
    });
    const el = (performance.now() - t0) / 1000, st = await g.sw.stats();
    const row = { fps: +(n / el).toFixed(1), worstMs: Math.round(worst), guestMs: +(S.phys / n).toFixed(2), renderMs: +(S.render / n).toFixed(2), ...st };
    console.table([row]);
    return row;
  };
})();
