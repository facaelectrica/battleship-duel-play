
const ART_PX: f32 = 0.6250;   // (the world's art pixel, world units - 01-zz-real-scale.js)
struct I { m: vec4f, t: vec4f, q: vec4f, at: vec4f, mul: vec4f, mk: vec4f, lit: vec4f, clip: vec4f, cl2: vec4f, x: vec4f, tn: vec4f, ct: vec4f, pf: vec4f, sr: vec4f, wp: vec4f };
@group(0) @binding(0) var<storage, read> inst: array<I>;
@group(0) @binding(1) var art: texture_2d_array<f32>;
@group(0) @binding(2) var masks: texture_2d<f32>;
struct DD { x: f32, y: f32, ox: f32, oy: f32, ord: f32, ns: f32, cx: f32, cy: f32 };   // (the target's size; the view's place on it - its px are the target's less these; an order layer to read (1); the surface's columns; the camera - a row's places are the target's less it)
@group(0) @binding(3) var<storage, read> D: DD;
@group(0) @binding(4) var smp: sampler;
@group(0) @binding(5) var<storage, read> pv: array<vec4f>;
@group(0) @binding(6) var ordL: texture_2d<f32>;              // (what's in front: the order layer the world's drawing wrote - read drawing a thing again over what came after it; a 1x1 stand-in)
@group(0) @binding(7) var<storage, read> surfL: array<vec2f>;  // (the view's surface: each column's row (x), from -3 - the water's, frameShared('water.levels'); a stand-in)
@group(0) @binding(8) var<storage, read> keepR: array<I>;      // (the rows kept on the GPU between frames - thingsRows)
@group(0) @binding(9) var<storage, read> lst: array<vec4u>;    // (the draw's instances in order: its row's place - the top bit: a kept row, the next: drawn above the surface only - and its order numbers)
@group(0) @binding(10) var<storage, read> shp: array<vec2u>;   // (the shape book: what the game paints itself, as runs - 04-zzz-shapes.js)
// a shape's texel ti (its place b in the book, w x h - 04-zzz-shapes.js): its row's runs looked through for the one over the column - premultiplied,
// none outside its box
fn shpAt(b: u32, w: f32, h: f32, ti: vec2i) -> vec4f {
  if (ti.x < 0 || ti.y < 0 || f32(ti.x) >= w || f32(ti.y) >= h) { return vec4f(0.0); }
  let R = shp[b + 1u + u32(ti.y)]; let n = min(R.y, 1024u);
  for (var k = 0u; k < 1024u; k++) {   // (bounded by a constant as well as by the row's count - the laptop's Intel GPU, Nov 10 / 11)
    if (k >= n) { break; }
    let u = shp[b + R.x + k];
    if (i32(u.x & 2047u) > ti.x) { break; }
    if (ti.x < i32((u.x >> 11u) & 2047u)) { let c = unpack4x8unorm(u.y); return vec4f(c.rgb * c.a, c.a); }
  }
  return vec4f(0.0);
}
// the texel at p of a picture whose place is at (its corner at.xy, its size at.zw) on page l: the atlas's (p its texel there), or on page -1 a
// shape's (p - at.xy its own)
fn artTexel(at: vec4f, p: vec2f, l: i32) -> vec4f {
  if (l < 0) { return shpAt(u32(at.x), at.z, at.w, vec2i(floor(p - at.xy))); }
  return textureLoad(art, vec2i(p), l, 0);
}
// an instance's row (this draw's own, or a kept one) and its order numbers [its number, cut from, cut to, above the surface]
fn rowOf(n: u32) -> I { let e = lst[n].x; let r = e & 0x3fffffffu; if ((e >> 31u) == 1u) { return keepR[r]; } return inst[r]; }
fn odOf(n: u32) -> vec4f { let e = lst[n]; return vec4f(bitcast<f32>(e.y), bitcast<f32>(e.z), bitcast<f32>(e.w), f32((e.x >> 30u) & 1u)); }
struct VO { @builtin(position) p: vec4f, @location(0) @interpolate(flat) i: u32 };
@vertex fn vs(@builtin(vertex_index) v: u32, @builtin(instance_index) n: u32) -> VO {
  // (the quad's corner at vertex v of its triangles 0 1 2, 0 2 3 - (0,0) (1,0) (1,1) (0,0) (1,1) (0,1) - from two six-bit masks, a vertex past the sixth
  // as the sixth: no corner table indexed by the vertex, Intel D3D12 scratch memory, Nov 11)
  let k = min(v, 5u); let qv = vec2f(f32((0x16u >> k) & 1u), f32((0x34u >> k) & 1u));
  let a = rowOf(n);
  let l = qv * a.q.xy;   // (t.xy: the quad's corner, the camera left out - added here)
  let d = vec2f(a.m.x * l.x + a.m.z * l.y + a.t.x + D.cx, a.m.y * l.x + a.m.w * l.y + a.t.y + D.cy);
  var o: VO;
  o.p = vec4f(d.x / D.x * 2.0 - 1.0, d.y / D.y * 2.0 - 1.0, 0.0, 1.0);   // (rows bottom first, as every target's: the canvas's row d.y is the target's row h - d.y)
  o.i = n;
  return o;
}
fn hsh(x: i32, y: i32, s: u32) -> f32 {
  var h = (bitcast<u32>(x) * 73856093u) ^ (bitcast<u32>(y) * 19349663u) ^ (s * 83492791u);
  h = h ^ (h >> 16u); h = h * 0x7feb352du; h = h ^ (h >> 15u); h = h * 0x846ca68bu; h = h ^ (h >> 16u);
  return f32(h & 0xffffffu) / 16777215.0;
}
// a picture's blotches (dmgBlots' rule): two octaves of a smooth value noise, cell texels across, the second 0.4 of it at 0.35 the weight
fn blot(t: vec2f, cell: f32, sd: u32) -> f32 {
  var s = 0.0; var a = 0.65; var c = cell;
  for (var o = 0; o < 2; o++) {
    let g = t / c; let i = floor(g); let f = g - i; let u = f * f * (3.0 - 2.0 * f);
    let ix = i32(i.x) + o * 31; let iy = i32(i.y);
    let n0 = hsh(ix, iy, sd); let n1 = hsh(ix + 1, iy, sd); let n2 = hsh(ix, iy + 1, sd); let n3 = hsh(ix + 1, iy + 1, sd);
    s += a * mix(mix(n0, n1, u.x), mix(n2, n3, u.x), u.y);
    a *= 0.35; c *= 0.4;
  }
  return s / 0.8775;
}
/* A PICTURE'S OWN RULES (thingsRules - a plane's frame, a part of its sheet: pf.w its block in pv + 1, 0 none). What used to be copies of
   the frame - a team's or a livery's paint, the rear charred, the frost, a wing torn off, the spinning propeller - worked out texel by
   texel from the sheet's own pixels, before the picture is sized (so its filtering and hard edge are the copies'):
   [0] paint (1 a team's red - tintRed, 2 a livery - recolourCessna), its blue margin, frost's threshold (< 0 none), the rear's char;
   [1] paint colour A (0..255; tintRed's already over 205 and its brightest), the picture's own way round (1 nose left, -1 nose right);
   [2] paint colour B, how many cut boxes; [3] the disc's middle, across, high (0 none - frame texels); [4] its fill, behind the plane (1);
   [5] its rim, how many lettering boxes; [6] the night's colour, own (1); [7] the frame - its place in the sheet [x, y, w, h]; [8] a wreck's
   torn ends (its left end's column + 1, its right end's - 0 none), their seed, its rust (0..1); [9] a cracked piece's edges (cellAt: left,
   right, top, bottom - +-1e6 none) [10] their cracks' places in pv (-1 none) [11] mirrored, on; [12] stretched: its rows from x on read from x
   on, y of a row a row (0 none), how many of the cut boxes its damaged picture takes too; [13] the stretched rows' colour laid over them (rgb, a
   - source-atop, before its paint); [14] a dark patch painted over from beside it: its box [x0, y0, x1, y1] (frame texels; none if empty), [15] where
   from - the column x in its row, else (that one dark too) its own column y rows down, no further than row z - and how dark (w: brightness at
   most) a solid texel in it must be; [16..] the cut boxes: [x0, y0, x1, y1]
   a box of texels taken out, or [x, y, -1, r] a round one; then the lettering boxes [x0, y0, x1, y1]: drawn mirrored, each still reads
   the right way round (its texels mirrored about its own middle - where the flipped copies put the lettered patch back) */
