drawLandProps = function (x0, x1, isl, part) {
  if (part !== 'plants') { if (!isl) drawScar(x0, x1); drawTropLayers(x0, x1, isl); }   // (the TROPICAL ground's forest behind, bushes, sand and shore boulders - 50-land-trop)
  if (!land.props || !land.props.length) return;
  if (!desertArt) buildDesertArt();
  const DA = desertKitArt(), fx = E.fx || [1, 1, 1], none = [0, 0, 0];
  const wnd = clamp((E.windU || 0) / 60, -1, 1);
  let lamps = 0;
  VEG_PX = clamp(VTUNE.tree.px || 0.8, 0.1, 4) * SV;   // (user Nov 4 10:46: every plant on the one pixel grid - the world's art pixel on the screen now)
  const VPL = part === 'plants' ? vegPassBegin() : null;   // (the plants of this pass laid in one layer at it - one blit, not one a plant)
  // (Nov 9, storm stress test zoomed out: this runs ~12 times a frame - each deck's pass, each view - over nearly every plant in the world, and every plant's
  // picture and size was looked up before asking whether it belongs to this pass at all. The pass's own questions first, the cheapest first; the same plants drawn)
  for (const it of propsIn(x0, x1)) {
    if (!it.isl !== !isl) continue;
    if ((it.kind === 'rock') !== (part !== 'plants') && part) continue;   // (rocks with the ground, plants after the structures)
    // (user Nov 8 10:59: "anything that is NOT Deck 1 or 0 should be rendering behind the terrain") the editor's DECK 2 and every deck behind it (it.deck 3+) in
    // the pass behind the ground; DECK 1 (it.deck 2) with the structures; DECK 0 (it.deck 1) in front of them
    if (part === 'plants' && !it.uw && !it.cave && (it.deck >= 3 ? 'back' : it.deck === 1 ? 'front' : null) !== VEG_PASS) continue;
    if (VEG_PASS === 'cave' ? !it.cave : VEG_PASS !== 'uw' && (it.uw || it.cave)) continue;
    const rr = plantReach(it); if (rr > PROP_IX.r && it.kind !== 'rock') PROP_IX.r = rr;   // (a picture bigger than any met before: the next span takes it in)
    if (offViewR(it.x, rr, x0, x1)) continue;
    if (VEG_PASS === 'uw' ? !it.uw || !lakeAt(it.x) !== !UW_LK : VEG_PASS === 'cave' ? !it.cave : it.uw || it.cave || lakeAt(it.x)) continue;   // (in a cave: with the stalactites - drawCavePlants)   // (underwater: its water's own pass - drawUwPlants)
    if (isl && (isl === 'land') !== !seaAtX(it.x)) continue;   // (a segment's in a country: drawn in the land's pass - drawIslandsLand)   // (an island's: drawn with it, behind the water)
    if (it.kind === 'rock') {
      const arr = DA && DA.rockC; if (!arr || !arr.length || !it.alive) continue;
      const im = arr[it.pick % arr.length], k = desertArt.kit ? DESERT_PK : it.s / im.width;   // (a rock at its own pixel too)
      const w = Math.round(im.width * k * SV), h = Math.round(im.height * k * SV), fo = (im._fx != null ? im._fx / im.width : 0.5) * w;
      const fX = Math.round(PX(it.x)), X = Math.round(fX - (it.flip ? w - fo : fo)), Y = Math.round(PY(propTop(it) + im.height * k * 0.28)) - h;
      const t = GLR.on ? glTint(im, 'desF', fx, none, false) : im;
      if (it.flip) { C.save(); C.translate(X + w, 0); C.scale(-1, 1); C.drawImage(t, 0, Y, w, h); C.restore(); } else C.drawImage(t, X, Y, w, h);
      continue;
    }
    if (it.state === 'gone' || !it.pk) continue;
    if (it.deck && !rigShown(it)) continue;                 // (its deck hidden in the Biome Editor: nothing of it drawn)
    const G = plantGeo(it); if (!G) continue;
    const im = G.im, bare = G.bare, k = G.k * SV, w = Math.round(im.width * k), h = Math.round(im.height * k), fo = (G.fo / G.k) * k;
    const fX = Math.round(PX(it.x)), foot = Math.round(PY(propTop(it) + G.sink));
    // its colour: the hour's light, darker as it chars; a little glow while it burns
    const ch = 1 - 0.78 * it.char, gl = it.fire > 0 ? 0.12 * it.fire * (0.8 + 0.2 * Math.sin(time * 13 + it.ph)) : 0;
    const mul = [fx[0] * ch, fx[1] * ch * (1 - 0.1 * it.char), fx[2] * ch * (1 - 0.2 * it.char)], add = [gl, gl * 0.4, 0];
    const tint = (src, key) => GLR.on ? glTint(src, key, mul, add, false) : src;
    if (it.fire > 0.1 && lamps < 12) { lamps++; airLamps[viewIdx].push(fX, foot - Math.min(h, 60 * SV) * 0.5, 0.6 * it.fire, lampR((it.pk === 'tree' || it.pk === 'palm' ? 46 : 26) * SV)); }
    const S = bare || im, F = c => it.flip ? flipOf(c) : c, fo2 = it.flip ? w - fo : fo, X = Math.round(fX - fo2);
    if (it.state === 'stump') {
      // (the bottom of its trunk, broken off)
      const sh = Math.max(2, Math.round(im.height * (it.pk === 'palm' ? 0.1 : 0.15)));
      C.drawImage(tint(F(S), 'plS'), 0, im.height - sh, im.width, sh, X, foot - Math.round(sh * k), w, Math.round(sh * k));
      continue;
    }
    if (it.state === 'down' || it.state === 'fall') {
      // (turned over about its foot - lying, its trunk on the ground beside it)
      const lift = it.state === 'down' ? 3 * SV : 0, src = it.state === 'fall' && it.leaf > 0.2 ? im : S;
      C.save(); C.translate(fX, foot - lift); C.rotate(it.fa);
      C.drawImage(tint(F(src), 'plD'), -Math.round(fo2), -h, w, h);
      C.restore();
      continue;
    }
    // standing: swaying in the wind (shaken when it's hit). (user Nov 7 23:26: no little shadow bar at its foot - it looked to float)
    const Y = foot - h;
    { const rc = rigOf(it); if (rc) { drawRigged(it, rc, X, Y, w, k, fx, add, h); continue; } }   // (a tree with bones: its trunk and fronds each move - 50-land-zz-rig.js)
    const tall = it.pk === 'tree' || it.pk === 'palm';
    const sk = (tall ? treeSway(it.ph) : 0) + (it.shake > 0 ? Math.sin(time * 38 + it.ph) * 0.05 * it.shake : 0);
    if (sk) { C.save(); C.translate(fX, foot); C.transform(1, 0, -sk, 1, 0, 0); C.translate(-fX, -foot); }
    const leaf = bare ? it.leaf : 1;
    if (leaf < 0.999 && bare) C.drawImage(tint(F(bare), 'plB'), X, Y, w, h);
    if (leaf > 0.001) { if (leaf < 0.999) C.globalAlpha = leaf; C.drawImage(tint(F(im), 'plW'), X, Y, w, h); C.globalAlpha = 1; }
    if (tall && GLR.on) civLitLook(F(leaf > 0.5 || !bare ? im : bare), k, X, Y, PX(it.x), 0);   // (the moon's and a low sun's rim, as every object's)
    if (sk) C.restore();
  }
  if (VPL) vegPassEnd(VPL);
}
;plantReach = function (it) { if (!SIM_ONLY && it._rrT === renderTick) return it._rr; const G = plantGeo(it), r = G ? Math.max(G.w, G.h) : 220; if (!SIM_ONLY) { it._rrT = renderTick; it._rr = r; } return r; }