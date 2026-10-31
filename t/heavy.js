// (60-fps chat, Oct 31, user 14:08: "Why don't you get rain and a ton of clouds and the towers firing at the same time? Maybe the
// submarine doing something else too") THE HEAVY BATTLE - the frame-rate test from now on: the worker fight (live.js SETUP: both
// battleships out, both subs dived, both planes in the air with their guns), then in the worker, every 0.4 s: both battleships'
// main guns, both towers (shells and machine guns by turns), both ships' machine guns, a torpedo from each sub every 2.4 s, a bomb
// from each plane every 3.2 s, planes sent up again when they're lost; and the storm pinned (weather 0.92, rain 0.8, wind 0.8,
// sea 0.9, dusk) - optional.
//   eval(await (await fetch('<this file>')).text()); await __heavySetup(); then __sample(8)  (storm.js's sampler, loaded here)
window.__heavySetup = async ({ storm = true, warm = 6 } = {}) => {
  for (let i = 0; i < 80 && typeof __game === 'undefined'; i++) await new Promise(r => setTimeout(r, 250));
  (0, eval)(await (await fetch('https://rawcdn.githack.com/facaelectrica/battleship-duel-play/fab8514f09e080cc59abe580209b0adf5fd762e4/t/live.js')).text());
  (0, eval)(await (await fetch('https://rawcdn.githack.com/facaelectrica/battleship-duel-play/47acdc97cefb3d069aeedd1c868015d538238791/t/storm.js')).text());
  await __liveRun('battle', -1);
  __swLive(3);
  await new Promise(r => setTimeout(r, 1200));
  await __game.sw.run(`if (self.__hv) clearInterval(self.__hv); let n = 0;
    self.__hv = setInterval(() => { n++;
      for (const p of [0, 1]) {
        try { const gu = g.sgun(p); gu.elev = 24 + (n * 7 + p * 5) % 20; gu.power = 0.42 + ((n + p * 7) % 24) / 100; if (gu.rk) gu.rk = [0, 0]; g.fire(p); } catch (e) { }
        try { g.tower(p, n % 2 === 0); } catch (e) { }
        try { g.shipMG(p); } catch (e) { }
        if (n % 6 === p * 3) try { g.torpedo(p, false); } catch (e) { }
        if (n % 8 === 4 + p) try { g.bomb(p); } catch (e) { }
        try { const pl = T.planes[p]; if (pl.state === 'fly') pl.mg = true; else if (pl.state === 'hangar' && self.__fly) self.__fly(p); } catch (e) { }
      }
    }, 400); return 1;`);
  if (storm) await __game.sw.run("Object.assign(g.env, { time: 18.6, weather: 0.92, rain: 0.8, wind: 0.8, sea: 0.9 }); g.W.manual = { time: 1, weather: 1, rain: 1, wind: 1, sea: 1, fog: 1 }; g.computeEnv(); return 1;");
  await new Promise(r => setTimeout(r, warm * 1000));
  return JSON.stringify(__game.env);
};
window.__heavyStop = () => __game.sw.run('if (self.__hv) clearInterval(self.__hv); self.__hv = null; return 1;');