fn rb(a: I) -> u32 { return u32(a.pf.w + 0.5); }
fn rv(a: I, k: u32) -> vec4f { return pv[rb(a) - 1u + k]; }
// a frame texel f as it's read: drawn mirrored (the quad's transform turns it over), inside a lettering box it's read mirrored back
fn keepAt(a: I, f0: vec2f) -> vec2f {
  let nk = min(u32(rv(a, 5u).w + 0.5), 8u);
  if (nk == 0u || a.m.x * a.m.w - a.m.z * a.m.y >= 0.0) { return f0; }
  let o = 16u + u32(rv(a, 2u).w + 0.5); var f = f0;
  for (var j = 0u; j < 8u; j++) { if (j >= nk) { break; } let b = rv(a, o + j); if (f0.x >= b.x && f0.x < b.z && f0.y >= b.y && f0.y < b.w) { f.x = b.x + b.z - 1.0 - f0.x; } }
  return f;
}
// the frame's own place in the picture (rules: its rect; else the whole picture)
fn ownAt(a: I) -> vec4f { if (rb(a) > 0u) { return rv(a, 7u); } return vec4f(0.0, 0.0, a.at.zw); }
// its paint on a texel (premultiplied): a team's red (tintRed's rule), a livery's navy and red (recolourCessna's), the desert's orange
// tone (desertTone's - the desert side's city), a side's colour on steel (a mine's), over olive paint (a tank's, a war helicopter's) or where
// the picture's marked for it (a blimp's)
fn paintR(a: I, c: vec4f) -> vec4f {
  let R0 = rv(a, 0u); let m = i32(R0.x + 0.5);
  if (m == 0 || c.a <= 0.0) { return c; }
  let R1 = rv(a, 1u); let R2 = rv(a, 2u);
  var s = c.rgb / c.a * 255.0;
  if (m == 1) {
    if (s.r >= 80.0 && s.r >= s.g * 1.55 && s.r >= s.b * 1.45) { s = clamp(R1.rgb * s.r, vec3f(0.0), vec3f(255.0)); }
  } else if (m == 6) {
    // (a side's colour where its picture is marked for it - a blimp's band and fins: pure red texels, their red the colour's share x 200)
    if (s.g < 0.5 && s.b < 0.5 && s.r > 0.5) { s = min(vec3f(255.0), R1.rgb * (s.r / 200.0)); }
  } else if (m == 5) {
    // (a side's colour over olive paint - a tank's, a war helicopter's: each olive texel taken R0.y of the way toward the colour at its own
    // brightness (R1 the colour over its own brightness, 1.08 up); the glass, the crew, the white number, the dark metal kept)
    let mx = max(s.r, max(s.g, s.b)); let mn = min(s.r, min(s.g, s.b));
    if (c.a >= 40.0 / 255.0 && s.g > s.b + 10.0 && s.r > s.b + 4.0 && abs(s.r - s.g) < 46.0 && mx < 215.0 && mx - mn > 14.0) {
      s = clamp(s + (R1.rgb * (0.3 * s.r + 0.59 * s.g + 0.11 * s.b) - s) * R0.y, vec3f(0.0), vec3f(255.0));
    }
  } else if (m == 4) {
    // (a side's colour on steel - a mine's: each grey under the glint taken 0.4 toward the colour at the grey's own brightness - R1 the colour
    // over its own brightness)
    let L = (s.r + s.g + s.b) / 3.0;
    if (L < 180.0) { s = s * 0.6 + min(vec3f(255.0), R1.rgb * L) * 0.4; }
  } else if (m == 3) {
    let L = 0.3 * s.r + 0.59 * s.g + 0.11 * s.b;
    s = s * 0.3 + vec3f(min(255.0, L * 1.12 + 22.0), L * 0.86 + 8.0, L * 0.62) * 0.7;
  } else {
    let L = (s.r + s.g + s.b) / 3.0;
    if (s.b > s.r + R0.y && L < 115.0) { s = clamp(R1.rgb * clamp(L / 62.0, 0.45, 1.5), vec3f(0.0), vec3f(255.0)); }
    else if (s.r > s.g + 80.0 && s.r > s.b + 60.0) { s = clamp(R2.rgb * clamp(L / 92.0, 0.45, 1.5), vec3f(0.0), vec3f(255.0)); }
  }
  return vec4f(s / 255.0 * c.a, c.a);
}
/* A WRECK'S TORN ENDS (buildPieceArt's, from a seed - no canvas): from each broken end in, a ragged depth torn away - a wandering line, now and
   then a notch torn deep or a bent plate sticking out, row by row - with a dark scorched lip; shreds of plating hanging off the break; the
   steel burnt black back from it, fading, in blotches. Then the rust of a wreck on the bottom (rusted's rule). In frame texels f, its height h */
