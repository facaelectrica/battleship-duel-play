// (80-fps work, Oct 31, user 22:18: "Did you ever try the rocket to take off two at the same time and make sure that the battles,
// there's rain, there's ships sinking, seeing the oil containers spill oil while planes are fighting and the battleship is
// shooting?") THE EVERYTHING SCENE - OPEN WORLD: the heavy battle's fight (heavy.js: both battleships' guns, both towers, machine
// guns, torpedoes, bombs, the planes in the air with their guns) moved into the open world's sea, the storm pinned, the tanker and
// the container ship brought in between the battleships - the tanker holed again and again (her oil spreading), a container ship
// sunk every 12 s - and BOTH rockets lifting off together.
//   eval(await (await fetch('<this file>')).text()); await __allSetup({ views: 'rocket' }); then __sample(10)
//   views: 'rocket' - the left view rides player 0's rocket, the right one is the sea battle; 'battle' - both views on the battle
//   (the rockets going up off-screen); 'both' - each view on its own player's rocket
window.__allSetup = async ({ views = 'rocket', storm = true, warm = 2 } = {}) => {
  for (let i = 0; i < 80 && typeof __game === 'undefined'; i++) await new Promise(r => setTimeout(r, 250));
  (0, eval)(await (await fetch('https://rawcdn.githack.com/facaelectrica/battleship-duel-play/fab8514f09e080cc59abe580209b0adf5fd762e4/t/live.js')).text());
  (0, eval)(await (await fetch('https://rawcdn.githack.com/facaelectrica/battleship-duel-play/47acdc97cefb3d069aeedd1c868015d538238791/t/storm.js')).text());
  await __liveRun('open', -1);
  __swLive(3);
  await new Promise(r => setTimeout(r, 1200));
  const info = await __game.sw.run(`const R = g.rest(), mid = self.__mid, cs = g.civShips();
    // the tanker and a container ship between the battleships
    const tk = cs.find(c => c.kind === 'tanker'), ct = cs.find(c => c.kind === 'container');
    if (tk) { tk.x = mid - 60; tk.vx = 0; } if (ct) { ct.x = mid + 260; ct.vx = 0; }
    if (self.__hv) clearInterval(self.__hv); let n = 0;
    self.__hv = setInterval(() => { n++;
      for (const p of [0, 1]) {
        try { const gu = g.sgun(p); gu.elev = 24 + (n * 7 + p * 5) % 20; gu.power = 0.42 + ((n + p * 7) % 24) / 100; if (gu.rk) gu.rk = [0, 0]; g.fire(p); } catch (e) { }
        try { g.tower(p, n % 2 === 0); } catch (e) { }
        try { g.shipMG(p); } catch (e) { }
        if (n % 6 === p * 3) try { g.torpedo(p, false); } catch (e) { }
        if (n % 8 === 4 + p) try { g.bomb(p); } catch (e) { }
        try { const pl = T.planes[p]; if (pl.state === 'fly') pl.mg = true; else if (pl.state === 'hangar' && self.__fly && !self.__rk[p]) self.__fly(p); } catch (e) { }
      }
      // the tanker holed every 2 s along her length (her oil out); a container ship sunk every 12 s, a new one brought in
      try { const t = g.civShips().find(c => c.kind === 'tanker' && c.state === 'sail'); if (t && n % 5 === 0) g.civHitHook(t.x + ((n * 37) % 120 - 60), R.WATER_Y - 6); } catch (e) { }
      try { if (n % 30 === 1) { const c = g.civShips().find(c => c.kind === 'container' && c.state === 'sail'); if (c) g.civLose(c); g.civSpawn('container', mid + 260 + (n % 60) * 4, R.SEA0, R.SEA1, 1); } } catch (e) { }
    }, 400);
    self.__rk = [false, false];
    return JSON.stringify({ mid, tanker: !!tk, container: !!ct, shuttles: R.shuttles.map(v => Math.round(v.x)) });`);
  if (storm) await __game.sw.run("Object.assign(g.env, { time: 18.6, weather: 0.92, rain: 0.8, wind: 0.8, sea: 0.9 }); g.W.manual = { time: 1, weather: 1, rain: 1, wind: 1, sea: 1, fog: 1 }; g.computeEnv(); return 1;");
  await new Promise(r => setTimeout(r, warm * 1000));
  // both rockets lit together: the players' own in the views that ride them, the other lit where it stands
  await __game.sw.run(`const S = g.rest().shuttles, ride = ${JSON.stringify(views)};
    for (let i = 0; i < 2; i++) { const v = S[i]; if (!v || v.state !== 'pad') continue;
      const p = ride === 'both' ? i : ride === 'rocket' && i === 0 ? 0 : -1;
      if (p >= 0) { g.boardCiv(p, v); self.__rk[p] = true; g.civLaunch(p); } else { v.state = 'count'; v.t = 0; } }
    return S.map(v => v.state).join();`);
  return info;
};
window.__allState = () => __game.sw.run(`const R = g.rest(); return JSON.stringify({ rk: R.shuttles.map(v => [v.state, Math.round(v.y)]), oil: g.oilSlicks().length, civ: g.civShips().map(c => c.kind[0] + ':' + c.state).join(' '), trail: g.rocketTrail().length, smoke: g.smokeList().length });`);
window.__allStop = () => __game.sw.run('if (self.__hv) clearInterval(self.__hv); self.__hv = null; return 1;');