fn tornN(y: f32, sd: u32) -> f32 { let i = floor(y); let u = y - i; let e = u * u * (3.0 - 2.0 * u); return mix(hsh(i32(i), 11, sd), hsh(i32(i) + 1, 11, sd), e); }
fn tornDepth(y: f32, sd: u32) -> f32 {
  let iy = i32(y);
  var dd = clamp(4.0 + 40.0 * tornN(y / 13.0, sd) + 14.0 * tornN(y / 3.0, sd + 1u), 3.0, 56.0);
  if (hsh(iy, 1, sd) < 0.08) { dd += 10.0 + 24.0 * hsh(iy, 2, sd); }                     // (a notch torn deep into the hull)
  if (hsh(iy, 3, sd) < 0.05) { dd = max(0.0, dd - 14.0 - 16.0 * hsh(iy, 4, sd)); }         // (a bent plate sticking out)
  return round(dd);
}
fn tornWreck(a: I, f: vec2f, h: f32, c0: vec4f) -> vec4f {
  let T = rv(a, 8u); var c = c0;
  for (var e = 0; e < 2; e++) {
    let ex = select(T.x - 1.0, T.y - 1.0, e == 1); if (select(T.x, T.y, e == 1) <= 0.0) { continue; }
    let i = floor((f.x - ex) * select(1.0, -1.0, e == 1) + 0.001);   // (texels in from the end)
    if (i < 0.0 || i > 150.0) { continue; }
    let sd = u32(T.z) * 2u + u32(e);
    if (c.a > 0.0) {
      let dd = tornDepth(f.y, sd);
      if (i < dd) { c = vec4f(0.0); } else if (i < dd + 4.0) { c = vec4f(c.rgb * select(0.55, 0.25, i < dd + 2.0), c.a); }   // (the scorched lip)
    }
    for (var n = 0; n < 7; n++) {                                                             // (shreds of plating hanging off)
      let y0 = floor(h * (0.3 + 0.65 * hsh(n, 5, sd))); let j = f.y - y0;
      if (j >= 0.0 && j < 4.0 + floor(10.0 * hsh(n, 6, sd)) && i == tornDepth(y0, sd) - 1.0 - floor(j * (0.2 + 0.4 * hsh(n, 7, sd)))) { c = vec4f(38.0, 36.0, 40.0, 255.0) / 255.0; }
    }
    if (c.a > 0.0) {
      var s = c.rgb / c.a;
      if (i < 90.0) { let t = i / 90.0; let k = select(mix(0.45, 0.0, (t - 0.45) / 0.55), mix(0.85, 0.45, t / 0.45), t < 0.45); s = mix(s, select(vec3f(18.0, 12.0, 8.0), mix(vec3f(10.0, 6.0, 4.0), vec3f(18.0, 12.0, 8.0), t / 0.45), t < 0.45) / 255.0, k); }
      for (var n = 0; n < 9; n++) {                                                           // (blotches of it, back into the hull)
        let b = vec2f(10.0 + 100.0 * hsh(n, 8, sd), h * (0.2 + 0.75 * hsh(n, 9, sd))); let r = 18.0 + 24.0 * hsh(n, 10, sd);
        let q = length(vec2f(i + 0.5, f.y + 0.5) - b);
        if (q < r) { let u = q / r; s = mix(s, mix(vec3f(10.0, 6.0, 4.0), vec3f(18.0, 12.0, 8.0), u) / 255.0, 0.75 * (1.0 - u)); }
      }
      c = vec4f(s * c.a, c.a);
    }
  }
  if (T.w > 0.0 && c.a > 0.0) {
    var s = c.rgb / c.a * 255.0; let l = (s.r + s.g + s.b) / 3.0; let nz = 0.85 + 0.3 * hsh(i32(f.x), i32(f.y), 9001u);
    s += (vec3f(l * 0.8 * nz + 52.0, l * 0.55 * nz + 18.0, l * 0.5 * nz + 14.0) - s) * T.w;
    c = vec4f(clamp(s, vec3f(0.0), vec3f(255.0)) / 255.0 * c.a, c.a);
  }
  return c;
}
/* A PIECE OF A TOPPLED TOWER (crumbleTower's cells - no canvases): kept between its four edges, each a crack moved texel by texel along it
   (rules [9]: where, [10]: its offsets' place in pv, -1 a straight edge), its texels near a crack darkened - a scorched rim (0.35, then 0.6);
   f its frame texel, wh the frame, mirrored ([11].x: as the frame's seen, its cracks measured).
   A PIECE OF A CRASHED PLANE's WRECK ([11].z soot - breakArt's, no canvases): kept between its left and right cuts (each edge's places by
   row, [10]), what's nearly clear dropped, sooted all over in blotches and black along a cut (piece q - [11].w - of its picture) */
fn crk(i: f32, k: f32) -> f32 { let j = u32(i + k + 0.5); return pv[j / 4u][j % 4u]; }
fn cellAt(a: I, f0: vec2f, wh: vec2f, c0: vec4f) -> vec4f {
  let E = rv(a, 9u); let P = rv(a, 10u);
  var f = f0; if (rv(a, 11u).x > 0.5) { f.x = wh.x - 1.0 - f0.x; }
  let X = clamp(f.x, 0.0, wh.x - 1.0); let Y = clamp(f.y, 0.0, wh.y - 1.0);
  var near = 99.0;
  var l = E.x; if (P.x >= 0.0) { l += crk(P.x, Y); near = min(near, f.x - l); }
  var r = E.y; if (P.y >= 0.0) { r += crk(P.y, Y); near = min(near, r - 1.0 - f.x); }
  var t = E.z; if (P.z >= 0.0) { t += crk(P.z, X); near = min(near, f.y - t); }
  var b = E.w; if (P.w >= 0.0) { b += crk(P.w, X); near = min(near, b - 1.0 - f.y); }
  if (f.x < l || f.x >= r || f.y < t || f.y >= b) { return vec4f(0.0); }
  let M = rv(a, 11u);
  if (M.z > 0.5) {
    if (c0.a < 10.0 / 255.0) { return vec4f(0.0); }
    let s = c0.rgb / c0.a * 255.0; let X = f.x; let j = f.y;
    let nz = 0.5 + 0.5 * sin(X * 0.37 + j * 0.21) * sin(X * 0.13 - j * 0.29 + M.w);
    let k = select(clamp(0.25 + 0.6 * nz * nz, 0.0, 0.85), 0.92, near < 2.0);
    let o = s * (1.0 - k) + (s * vec3f(0.15, 0.13, 0.12) + vec3f(12.0, 9.0, 8.0)) * k;
    return vec4f(o / 255.0 * c0.a, c0.a);
  }
  if (c0.a > 0.0 && near < 3.0) { return vec4f(c0.rgb * select(0.6, 0.35, near < 1.0), c0.a); }
  return c0;
}
// a balloon's burner glow over its own picture (paint 7 - balloonGlowArt's rule, at frame texel f of its wh): the envelope lit from the mouth (R2.x its
// row) up, deep red through orange to near white at the mouth, the seams and shading kept (its brightness over the picture's brightest, R2.y); the basket
// under it caught from above - straight colour c in, premultiplied out
fn glowR(a: I, f: vec2f, wh: vec2f, c: vec4f) -> vec4f {
  if (c.a < 10.0 / 255.0) { return vec4f(0.0); }
  let R2 = rv(a, 2u); let my = R2.x; let s = c.rgb / c.a * 255.0;
  let sh = 0.5 + 0.65 * dot(s, vec3f(0.3, 0.59, 0.11)) / R2.y;
  var I = 0.6 * clamp(1.0 - (f.y - my) / max(1.0, wh.y - my), 0.0, 1.0) + 0.15;
  if (f.y <= my) { I = clamp(1.0 - length(vec2f((f.x - wh.x * 0.5) / (wh.x * 0.62), (my - f.y) / (my * 0.86))), 0.0, 1.0); }
  if (I <= 0.02) { return vec4f(0.0); }
  let t = min(1.0, I * 1.05);
  var g = mix(vec3f(110.0, 28.0, 34.0), vec3f(196.0, 58.0, 30.0), clamp(t / 0.25, 0.0, 1.0));
  g = select(g, mix(vec3f(196.0, 58.0, 30.0), vec3f(242.0, 122.0, 34.0), (t - 0.25) / 0.25), t > 0.25);
  g = select(g, mix(vec3f(242.0, 122.0, 34.0), vec3f(255.0, 190.0, 70.0), (t - 0.5) / 0.25), t > 0.5);
  g = select(g, mix(vec3f(255.0, 190.0, 70.0), vec3f(255.0, 244.0, 170.0), (t - 0.75) / 0.25), t > 0.75);
  let al = c.a * clamp(I * 2.6, 0.0, 1.0);
  return vec4f(min(vec3f(255.0), g * sh) / 255.0 * al, al);
}
// a texel of a frame with its rules (t0: its texel in the frame's sheet, as drawn) read from the picture at place P on page l - the thing's own (P its
// at), or its damaged picture (its texels scaled from the own's by their sizes) - its first ncut cut boxes taken out; premultiplied
fn texRAt(a: I, t0: vec2f, P: vec4f, l: i32, ncut: u32) -> vec4f {
  let FR = rv(a, 7u);
  if (t0.x < FR.x || t0.y < FR.y || t0.x >= FR.x + FR.z || t0.y >= FR.y + FR.w) { return vec4f(0.0); }
  let f = keepAt(a, t0 - FR.xy); let ti = FR.xy + f;
  let S = rv(a, 12u); var tr = ti;
  let band = S.y > 0.0 && ti.y >= S.x;
  if (band) { tr.y = S.x + floor((ti.y - S.x + 0.5) * S.y); }   // (stretched: the rows from S.x read from S.x on, S.y of a row a row - the nearest)
  var t1 = artTexel(P, P.xy + floor(tr * P.zw / a.at.zw), l);
  let Fb = rv(a, 14u);
  if (Fb.z > Fb.x && t1.a >= 200.0 / 255.0 && f.x >= Fb.x && f.x < Fb.z && f.y >= Fb.y && f.y < Fb.w) {
    let Fs = rv(a, 15u); let s1 = t1.rgb / t1.a * 255.0;
    if (dot(s1, vec3f(0.3, 0.59, 0.11)) <= Fs.w) {   // (a dark texel in the patch: the colour beside it, its own alpha kept)
      var q = artTexel(P, P.xy + floor(vec2f(FR.x + Fs.x, ti.y) * P.zw / a.at.zw), l); let sq = q.rgb / max(q.a, 1e-4) * 255.0;
      if (0.3 * sq.r + 0.59 * sq.g <= 30.0) { q = artTexel(P, P.xy + floor(vec2f(ti.x, FR.y + min(Fs.z, f.y + Fs.y)) * P.zw / a.at.zw), l); }
      t1 = vec4f(q.rgb / max(q.a, 1e-4) * t1.a, t1.a);
    }
  }
  if (band) { let T = rv(a, 13u); t1 = vec4f(t1.rgb * (1.0 - T.a) + T.rgb * T.a * t1.a, t1.a); }   // (its colour laid over them)
  var c: vec4f;
  if (i32(rv(a, 0u).x + 0.5) == 7) { c = glowR(a, f, FR.zw, t1); } else { c = paintR(a, t1); }
  let R0 = rv(a, 0u); let R1 = rv(a, 1u); let R2 = rv(a, 2u);
  if (c.a > 0.0 && R0.w > 0.0) {
    var s = c.rgb / c.a * 255.0;
    var u = (f.x + 0.5) / FR.z; if (R1.w < 0.0) { u = 1.0 - u; } s = mix(s, vec3f(16.0, 12.0, 10.0), clamp((u - 0.35) / 0.6, 0.0, 1.0) * 0.9 * R0.w);
    c = vec4f(s / 255.0 * c.a, c.a);
  }
  let D = rv(a, 3u);
  if (D.w > 0.0) {
    let q = (f + 0.5 - D.xy) / D.zw; let e = dot(q, q);
    if (e <= 1.0) {
      let F = rv(a, 4u);
      var dc = vec4f(F.rgb * (52.0 / 255.0), 52.0 / 255.0);
      if (e > 0.78) { dc = vec4f(rv(a, 5u).rgb * (110.0 / 255.0), 110.0 / 255.0); }
      if (F.w > 0.5) { if (c.a <= 0.0) { c = dc; } } else { c = dc + c * (1.0 - dc.a); }
    }
  }
  let T8 = rv(a, 8u);
  if (T8.x > 0.0 || T8.y > 0.0 || T8.w > 0.0) { c = tornWreck(a, f, FR.w, c); }   // (a wreck's torn ends, its rust)
  if (rv(a, 11u).y > 0.5) { c = cellAt(a, f, FR.zw, c); }                         // (a piece of a toppled tower)
  let nc = min(min(u32(R2.w + 0.5), ncut), 16u);   // (Nov 10: every loop's bound capped by a constant - the laptop's hangs)
  for (var j = 0u; j < nc; j++) {
    let b = rv(a, 16u + j);
    if (b.z >= 0.0) { if (f.x >= b.x && f.x < b.z && f.y >= b.y && f.y < b.w) { c = vec4f(0.0); } }
    else if (length(f + 0.5 - b.xy) <= b.w) { c = vec4f(0.0); }
  }
  return c;
}
fn texR(a: I, t0: vec2f, l: i32) -> vec4f { return texRAt(a, t0, a.at, l, 16u); }
// a frame with its rules at texel place t, from the picture at place P on page l (its first ncut cut boxes): the nearest texel, or (drawn smaller)
// four mixed as the sampler mixes them - each its own rules first
fn lookRAt(a: I, t: vec2f, lin: bool, P: vec4f, l: i32, ncut: u32) -> vec4f {
  if (!lin) { return texRAt(a, floor(t), P, l, ncut); }
  let p = t - 0.5; let i = floor(p); let w = p - i;
  return mix(mix(texRAt(a, i, P, l, ncut), texRAt(a, i + vec2f(1.0, 0.0), P, l, ncut), w.x), mix(texRAt(a, i + vec2f(0.0, 1.0), P, l, ncut), texRAt(a, i + vec2f(1.0, 1.0), P, l, ncut), w.x), w.y);
}
fn lookR(a: I, t: vec2f, lin: bool) -> vec4f { return lookRAt(a, t, lin, a.at, i32(a.cl2.w), 16u); }
// the night's dark shape's colour: its own (a plane's near black) or the things' (civLitLook's)
fn dkc(a: I) -> vec3f { if (rb(a) > 0u) { let d = rv(a, 6u); if (d.w > 0.5) { return d.rgb; } } return vec3f(28.0, 18.0, 12.0) / 255.0; }
// is the picture solid at the screen-sized picture's pixel p (its size wh; k texels a pixel; from its own corner - ownAt) - its hard edge, as scaled() cut it
fn sil(a: I, p: vec2f, wh: vec2f, k: vec2f) -> bool {
  if (p.x < 0.0 || p.y < 0.0 || p.x >= wh.x || p.y >= wh.y) { return false; }
  let O = ownAt(a);
  let tx = min(floor((p + 0.5) * k), O.zw - 1.0);
  if (rb(a) > 0u) { return texR(a, O.xy + tx, i32(a.cl2.w)).a >= 0.4314; }
  return artTexel(a.at, a.at.xy + tx, i32(a.cl2.w)).a >= 0.4314;
}
// a rim on the edges facing a light up to its left (L) or right: lit where the pixel up and toward the light (r pixels) is empty,
// faded along the picture from the light's end (1) to the far end (0.12) - moonArt's rims
fn rim(a: I, ip: vec2f, wh: vec2f, k: vec2f, left: bool) -> f32 {
  let r = a.cl2.y; let dx = select(r, -r, left);
  if (sil(a, ip + vec2f(dx, -r), wh, k)) { return 0.0; }
  let u = (ip.x + 0.5) / wh.x;
  return select(0.12 + 0.88 * u, 1.0 - 0.88 * u, left);
}
// a filled shape's triangles (thingsPoly): each vertex its place on the target and its colour (premultiplied)
struct PO { @builtin(position) p: vec4f, @location(0) c: vec4f, @location(1) @interpolate(flat) s: f32 };
@vertex fn vsPoly(@builtin(vertex_index) v: u32) -> PO {
  let a = pv[v * 2u];
  var o: PO;
  o.p = vec4f(a.x / D.x * 2.0 - 1.0, a.y / D.y * 2.0 - 1.0, 0.0, 1.0);
  o.c = pv[v * 2u + 1u]; o.s = a.z;
  return o;
}
@fragment fn fsPoly(o: PO) -> @location(0) vec4f { return o.c; }
/* WHAT'S IN FRONT (the order layer - the light's slice 5): drawing the world's layer, every quad and shape also writes its draw's number (od.x:
   1, 2, 3... in the order drawn this frame) where it covers (alpha at least a half) into a second target the layer's size - its three bytes
   (r the high, b the low), a 1 - so each pixel holds the number of the last thing drawn there: the one in front. A light that belongs to a thing
   (a window, a boat's lamp - its order: the number drawn when it was given) is cut by the light pass where the layer's number is higher -
   something drawn after its thing, in front of it */
struct WO { @location(0) c: vec4f, @location(1) o: vec4f };
fn ordPx(n: f32, c: vec4f) -> vec4f {
  let k = select(0.0, 1.0, c.a >= 0.5);
  return vec4f(floor(n / 65536.0) / 255.0, floor((n % 65536.0) / 256.0) / 255.0, (n % 256.0) / 255.0, 1.0) * k;
}
@fragment fn fsPolyW(o: PO) -> WO { var w: WO; w.c = o.c; w.o = ordPx(o.s, o.c); return w; }
// a big thing's sections (the damage's list - pf: where they are in pv, how many, has it a damaged picture): their damage (0..1, stepped), then
// where they meet (fractions of the width, n + 1), then its damaged picture's place [x, y, w, h] and [page, sent]
fn pval(o: u32, k: i32) -> f32 { return pv[o + u32(k / 4)][k % 4]; }
fn cutAt(a: I, k: i32) -> f32 { let n = i32(a.pf.y + 0.5); return round(pval(u32(a.pf.x + 0.5) + u32((n + 3) / 4), k) * a.at.z); }
fn midAt(a: I, k: i32) -> f32 { return (cutAt(a, k) + cutAt(a, k + 1)) * 0.5; }
fn secAt(a: I, x: f32) -> i32 { let n = min(i32(a.pf.y + 0.5), 64); var k = 0; for (var j = 1; j < n; j++) { if (x >= cutAt(a, j)) { k = j; } } return k; }
// its charring at texel column x: each section's damage at its middle, eased into its neighbours' (the damage's sums)
fn prof(a: I, x: f32) -> f32 {
  let n = min(i32(a.pf.y + 0.5), 64); let o = u32(a.pf.x + 0.5);
  var k = 0;
  for (var j = 0; j < 63; j++) { if (k >= n - 1 || x <= midAt(a, k + 1)) { break; } k++; }
  var F = pval(o, k);
  if (n > 1) {
    let k0 = select(k, max(0, k - 1), x < midAt(a, k)); let k1 = min(n - 1, k0 + 1); let m0 = midAt(a, k0); let m1 = midAt(a, k1);
    let u = select(0.0, clamp((x - m0) / (m1 - m0), 0.0, 1.0), m1 > m0); let e = u * u * (3.0 - 2.0 * u);
    F = pval(o, k0) + (pval(o, k1) - pval(o, k0)) * e;
  }
  if (F <= 0.02) { return 0.0; }
  return select(0.18 + 0.55 * F, 0.12 + 0.33 * F, a.pf.z > 0.5);
}
// a picture's texel at t (its own texels, from its corner; at its place, l its page): smooth (lin - a picture drawn smaller, as scaled()
// sampled it) or the nearest
fn look(at: vec4f, l: i32, t: vec2f, lin: bool) -> vec4f {
  if (lin && l < 0) {   // (a shape drawn smaller: its four texels mixed as the sampler mixes a picture's)
    let p = clamp(t, vec2f(-1.0), at.zw + 1.0) - 0.5; let i = vec2i(floor(p)); let w = p - floor(p); let b = u32(at.x);
    return mix(mix(shpAt(b, at.z, at.w, i), shpAt(b, at.z, at.w, i + vec2i(1, 0)), w.x), mix(shpAt(b, at.z, at.w, i + vec2i(0, 1)), shpAt(b, at.z, at.w, i + vec2i(1, 1)), w.x), w.y);
  }
  if (lin) { return textureSampleLevel(art, smp, (at.xy + clamp(t, vec2f(-1.0), at.zw + 1.0)) / vec2f(textureDimensions(art).xy), max(l, 0), 0.0); }
  let ti = floor(t);
  if (ti.x < 0.0 || ti.y < 0.0 || ti.x >= at.z || ti.y >= at.w) { return vec4f(0.0); }
  return artTexel(at, at.xy + ti, l);
}
// one tap of the picture at texel place t: a thing's own picture with its damage on it (a section destroyed from its damaged picture,
// the charring, the marks' mask) - premultiplied
fn tap(a: I, t: vec2f, lin: bool, body: bool) -> vec4f {
  let own = rb(a) > 0u;
  var c: vec4f;
  if (own) { c = lookR(a, t, lin); } else { c = look(a.at, i32(a.cl2.w), t, lin); }
  let ti = floor(t);
  if (body && a.pf.y > 0.5 && a.pf.z > 0.5) {
    let o = u32(a.pf.x + 0.5); let n = i32(a.pf.y + 0.5); let ob = o + u32((n + 3) / 4) + u32((n + 4) / 4);
    let B = pv[ob]; let Bl = pv[ob + 1u];
    if (Bl.y > 0.5 && pval(o, secAt(a, clamp(ti.x, 0.0, a.at.z - 1.0))) >= 1.0) {
      if (own) { c = lookRAt(a, t, lin, B, i32(Bl.x), u32(rv(a, 12u).z + 0.5)); }   // (by its own picture's rules: painted, stretched and cut as it is - the cut boxes it takes too)
      else { c = look(B, i32(Bl.x), t * B.zw / a.at.zw, lin); }
    }
  }
  if (c.a <= 0.0 || !body) { return c; }
  var s = c.rgb / c.a;
  let O = ownAt(a);   // (its own texels: a frame's from the frame's corner - its mask, its blotches, its frost)
  let tc = clamp(ti - O.xy, vec2f(0.0), O.zw - 1.0);
  var cov = a.mul.w;
  if (a.pf.y > 0.5) { cov = prof(a, tc.x); }
  if (cov > 0.0) { let kk = clamp((cov - blot(tc, a.mk.z, u32(a.mk.w))) / 0.1, 0.0, 1.0) * 0.92; s += (s * vec3f(0.16, 0.14, 0.13) + vec3f(10.0, 8.0, 7.0) / 255.0 - s) * kk; }
  if (a.mk.x >= 0.0) { let m = textureLoad(masks, vec2i(a.mk.xy + tc), 0); s = mix(s, vec3f(14.0, 10.0, 8.0) / 255.0, m.r); s = mix(s, vec3f(214.0, 208.0, 196.0) / 255.0, m.g); }
  if (own) {
    // (frosted up high: little crusts of ice over the paint - the upper edges first, where the cold air strikes; planeFrost's rule,
    // from the frame's own texels and the two rows over them)
    let th = rv(a, 0u).z;
    if (th >= 0.0) {
      let l = i32(a.cl2.w); let p0 = O.xy + tc;
      if (artTexel(a.at, a.at.xy + p0, l).a > 0.0) {
        let edge = tc.y < 3.0 || artTexel(a.at, a.at.xy + p0 - vec2f(0.0, 1.0), l).a <= 0.0 || artTexel(a.at, a.at.xy + p0 - vec2f(0.0, 3.0), l).a <= 0.0;
        let ix = i32(tc.x); let iy = i32(tc.y);
        let cl = hsh(ix / 4, iy / 4, 7001u); let fine = hsh(ix, iy, 7002u);
        if (select(cl, cl * 0.45, edge) + (fine - 0.5) * 0.18 <= th) { let u = 0.4 + 0.6 * fine; s = vec3f(170.0 + 85.0 * u, 208.0 + 47.0 * u, 238.0 + 17.0 * u) / 255.0; }
      }
    }
  }
  return vec4f(s * c.a, c.a);
}
// the order layer's number at a pixel of the target (q: rows from the top): the thing drawn there last in the world's layer (0 none)
fn ordAt(q: vec2f) -> f32 {
  let d = vec2i(textureDimensions(ordL)); let x = i32(floor(q.x)); let y = i32(floor(q.y));
  if (x < 0 || y < 0 || x >= d.x || y >= d.y) { return 0.0; }
  let o = textureLoad(ordL, vec2i(x, d.y - 1 - y), 0);
  return round(o.r * 255.0) * 65536.0 + round(o.g * 255.0) * 256.0 + round(o.b * 255.0);
}
// (a gradient's stop j - offsets o0 the one before, o1 its own - over colour c at t: c, or the mix of the colours either side of it once t is past o0)
fn gradStop(a: I, c: vec4f, t: f32, j: u32, o0: f32, o1: f32) -> vec4f {
  if (t > o0) { return mix(rv(a, 2u + j), rv(a, 3u + j), clamp((t - o0) / max(o1 - o0, 1e-5), 0.0, 1.0)); }
  return c;
}
fn shade(v: VO) -> vec4f {
  let a = rowOf(v.i); let od = odOf(v.i);
  let q = vec2f(v.p.x, D.y - v.p.y); let qc = q - vec2f(D.cx, D.cy);   // (qc: the pixel with the camera left out - as a row's places are)
  // (a thing drawn again over what came after it in the world - thingsCut: od.yz its numbers in the order layer, (from, to] - only where one of them
  // is in front, its own pixels; from -1: anywhere nothing after to is in front - a thing's light, thingsBehind; od.w 1: only above the water's
  // surface - a pixel whose middle is over its column's row)
  if (od.z > 0.0 && D.ord > 0.5) { let n = ordAt(q); if (n <= od.y || n > od.z) { discard; } }
  if (od.w > 0.5 && D.ns > 0.5) { let c = clamp(i32(floor(q.x - D.ox)) + 3, 0, i32(D.ns) - 1); if (floor(q.y - D.oy) >= surfL[c].x) { discard; } }
  // (a structure's mask: hidden inside its building's walls unless seen through its door)
  if (a.clip.x < a.clip.y && qc.x >= a.clip.x && qc.x < a.clip.y && !(qc.x >= a.clip.z && qc.x < a.clip.w && qc.y >= a.cl2.x)) { discard; }
  let det = a.m.x * a.m.w - a.m.z * a.m.y;
  let r = qc - a.t.xy;
  let lp = vec2f(a.m.w * r.x - a.m.z * r.y, a.m.x * r.y - a.m.y * r.x) / det;   // (this pixel in the quad's own units, from its corner; + t.zw: from the transform's origin - a cut's, a gradient's)
  if (lp.x < 0.0 || lp.y < 0.0 || lp.x >= a.q.x || lp.y >= a.q.y) { discard; }
  // (torn in two: only this half's side of the ragged line - ct: the line's place, the side kept, its seed and step; x.yzw: its two waves'
  // heights and where its rows start - the broken boats' tear, fishHalves)
  if (abs(a.ct.y) > 1.5) {
    // (torn across - a pier's pillar snapped, its stump, a piece of it: only the side (2 below, -2 above) of a row of teeth at row ct.x, every
    // other one up and down by j (x.y) times 0.4..1 from its seed (ct.z), straight between, n (x.z) teeth ct.w apart from x.w - tearArt's;
    // level past its ends)
    let g = (lp.x + a.t.z - a.x.w) / a.ct.w; var yl = a.ct.x;
    if (g >= 0.0 && g <= a.x.z) {
      let k0 = min(floor(g), max(a.x.z - 1.0, 0.0)); let i0 = i32(k0); let sd = u32(a.ct.z);
      let t0 = select(-1.0, 1.0, (i0 & 1) == 1) * (0.4 + 0.6 * hsh(i0, 0, sd));
      let t1 = select(-1.0, 1.0, ((i0 + 1) & 1) == 1) * (0.4 + 0.6 * hsh(i0 + 1, 0, sd));
      yl = a.ct.x + mix(t0, t1, clamp(g - k0, 0.0, 1.0)) * a.x.y;
    }
    if ((lp.y + a.t.w - yl) * a.ct.y < 0.0) { discard; }
  } else if (a.ct.y != 0.0) {
    let ly = lp.y + a.t.w + a.x.w;
    let g = ly / a.ct.w; let g0 = floor(g); let u = g - g0;
    let j0 = round(sin(g0 * 0.9 + a.ct.z) * a.x.y + sin(g0 * 2.3 + a.ct.z * 3.0) * a.x.z);
    let j1 = round(sin((g0 + 1.0) * 0.9 + a.ct.z) * a.x.y + sin((g0 + 1.0) * 2.3 + a.ct.z * 3.0) * a.x.z);
    if ((lp.x + a.t.z - a.ct.x - mix(j0, j1, u)) * a.ct.y < 0.0) { discard; }
  }
  let kind = i32(a.q.z + 0.5); let body = kind == 0;   // (3: the light alone - THG_LIGHT)
  if (kind == 2) { return vec4f(a.mul.rgb, 1.0) * a.q.w; }                                   // (a solid block of colour)
  if (kind == 5) {
    // (a gradient over the quad - thingsGrad, the context's gradients': its block [0] the axis a -> b in the quad's units (radial: its middle a,
    // b on its rim), [1] how many stops, radial; [2] their offsets; [3..] their colours, straight - padded past its ends)
    let G0 = rv(a, 0u); let G1 = rv(a, 1u); let O = rv(a, 2u); let p = lp + a.t.zw; let ab = G0.zw - G0.xy;
    var t = clamp(dot(p - G0.xy, ab) / max(dot(ab, ab), 1e-8), 0.0, 1.0);
    if (G1.y > 0.5) { t = clamp(length(p - G0.xy) / max(length(ab), 1e-4), 0.0, 1.0); }
    let n = u32(G1.x + 0.5); var c = rv(a, 3u);
    // (stops 1, 2, 3 in turn while there are that many - the offsets O's lanes named, not indexed at run time: Intel D3D12 scratch memory, Nov 11)
    if (n > 1u) { c = gradStop(a, c, t, 1u, O.x, O.y); } if (n > 2u) { c = gradStop(a, c, t, 2u, O.y, O.z); } if (n > 3u) { c = gradStop(a, c, t, 3u, O.z, O.w); }
    return vec4f(c.rgb * c.a, c.a) * a.q.w;
  }
  // (a part of the picture only - sr: its texels [x, y, w, h], the rest of the picture still its own for the rims; a sail's band, a column run)
  let sub = a.sr.z > 0.0; let so = select(vec2f(0.0), a.sr.xy, sub);
  let k = select(a.at.zw, a.sr.zw, sub) / a.q.xy;
  // THE WORLD'S ART PIXEL (user Nov 13 15:51: "radically different levels of detail in our pixel art ... the lighthouse should be our target
  // resolution"): in a view, a picture finer than ART_PX world units a texel is drawn on a grid of ART_PX squares fixed to the picture (from its
  // own corner - it moves and turns with it, never shimmers), each square its texels' average (up to 4 x 4 smooth taps), cut at the hard edge as
  // scaled()'s; a picture as coarse or coarser keeps its own texels. Under a screen pixel a square, scaled()'s rule below as before.
  // (User Nov 17: the Biome Editor and TANK VS TANK took ages to open - this pipeline took 10.2 s to compile on his GTX (D3D12) and every draw
  // waited for it. tap() - the picture with its damage, frost and cuts - was written three times here, twice in a 4 x 4 loop the compiler unrolls.
  // Now the three ways only say where their taps go - base + ex * (i + 0.5) / n.x + ey * (j + 0.5) / n.y - and ONE loop takes them: keep tap() in
  // one place in this shader.)
  var base = so + lp * k; var ex = vec2f(0.0); var ey = vec2f(0.0); var n = vec2i(1); var lin = false; var hard = false;
  let gA = select(vec2f(0.0), max(vec2f(1.0), ART_PX * k / max(a.wp.xy, vec2f(1e-6))), a.wp.x > 0.0 && a.wp.y > 0.0);
  if (gA.x * gA.y > 1.001 && a.wp.z >= 1.0) {
    let O = ownAt(a).xy; base = O + floor((base - O) / gA) * gA;
    n = vec2i(clamp(vec2f(ceil(gA - 0.05)), vec2f(1.0), vec2f(4.0))); ex = vec2f(gA.x, 0.0); ey = vec2f(0.0, gA.y); lin = true; hard = true;
  } else if (a.x.x > 0.5) {
    // (scaled()'s picture: drawn smaller, as many smooth taps a side as texels fall in a screen pixel, up to 4, averaged; then the
    // hard edge at 110 / 255 - crisp pixel art at any size; drawn bigger, the nearest texel, cut alike)
    let ddx = vec2f(a.m.w, -a.m.y) / det * k; let ddy = vec2f(-a.m.z, a.m.x) / det * k;
    let down = k.x > 1.0001 || k.y > 1.0001;
    let tpp = max(k.x / length(a.m.xy), k.y / length(a.m.zw));
    n = vec2i(select(1, clamp(i32(ceil(tpp - 0.05)), 1, 4), down)); ex = ddx; ey = ddy; base = base - 0.5 * (ddx + ddy); lin = down; hard = true;
  }
  var acc = vec4f(0.0);
  acc = tap(a, base, lin, body);
  var c = acc / f32(n.x * n.y);
  if (hard) { if (c.a < 0.4314) { discard; } c = vec4f(c.rgb / c.a, 1.0); }
  else { if (c.a <= 0.0) { discard; } c = vec4f(c.rgb / c.a, c.a); }
  var s = c.rgb;
  let raw = s;
  if (kind == 3) {
    // (the light alone, laid over what's under it - civLitLook's own draws, each over the last: the night's dark shape, the moon's sheen,
    // its rim, a low sun's rim; on the picture's solid pixels)
    let O = ownAt(a); let kp = k; let wh = O.zw / k; let ip = floor((so - O.xy) / k + lp); let f = u32(a.cl2.z);
    var o = vec4f(0.0);
    o = vec4f(dkc(a), 1.0) * a.lit.x + o * (1.0 - a.lit.x);
    o = vec4f(raw * 0.5 + vec3f(70.0, 108.0, 170.0) / 255.0 * 0.5, 1.0) * a.lit.y + o * (1.0 - a.lit.y);
    if (a.lit.z > 0.0) { let k2 = a.lit.z * rim(a, ip, wh, kp, (f & 1u) != 0u); o = vec4f(191.0, 228.0, 246.0, 255.0) / 255.0 * k2 + o * (1.0 - k2); }
    if (a.lit.w > 0.0) { let k2 = a.lit.w * rim(a, ip, wh, kp, (f & 2u) != 0u); o = vec4f(255.0, 197.0, 138.0, 255.0) / 255.0 * k2 + o * (1.0 - k2); }
    return o * c.a * a.q.w;
  }
  s *= a.mul.rgb;
  s = mix(s, a.tn.rgb, a.tn.a);                                                                  // (laid over its shape: a colour - burning hot, burnt dark)
  if (body && (a.lit.x + a.lit.y + a.lit.z + a.lit.w) > 0.0) {
    let O = ownAt(a); let kp = k; let wh = O.zw / k; let ip = floor((so - O.xy) / k + lp);
    let f = u32(a.cl2.z);
    s = mix(s, dkc(a), a.lit.x);                                                                  // (the night's dark shape; a burnt one)
    s = mix(s, raw * 0.5 + vec3f(70.0, 108.0, 170.0) / 255.0 * 0.5, a.lit.y);                     // (the moon's sheen)
    if (a.lit.z > 0.0) { s = mix(s, vec3f(191.0, 228.0, 246.0) / 255.0, a.lit.z * rim(a, ip, wh, kp, (f & 1u) != 0u)); }   // (its rim)
    if (a.lit.w > 0.0) { s = mix(s, vec3f(255.0, 197.0, 138.0) / 255.0, a.lit.w * rim(a, ip, wh, kp, (f & 2u) != 0u)); }   // (a low sun's)
  }
  return vec4f(s * c.a, c.a) * a.q.w;
}
@fragment fn fs(v: VO) -> @location(0) vec4f { return shade(v); }
@fragment fn fsW(v: VO) -> WO { let c = shade(v); var w: WO; w.c = c; w.o = ordPx(odOf(v.i).x, c); return w; }