
const CELL: f32 = 2.5000;
const ACELL: f32 = 0.6250;                      // (the world's art pixel - the ground painted in them, AN a cell across and down: 01-zz-real-scale.js)
const AN: f32 = 4.0;
const LT_Y0: f32 = -20.0000;
const WATER_Y: f32 = 400.0000;
const PAGE: i32 = 64;
const RB: i32 = -4096;
const M_AIR: u32 = 0u; const M_GRASS: u32 = 1u; const M_DIRT: u32 = 2u; const M_SAND: u32 = 3u; const M_ROCK: u32 = 4u; const M_CONC: u32 = 5u;
const NONE: u32 = 0xffffffffu; const BLACK: u32 = 0xfffffffeu;
const CW: u32 = 6u;                                           // (words a cell: w0 cell, w1 column facts, d0 d1 derived, w4 noise, w5 its stone and rare picks)
const SW: u32 = 9u;                                           // (vec4s a stone)
fn hu(x: u32) -> u32 { var v = x * 747796405u + 2891336453u; v = ((v >> ((v >> 28u) + 4u)) ^ v) * 277803737u; return (v >> 22u) ^ v; }
// an integer hash 0..1 of two integers and a salt (each use of the old hash its own salt)
fn gh(a: i32, b: i32, s: u32) -> f32 { return f32(hu(hu(bitcast<u32>(a) + s * 0x9E3779B9u) ^ (bitcast<u32>(b) * 0x85EBCA6Bu)) >> 8u) / 16777216.0; }
fn sstep(a: f32, b: f32, x: f32) -> f32 { let t = clamp((x - a) / (b - a), 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }
@group(0) @binding(1) var<storage, read> stones: array<vec4f>;
fn sva(b: u32, i: u32) -> f32 { return stones[b + 3u + i / 4u][i % 4u]; }
fn svx(b: u32, i: u32) -> f32 { return stones[b + 5u + i / 4u][i % 4u]; }
fn svy(b: u32, i: u32) -> f32 { return stones[b + 7u + i / 4u][i % 4u]; }
// (stoneHit) is (dx, dy) - in the stone's own measure - inside it: x how far in from its edge, y z its face's outward way, w how far out toward that face; ok
struct Hit { ok: bool, d: f32, nx: f32, ny: f32, f: f32 }
fn stoneHit(b: u32, dx: f32, dy: f32) -> Hit {
  let n = max(1u, min(u32(stones[b + 1u].x), 8u)); let th = atan2(dy, dx);   // (Nov 10: capped - a stone has 8 corners at most: sva / svx)
  var i: i32 = i32(n) - 1;
  for (var k = 0u; k < 8u; k++) { if (k >= n) { break; } if (sva(b, k) > th) { i = i32(k) - 1; break; } }
  if (i < 0) { i = i32(n) - 1; }
  let j = (u32(i) + 1u) % n; let ax = svx(b, u32(i)); let ay = svy(b, u32(i)); let ex = svx(b, j) - ax; let ey = svy(b, j) - ay;
  var L = sqrt(ex * ex + ey * ey); if (L == 0.0) { L = 1.0; }
  var nx = ey / L; var ny = -ex / L; let h = nx * ax + ny * ay; if (h < 0.0) { nx = -nx; ny = -ny; }
  let Hh = abs(h); let d = Hh - (nx * dx + ny * dy);
  return Hit(d >= 0.0, d, nx, ny, 1.0 - d / select(Hh, 1.0, Hh == 0.0));
}
const PAL_G = array<vec3f, 4>(vec3f(142.0, 170.0, 58.0), vec3f(124.0, 152.0, 48.0), vec3f(162.0, 182.0, 66.0), vec3f(64.0, 104.0, 34.0));
fn PAL_G_at(i: u32) -> vec3f { return select(select(select(PAL_G[0], PAL_G[1], i >= 1u), PAL_G[2], i >= 2u), PAL_G[3], i >= 3u); }
const PAL_DI = array<vec3f, 7>(vec3f(112.0, 78.0, 52.0), vec3f(98.0, 67.0, 45.0), vec3f(124.0, 88.0, 58.0), vec3f(28.0, 21.0, 20.0), vec3f(152.0, 110.0, 72.0), vec3f(184.0, 142.0, 98.0), vec3f(70.0, 49.0, 36.0));
fn PAL_DI_at(i: u32) -> vec3f { return select(select(select(select(select(select(PAL_DI[0], PAL_DI[1], i >= 1u), PAL_DI[2], i >= 2u), PAL_DI[3], i >= 3u), PAL_DI[4], i >= 4u), PAL_DI[5], i >= 5u), PAL_DI[6], i >= 6u); }
const PAL_S = array<vec3f, 3>(vec3f(216.0, 190.0, 128.0), vec3f(198.0, 170.0, 110.0), vec3f(232.0, 210.0, 152.0));
fn PAL_S_at(i: u32) -> vec3f { return select(select(PAL_S[0], PAL_S[1], i >= 1u), PAL_S[2], i >= 2u); }
const PAL_R = array<vec3f, 6>(vec3f(150.0, 144.0, 134.0), vec3f(128.0, 122.0, 114.0), vec3f(216.0, 210.0, 198.0), vec3f(46.0, 42.0, 40.0), vec3f(100.0, 95.0, 89.0), vec3f(184.0, 178.0, 166.0));
fn PAL_R_at(i: u32) -> vec3f { return select(select(select(select(select(PAL_R[0], PAL_R[1], i >= 1u), PAL_R[2], i >= 2u), PAL_R[3], i >= 3u), PAL_R[4], i >= 4u), PAL_R[5], i >= 5u); }
const PAL_C = array<vec3f, 6>(vec3f(170.0, 168.0, 162.0), vec3f(158.0, 156.0, 150.0), vec3f(194.0, 192.0, 186.0), vec3f(84.0, 84.0, 86.0), vec3f(140.0, 138.0, 134.0), vec3f(236.0, 234.0, 226.0));
fn PAL_C_at(i: u32) -> vec3f { return select(select(select(select(select(PAL_C[0], PAL_C[1], i >= 1u), PAL_C[2], i >= 2u), PAL_C[3], i >= 3u), PAL_C[4], i >= 4u), PAL_C[5], i >= 5u); }
const PALD_DI = array<vec3f, 7>(vec3f(150.0, 92.0, 64.0), vec3f(132.0, 80.0, 58.0), vec3f(168.0, 106.0, 74.0), vec3f(30.0, 20.0, 22.0), vec3f(184.0, 124.0, 86.0), vec3f(206.0, 150.0, 104.0), vec3f(110.0, 66.0, 50.0));
fn PALD_DI_at(i: u32) -> vec3f { return select(select(select(select(select(select(PALD_DI[0], PALD_DI[1], i >= 1u), PALD_DI[2], i >= 2u), PALD_DI[3], i >= 3u), PALD_DI[4], i >= 4u), PALD_DI[5], i >= 5u), PALD_DI[6], i >= 6u); }
const PALD_S = array<vec3f, 3>(vec3f(232.0, 186.0, 120.0), vec3f(214.0, 164.0, 104.0), vec3f(246.0, 208.0, 148.0));
fn PALD_S_at(i: u32) -> vec3f { return select(select(PALD_S[0], PALD_S[1], i >= 1u), PALD_S[2], i >= 2u); }
const PALD_R = array<vec3f, 6>(vec3f(200.0, 140.0, 96.0), vec3f(176.0, 118.0, 82.0), vec3f(230.0, 176.0, 124.0), vec3f(70.0, 44.0, 40.0), vec3f(150.0, 98.0, 72.0), vec3f(214.0, 158.0, 110.0));
fn PALD_R_at(i: u32) -> vec3f { return select(select(select(select(select(PALD_R[0], PALD_R[1], i >= 1u), PALD_R[2], i >= 2u), PALD_R[3], i >= 3u), PALD_R[4], i >= 4u), PALD_R[5], i >= 5u); }
const PALD_C = array<vec3f, 6>(vec3f(190.0, 172.0, 148.0), vec3f(176.0, 160.0, 138.0), vec3f(212.0, 196.0, 172.0), vec3f(96.0, 82.0, 72.0), vec3f(158.0, 142.0, 122.0), vec3f(240.0, 232.0, 214.0));
fn PALD_C_at(i: u32) -> vec3f { return select(select(select(select(select(PALD_C[0], PALD_C[1], i >= 1u), PALD_C[2], i >= 2u), PALD_C[3], i >= 3u), PALD_C[4], i >= 4u), PALD_C[5], i >= 5u); }
const DES_EARTH = array<vec3f, 4>(vec3f(184.0, 104.0, 62.0), vec3f(160.0, 86.0, 50.0), vec3f(140.0, 72.0, 44.0), vec3f(172.0, 96.0, 56.0));
fn DES_EARTH_at(i: u32) -> vec3f { return select(select(select(DES_EARTH[0], DES_EARTH[1], i >= 1u), DES_EARTH[2], i >= 2u), DES_EARTH[3], i >= 3u); }
const DES_SAND = array<vec3f, 4>(vec3f(224.0, 162.0, 96.0), vec3f(210.0, 146.0, 84.0), vec3f(234.0, 178.0, 112.0), vec3f(198.0, 134.0, 78.0));
const DES_CRUST = array<vec3f, 4>(vec3f(246.0, 226.0, 176.0), vec3f(234.0, 204.0, 148.0), vec3f(216.0, 178.0, 122.0), vec3f(168.0, 110.0, 68.0));
const DES_STONE = array<vec3f, 6>(vec3f(238.0, 170.0, 110.0), vec3f(220.0, 136.0, 86.0), vec3f(200.0, 112.0, 72.0), vec3f(182.0, 100.0, 66.0), vec3f(144.0, 78.0, 60.0), vec3f(98.0, 52.0, 46.0));
const DES_PEB = array<vec3f, 2>(vec3f(222.0, 158.0, 104.0), vec3f(96.0, 50.0, 36.0));
const SEA_SAND = array<vec3f, 3>(vec3f(196.0, 181.0, 148.0), vec3f(183.0, 166.0, 131.0), vec3f(160.0, 144.0, 113.0));
const SEA_SILT = array<vec3f, 3>(vec3f(128.0, 115.0, 94.0), vec3f(112.0, 101.0, 83.0), vec3f(138.0, 125.0, 102.0));
const SEA_PEB = array<vec3f, 3>(vec3f(120.0, 118.0, 116.0), vec3f(92.0, 90.0, 92.0), vec3f(150.0, 146.0, 140.0));
fn SEA_PEB_at(i: u32) -> vec3f { return select(select(SEA_PEB[0], SEA_PEB[1], i >= 1u), SEA_PEB[2], i >= 2u); }
const MEADOW = array<vec3f, 4>(vec3f(58.0, 104.0, 98.0), vec3f(92.0, 136.0, 84.0), vec3f(130.0, 162.0, 64.0), vec3f(160.0, 182.0, 78.0));
const DFIELD = array<vec3f, 4>(vec3f(226.0, 178.0, 116.0), vec3f(208.0, 158.0, 100.0), vec3f(240.0, 198.0, 138.0), vec3f(176.0, 128.0, 84.0));
const DES_SEAM = vec3f(108, 52, 36); const TROP_IN_TOP = vec3f(222, 176, 110); const TROP_IN_DEEP = vec3f(132, 80, 44);
const LT_DEEP = vec3f(0, 0, 0); const LT_DEEP_D = vec3f(0, 0, 0); const UG = vec3f(0, 0, 0);

// ---- DRAW ----
struct View { fx: vec4f, rim: vec4f, sun: vec4f, c: vec4f }
// fx: the hour's light (bytes / 255) | rim: colour, strength | sun: x, y (the view's own pixels), 1 if there, the hour's light way x |
// c: its y, UNDERGROUND LIGHT, STONE COLOURS, edge on (a cell 2 pixels or more)
// the view's camera (frameCam, src/gpu/50-frame.js): left px, top px, scale, zoom | view x on the target, view width (world), target w, h | time, view, shake x, y
struct Cam { camPx: f32, topPx: f32, sv: f32, ox: f32, oy: f32, tw: f32, th: f32, vx0: f32, vx1: f32 }
fn cam() -> Cam { let a = FD[4]; let b = FD[5]; let c = FD[6]; return Cam(a.x, a.y, a.z, b.x + c.z, c.w, b.z, b.w, b.x, b.x + b.y * a.z); }
struct Slot { k: i32, c0: i32, rT: i32, rB: i32, j0: i32, npr: i32, sb: u32, w: i32, rBL: i32, rBR: i32, p1: i32, p0: i32 }
// (the draw's own numbers, one buffer - a stage has 8 storage buffers at least: FD[0..3] the view's light (View), FD[4..7] its camera (frameCam's),
// FD[8..] the biomes' table (8 x BIOV), then 4 vec4s an instance)
@group(0) @binding(0) var<storage, read> FD: array<vec4f>;
const FD_BIO: u32 = 8u; const FD_INST: u32 = 144u;
@group(0) @binding(2) var<storage, read> pages: array<u32>;
@group(0) @binding(3) var<storage, read> ptab: array<u32>;
@group(0) @binding(4) var<storage, read> slots: array<Slot>;
@group(0) @binding(5) var<storage, read> cols: array<vec4f>;
// (the strata: the processor's hash of a stratum b (b + 2048): x desertEarth's pick, y its faint line's, z desertRock's - the first STRATA
// vec4s of bcols: the draw is held to 8 storage buffers, the iPad's limit)
const STRATA: u32 = 4096u;
fn sth(b: f32) -> vec4f { return bcols[u32(clamp(i32(b) + 2048, 0, i32(STRATA) - 1))]; }
const PTS: u32 = 128u;
const BCV: u32 = 8u;
const LT_MIX: f32 = 45.0; const LT_MIX_DEEP: f32 = 110.0; const LT_MIX_D: f32 = 180.0;
@group(0) @binding(6) var<storage, read> bcols: array<vec4f>;
@group(0) @binding(8) var<storage, read> art: array<u32>;
const COLV: u32 = 7u;
// which page set this draw is (FD[0].w): 0 the ground in front - the rows from each column's split row down -, 1 the islands' over it
fn which() -> u32 { return u32(FD[0].w); }
// a row in this draw's rows: the ground in front's from the split row down, the islands' over it
fn mine(si: u32, c: i32, r: f32) -> bool { return (r < col(si, c, 2u).x) == (which() == 1u); }
const BIOV: u32 = 17u;
// the level this draw reads (the instance's: a cell every 2^LV - ggLevel), and the levels' places in a slot's page table (GG_LOFF)
var<private> LV: u32 = 0u;

fn loff(L: u32) -> u32 { return select(select(select(0u, 64u, L == 1u), 97u, L == 2u), 114u, L == 3u); }
fn cellAtW(si: u32, c: i32, r: i32, L: u32, wh: u32) -> u32 {
  let S = slots[si]; let sh = 6u + L; let jl0 = (S.rT + 4096) >> sh;
  let j = ((r + 4096) >> sh) - jl0;
  if (j < 0) { return 0xfffffffdu; }
  if (j > ((S.rB - 1 + 4096) >> sh) - jl0) { return 0xfffffffeu; }
  let p = ptab[(si * 2u + wh) * 128u + loff(L) + u32(j)]; if (p >= 0xfffffffeu) { return p; }
  return (p * 4096u + (u32((r + 4096) >> L) & 63u) * 64u + (u32(c >> L) & 63u)) * 6u;
}

fn cellAtL(si: u32, c: i32, r: i32, L: u32) -> u32 { return cellAtW(si, c, r, L, which()); }
// a cell's words as this draw's level has them - while it isn't loaded, a finer level's standing in (loaded before a zoom out), else a coarser one's
// (level 3's: loaded first wherever a view is); NONE: none loaded yet
fn cellAt(si: u32, c: i32, r: i32) -> u32 {
  for (var q = 0; q <= 3; q++) { let L = i32(min(LV, 3u)) - q; if (L < 0) { break; } let o = cellAtL(si, c, r, u32(L)); if (o != NONE) { return o; } }
  for (var L = LV + 1u; L <= 3u; L++) { let o = cellAtL(si, c, r, L); if (o != NONE) { return o; } }
  return NONE;
}
fn ok(o: u32) -> bool { return o < NONE - 2u; }
fn matAt(si: u32, c: i32, r: i32) -> u32 {
  let S = slots[si]; if (r >= S.rB) { return M_ROCK; } if (r < S.rT) { return M_AIR; }
  let o = cellAt(si, c, r); if (o == NONE - 2u) { return M_AIR; } if (o >= BLACK) { return M_ROCK; }
  return pages[o] & 7u;
}
fn col(si: u32, c: i32, v: u32) -> vec4f { return cols[(si * 64u + u32(c - slots[si].c0)) * COLV + v]; }
fn bv(b: u32, v: u32) -> vec4f { return FD[FD_BIO + b * BIOV + v]; }
// a type (ltTypeKey: look | trop << 1 | mtn << 2 | bio << 3) -> its biome (colBiome): 0 forest, 1 desert, 2 mountain, 3 tropical, 4 ice, 5 swamp, 6 volcanic, 7 sea
fn tBiome(t: u32) -> u32 { let b = t >> 3u; if (b != 0u) { return 3u + b; } if ((t & 4u) != 0u) { return 2u; } if ((t & 2u) != 0u) { return 3u; } if ((t & 1u) != 0u) { return 1u; } return 0u; }
fn pal(m: u32, des: bool, i: u32) -> vec3f {
  if (m == M_GRASS) { return PAL_G_at(i); }
  if (m == M_DIRT) { if (des) { return PALD_DI_at(i); } return PAL_DI_at(i); }
  if (m == M_SAND) { if (des) { return PALD_S_at(i); } return PAL_S_at(i); }
  if (m == M_ROCK) { if (des) { return PALD_R_at(i); } return PAL_R_at(i); }
  if (des) { return PALD_C_at(i); } return PAL_C_at(i);
}
fn lum(c: vec3f) -> f32 { return min(1.0, (0.3 * c.x + 0.59 * c.y + 0.11 * c.z) / 255.0 * 1.45); }
// a cell's colour col (material m, depth cells under its open top, seam: between stones, h its own noise 0..1) in biome b; nb (VOLCANIC, a seam
// cell): 2 a narrow gap between two stones, 1 touching one, 0 neither
// (Nov 7, after the user's references gen/biome_ref/ref-volcanic.png and ref-swamp.png - the stand-ins made over:) VOLCANIC near-black basalt boulders lit
// from the upper left, packed in a black-brown matrix, glowing lava cracks where two stones nearly meet, an orange crust along the top; SWAMP wet
// glossy mud lumps, red-brown, olive moss in patches, black wet gaps; ICE pale blue ice chunks, bright where lit, deep blue cracks, snow on top
// (the rule's one copy - its JS twin in 09-zz-biomes.js, unused since the grid, deleted Nov 10) ICE 1 / SWAMP 2 / VOLCANIC 3
fn bioTint(b: u32, cin: vec3f, m: u32, depth: f32, seam: bool, h: f32, x: f32, nb: u32, isd: f32) -> vec3f {
  let L = lum(cin);
  if (b == 1u) {
    if (depth < isd) { return select(vec3f(244.0, 248.0, 252.0), vec3f(226.0, 236.0, 246.0), h < 0.3); }
    if (depth < isd + 2.0 && h < 0.5) { return vec3f(214.0, 226.0, 240.0); }
    if (seam) { return select(vec3f(34.0, 54.0, 86.0), vec3f(52.0, 78.0, 112.0), h < 0.2); }
    if (L > 0.86) { return vec3f(246.0, 251.0, 255.0); } return mix(vec3f(70.0, 104.0, 142.0), vec3f(214.0, 234.0, 250.0), L);
  }
  if (b == 2u) {
    if (m == M_GRASS) { return mix(vec3f(62.0, 64.0, 24.0), vec3f(132.0, 128.0, 52.0), L); }
    if (m == M_SAND) { if (h < 0.3) { return vec3f(86.0, 60.0, 38.0); } return mix(vec3f(58.0, 38.0, 24.0), vec3f(118.0, 82.0, 52.0), L * 0.8); }
    if (seam) { return select(vec3f(30.0, 17.0, 12.0), vec3f(46.0, 26.0, 18.0), h < 0.3); }
    let mp = sin(x / 23.0 + depth * 0.37) + sin(x / 9.7 - depth * 0.61);
    if (mp > 1.35 && depth > 1.0) { return select(vec3f(96.0, 90.0, 36.0), vec3f(132.0, 124.0, 52.0), L > 0.6); }
    if (L > 0.84) { return vec3f(204.0, 148.0, 110.0); } return mix(vec3f(50.0, 26.0, 17.0), vec3f(154.0, 90.0, 56.0), L);
  }
  if (seam) {
    if (depth < 1.0) { return select(vec3f(150.0, 52.0, 22.0), vec3f(236.0, 110.0, 38.0), h < 0.55); }
    if (nb == 2u && depth > 1.0) { return select(vec3f(255.0, 160.0, 70.0), vec3f(234.0, 104.0, 34.0), h < 0.75); }
    if (nb == 1u && h < 0.4 && depth > 1.0) { return select(vec3f(150.0, 54.0, 22.0), vec3f(214.0, 88.0, 30.0), h < 0.2); }
    return select(vec3f(26.0, 17.0, 15.0), vec3f(40.0, 24.0, 20.0), h < 0.3);
  }
  if (L > 0.97) { return vec3f(62.0, 60.0, 68.0); } return mix(vec3f(9.0, 8.0, 10.0), vec3f(46.0, 44.0, 50.0), L * 0.9);
}
// (surfLayerCol) layer l of biome b: its three tones speckled, grit for gravel and ash; k how far down it is
fn layerCol(b: u32, l: u32, c: i32, r: i32, k: f32, h: f32, rb: u32) -> vec3f {
  let o = 1u + l * 4u; let f = u32(bv(b, o).w);
  let P0 = bv(b, o).xyz; let P1 = bv(b, o + 1u).xyz; let P2 = bv(b, o + 2u).xyz;
  var cc = select(select(P1, P2, h > 0.86), P0, h < 0.24);
  if ((f & 1u) != 0u && (rb & (1u << 21u)) != 0u) { cc = select(P2, P0, (rb & (1u << 22u)) != 0u); }
  if (k > 0.0) { return mix(cc, P2, min(1.0, k) * 0.35); } return cc;
}
fn fadeAt(d: f32, c: i32, r: i32) -> f32 {
  let B = FD[3].y; var f = sstep(B * 0.13, B, d) * 8.0; let lo = floor(f);
  f = lo + select(0.0, 1.0, (f - lo) > select(0.38, 0.62, ((c + r) & 1) != 0));
  return min(1.0, f / 8.0);
}
fn stint(cc: vec3f, b: u32) -> vec3f { let Vs = FD[3].z; let s = stones[b + 1u]; let tb = 1.0 + (s.z - 1.0) * Vs; let tw = s.w * Vs; return vec3f(cc.x * tb + tw, cc.y * tb, cc.z * tb - tw * 0.6); }
// (the old seaFloorCol's rule - its one copy now: the world's sea floor and the open floor past its ends) the sea's floor: its sand layer, under it the silt with its pebbles
fn seaFloor(si: u32, c: i32, r: i32, d: f32, hs: f32, rb: u32) -> vec3f {
  let L4 = col(si, c, 4u); let L5 = col(si, c, 5u); let n = min(u32(L5.x), 4u); let sd = L5.y;   // (Nov 10: capped - a vec4's 4 layers at most)
  var acc = 0.0; var li = 99u; var k = 0.0;
  // (layer i's bottom L4's lane i by selects - not a vector indexed at run time: Intel D3D12 scratch memory, Nov 11)
  for (var i = 0u; i < 4u; i++) { if (i >= n) { break; } let bot = select(select(select(L4.x, L4.y, i >= 1u), L4.z, i >= 2u), L4.w, i >= 3u); if (d < bot) { if (d >= acc) { li = i; k = (d - acc) / max(1.0, bot - acc); } break; } acc = bot; }
  var cc: vec3f;
  if (li != 99u) {
    let f = u32(bv(7u, 1u + li * 4u).w);
    if ((f & 4u) == 0u || (f & 8u) != 0u) { cc = layerCol(7u, li, c, r, k, hs, rb); }
    else { let t = select(select(SEA_SAND[0], SEA_SAND[2], hs > 0.9), SEA_SAND[1], hs < 0.22); cc = mix(t, SEA_SAND[2], k * 0.55); }
  } else {
    cc = select(select(SEA_SILT[0], SEA_SILT[2], hs > 0.93), SEA_SILT[1], hs < 0.3);
    let pk = (rb >> 27u) & 3u; if (pk != 0u) { cc = SEA_PEB_at(pk - 1u); }   // (its pebble: the processor's - one to a jittered 10-cell square)
    if (d - sd < 4.0) { cc = mix(cc, SEA_SAND[2], 0.5); }
  }
  let f = fadeAt(d, c, r); if (f > 0.0) { cc = mix(cc, LT_DEEP, f); }
  return cc;
}
// the stone's look at a cell: its face's shade t (stoneFaceShade), e how far in from its rim, ux uy where in it, up its upward faces
struct SR { t: f32, e: f32, ux: f32, uy: f32, up: f32 }
fn stoneAt(b: u32, P: vec2f, hs: f32) -> SR {
  let o = stones[b]; return stoneLook(b, (P.x - o.x) / o.z, (P.y - o.y) / o.w, hs);
}
// (P a world point) is it inside stone b
fn stoneHas(b: u32, P: vec2f) -> bool { let o = stones[b]; let dx = (P.x - o.x) / o.z; let dy = (P.y - o.y) / o.w; return dx * dx + dy * dy <= 1.0 && stoneHit(b, dx, dy).ok; }
// THE ART PIXEL'S STONE (user Nov 13 15:51 - the ground at the lighthouse's detail): a cell's art pixel at P (its quarter sp of the cell) lies in the
// cell's own stone, or in the stone of the cell beside it, under it or across from it toward P, or in none (the earth between) - the stones'
// outlines drawn at the art pixel, not the cell. Its place in the stones (0xffffffff: none)
fn subStone(si: u32, c: i32, r: i32, w5: u32, P: vec2f, sp: vec2f) -> u32 {
  let S = slots[si]; let sj = w5 & 0xffffu;
  if (sj != 0xffffu) { let b = (S.sb + sj) * SW; if (stoneHas(b, P)) { return b; } }
  let dx = select(1, -1, sp.x < 0.5); let dy = select(1, -1, sp.y < 0.5);
  let cx = c + dx; let ry = r + dy; let inX = cx >= S.c0 && cx < S.c0 + S.w; let inY = ry >= S.rT && ry < S.rB;
  if (inX) { let o = cellAt(si, cx, r); if (ok(o)) { let j = pages[o + 5u] & 0xffffu; if (j != 0xffffu) { let b = (S.sb + j) * SW; if (stoneHas(b, P)) { return b; } } } }
  if (inY) { let o = cellAt(si, c, ry); if (ok(o)) { let j = pages[o + 5u] & 0xffffu; if (j != 0xffffu) { let b = (S.sb + j) * SW; if (stoneHas(b, P)) { return b; } } } }
  if (inX && inY) { let o = cellAt(si, cx, ry); if (ok(o)) { let j = pages[o + 5u] & 0xffffu; if (j != 0xffffu) { let b = (S.sb + j) * SW; if (stoneHas(b, P)) { return b; } } } }
  return 0xffffffffu;
}
// (dx, dy: where in the stone, in its own measure - a cell of the grid's (stoneAt) or of a loose stone's own (fsLoose))
fn stoneLook(b: u32, dx: f32, dy: f32, hs: f32) -> SR {
  let h = stoneHit(b, dx, dy);
  let w = sstep(0.32, 0.72, h.f); let f = -(h.nx * 0.55 + h.ny * 0.85);
  return SR(0.42 * (1.0 - w) + f * w - 0.2 * max(0.0, h.ny) * w + (hs - 0.5) * 0.16, h.d * stones[b + 2u].w, dx, dy, select(-h.ny, 1.0, h.f < 0.4));
}
// (desertCell) the desert's earth; soft: the crust (lit softly from above)
struct DC { c: vec3f, soft: bool }
fn desertCell(si: u32, c: i32, r: i32, m: u32, depth: f32, hs: f32, jit0: f32, sb0: u32, hasS: bool, rb: u32, P: vec2f, eK: f32) -> DC {
  if (hasS && (m == M_DIRT || m == M_ROCK)) {
    let S = stoneAt(sb0, P, hs); let k0 = stones[sb0 + 2u].x;   // (DES_STONE read where it's used - not copied into a local array: Intel D3D12 scratch memory, Nov 11)
    var cc = select(select(select(DES_STONE[4], select(DES_STONE[3], DES_STONE[2], k0 < 0.5), S.t > -0.25), DES_STONE[1], S.t > 0.22), DES_STONE[0], S.t > 0.6);
    if (S.e < 0.9 * eK && S.t < 0.2) { cc = DES_STONE[5]; }
    if ((rb & (1u << 17u)) != 0u) { cc = mix(cc, DES_STONE[4], 0.55); }   // (a bedding line across it - the processor's)
    return DC(stint(cc, sb0), false);
  }
  let C0 = col(si, c, 0u); let C3 = col(si, c, 3u); let y = LT_Y0 + f32(r) * CELL; let t0 = C0.y;
  let d0 = round((y - t0) / CELL); let jit = jit0 - 0.5; let cr = C3.x; let sb = C3.y;
  if (depth == d0 && depth < 4.0 && d0 + jit * 0.6 < cr + 0.7) {
    if (d0 + jit * 0.6 >= cr) { return DC(DES_CRUST[3], false); }
    if (d0 < 1.0) { return DC(select(DES_CRUST[0], DES_CRUST[1], hs < 0.12), true); }
    return DC(select(DES_CRUST[1], DES_CRUST[2], hs < 0.22), true);
  }
  let sand = select(select(select(DES_SAND[0], DES_SAND[2], hs > 0.85), DES_SAND[1], hs < 0.25), DES_SAND[3], ((r + i32(floor(f32(c) / 7.0))) % 5 + 5) % 5 == 0 && hs < 0.5);
  if (d0 >= 0.0 && d0 + jit * 1.6 < sb) { return DC(sand, false); }
  var deep: vec3f;
  if (m == M_ROCK) {
    let v = y / 9.0 + C3.w; let b = floor(v); let f = v - b;
    deep = select(DES_STONE[3], DES_STONE[2], sth(b).z < 0.5);
    if (f < 0.18) { deep = DES_STONE[4]; } else if (hs > 0.9) { deep = DES_STONE[1]; }
  } else {
    let v = y - C0.x + C3.z; let T = 22.0; let b = floor(v / T); let f = v / T - b;
    deep = DES_EARTH_at(min(3u, u32(sth(b).x * 4.0)));
    if (f < 0.07 && (rb & (1u << 18u)) != 0u) { deep = mix(deep, DES_SEAM, 0.55); }
    else if (sth(b).y < 0.45 && abs(f - 0.55) < 0.05) { deep = mix(deep, DES_SEAM, 0.25); }
    else if (hs < 0.12) { deep = deep * 0.9; } else if (hs > 0.92) { deep = deep * 1.07; }
    if ((rb & (1u << 19u)) != 0u) { deep = DES_PEB[0]; } else if ((rb & (1u << 20u)) != 0u) { deep = DES_PEB[1]; }
  }
  if (d0 >= 0.0 && d0 + jit * 1.6 < sb + 2.0) { return DC(mix(sand, deep, 0.5), false); }
  return DC(select(deep, mix(sand, deep, 0.4), m == M_SAND), false);
}
// a cell's type: its own column's, or across the seam (ltTC - the processor's choice, a bit of w0)
// (r: a segment's own rows over its end row SE - islPaintLook - are the segment's type)
fn typeOf(si: u32, c: i32, r: i32, w0: u32) -> u32 { let C6 = col(si, c, 6u); if (f32(r) < C6.x) { return u32(C6.y); } let C1 = col(si, c, 1u); if (col(si, c, 0u).w < 0.0) { return u32(C1.x); } return select(u32(C1.y), u32(C1.z), (w0 & (1u << 21u)) != 0u); }
// THE CELL'S COLOUR (paintLandChunk0): 0..255, before the hour's light
// (sp: the art pixel's place in the cell - its middle, (k + 0.5) / AN across and down - or x < 0: the whole cell, as before - an art pixel under a screen pixel)
fn cellCol(si: u32, c: i32, r: i32, o: u32, sp: vec2f) -> vec3f {
  let S = slots[si]; let w0 = pages[o]; let w1 = pages[o + 1u]; let d0 = pages[o + 2u]; let d1 = pages[o + 3u]; let w4 = pages[o + 4u]; let w5 = pages[o + 5u];
  let sub = sp.x >= 0.0; let spp = select(vec2f(0.5), sp, sub); let P = vec2f((f32(c) + spp.x) * CELL, LT_Y0 + (f32(r) + spp.y) * CELL); let eK = select(1.0, 1.0 / AN, sub);
  let m = w0 & 7u; let depth = f32(w1 & 0xffffu); let jit = (f32(w4 >> 16u) + 0.5) / 65536.0; let bk = (w5 >> 29u) & 3u;
  // (its noise: the processor's for the cell; an art pixel's its own - each of the four of a cell its own pick, as each cell had)
  let hs = select((f32(w4 & 0xffffu) + 0.5) / 65536.0, gh(c * i32(AN) + i32(spp.x * AN), r * i32(AN) + i32(spp.y * AN), 0x51u), sub);
  let C0 = col(si, c, 0u); let C1 = col(si, c, 1u); let C2 = col(si, c, 2u); let own = u32(C1.x); let cfl = u32(C1.w);
  let SEG = f32(r) < col(si, c, 6u).x; let SEAB = (cfl & 1u) != 0u && !SEG;
  let up = select(M_AIR, matAt(si, c, r - 1), r > S.rT && f32(r) != col(si, c, 6u).x); let dn = select(M_ROCK, matAt(si, c, r + 1), r < S.rB - 1);
  let tC = typeOf(si, c, r, w0); let sj = w5 & 0xffffu; let sbS = select(select(0xffffffffu, (S.sb + sj) * SW, sj != 0xffffu), subStone(si, c, r, w5, P, spp), sub);
  let hasS = sbS != 0xffffffffu; let sb0 = select(0u, sbS, hasS);
  let tt = select(tC, u32(stones[select(0u, sb0 + 2u, hasS)].y), hasS && !SEG);   // (in a stone: its middle's type - stoneTC; a segment's rows: the segment's)
  let DSx = (tt & 1u) != 0u; let BIO = tt >> 3u; let BS = bv(tBiome(own), 0u); let BSx = select(bv(tBiome(tt), 0u), BS, SEG);
  let TRC = (tt & 2u) != 0u; let TRCc = (tC & 2u) != 0u && !SEG;
  var cc: vec3f; var SJ = false; var soft = false;
  if (SEAB) { cc = seaFloor(si, c, r, max(0.0, P.y - C0.y), hs, w5); }
  else if (DSx && m != M_CONC) { let D = desertCell(si, c, r, m, depth, hs, jit, sb0, hasS, w5, P, eK); cc = D.c; soft = D.soft; }
  else if (m == M_DIRT || m == M_ROCK || (m == M_SAND && (TRC || TRCc))) {
    SJ = !hasS;
    if (!hasS && (tt & 4u) != 0u) { cc = select(select(PAL_R[4] * 0.8, PAL_R[4], hs < 0.3), PAL_R[0], depth < 2.0); }
    else if (!hasS) { cc = select(select(pal(M_DIRT, DSx, 3u), pal(M_DIRT, DSx, 6u), hs < 0.14), select(select(pal(M_DIRT, DSx, 0u), pal(M_DIRT, DSx, 1u), hs < 0.75), pal(M_DIRT, DSx, 6u), hs < 0.35), depth < 3.0); }
    else {
      let St = stoneAt(sb0, P, hs); let k0 = stones[sb0 + 2u].x; let grey = stones[sb0 + 1u].y > 0.5; let rx = stones[sb0].z;
      if (grey) {
        cc = select(select(select(pal(M_ROCK, DSx, 4u), select(pal(M_ROCK, DSx, 1u), pal(M_ROCK, DSx, 0u), k0 < 0.5), St.t > -0.25), pal(M_ROCK, DSx, 5u), St.t > 0.22), pal(M_ROCK, DSx, 2u), St.t > 0.6);
        if (St.e < 0.9 * eK && St.t < 0.2) { cc = pal(M_ROCK, DSx, 4u); }
        let cy = 0.25 * sin(St.ux * 4.2 + k0 * 9.0) - 0.15 + 0.3 * (k0 - 0.5); let cx = 0.3 * sin(St.uy * 3.7 + k0 * 5.0) + 0.2;
        if (k0 > 0.35 && rx > 9.0 && ((abs(St.uy - cy) < 0.06 && abs(St.ux) < 0.7) || (k0 > 0.7 && abs(St.ux - cx) < 0.06 && St.uy > cy && St.uy < 0.6))) { cc = pal(M_ROCK, DSx, 4u) * 0.82; }
        if ((w5 & (1u << 16u)) != 0u) { cc = mix(cc, vec3f(104.0, 128.0, 66.0), 0.45); }   // (moss on its upward faces - the processor's)
      } else {
        cc = select(select(select(pal(M_DIRT, DSx, 6u), select(select(pal(M_DIRT, DSx, 0u), pal(M_DIRT, DSx, 2u), k0 > 0.66), pal(M_DIRT, DSx, 1u), k0 < 0.33), St.t > -0.3), pal(M_DIRT, DSx, 4u), St.t > 0.25), pal(M_DIRT, DSx, 5u), St.t > 0.62 && rx > 6.0);
        if (St.e < 0.8 * eK && St.t < 0.25) { cc = pal(M_DIRT, DSx, 6u); }
      }
      cc = stint(cc, sb0);
    }
    if (TRC) {   // (tropInterior: sand to earth)
      let t = clamp(depth * CELL / 170.0, 0.0, 1.0); let tg = mix(TROP_IN_TOP, TROP_IN_DEEP, t * t * (3.0 - 2.0 * t));
      if (!hasS) { cc = tg * (0.97 - 0.3 * t - select(0.0, 0.08, (w5 & (1u << 26u)) != 0u)); } else { cc = mix(cc, tg, 0.3 + 0.12 * (1.0 - t)); }
    }
  } else if (m == M_SAND) { cc = select(select(pal(M_SAND, DSx, 0u), pal(M_SAND, DSx, 2u), hs > 0.85), pal(M_SAND, DSx, 1u), hs < 0.25); }
  else if (m == M_CONC) {
    let sx = ((c % 16) + 16) % 16; let C5 = col(si, c, 5u);
    if (depth == 0.0) { cc = select(pal(M_CONC, DSx, 2u), pal(M_CONC, DSx, 5u), ((c % 40) + 40) % 40 < 16 && hs < 0.97); }
    else if (sx == 0) { cc = pal(M_CONC, DSx, 3u); } else if (depth >= 7.0) { cc = pal(M_CONC, DSx, 4u); } else if (hs < 0.08) { cc = pal(M_CONC, DSx, 1u); }
    else if (C5.z < 0.3 && hs < 0.3) { cc = pal(M_CONC, DSx, 4u); } else { cc = pal(M_CONC, DSx, 0u); }
  }
  else if (m == M_GRASS && BSx.x < 0.5 && ((d0 >> 16u) & 3u) == 2u) { cc = select(select(pal(M_DIRT, DSx, 0u), pal(M_DIRT, DSx, 1u), hs < 0.75), pal(M_DIRT, DSx, 6u), hs < 0.35); }
  else {
    if (depth < 2.0) { cc = select(select(PAL_G[0], PAL_G[2], hs > 0.75), PAL_G[1], hs < 0.3); }
    else if (depth < 7.0) { cc = select(select(select(PAL_G[2], PAL_G[3], bk == 2u), PAL_G[1], bk == 1u), vec3f(99.0, 121.0, 70.0), bk == 0u); }
    else { cc = PAL_G[3]; }
    if (dn != M_GRASS && depth >= 4.0) { cc = select(PAL_G[3], vec3f(52.0, 88.0, 34.0), hs < 0.5); }
  }
  var NB = 0u;
  if (BIO == 3u && SJ) {
    let ol = cellAt(si, c - 1, r); let orr = cellAt(si, c + 1, r);
    let L1 = c > S.c0 && ok(ol) && (pages[ol + 5u] & 0xffffu) != 0xffffu; let R1 = c < S.c0 + S.w - 1 && ok(orr) && (pages[orr + 5u] & 0xffffu) != 0xffffu;
    let ou = cellAt(si, c, r - 1); let od = cellAt(si, c, r + 1);
    let U1 = r > S.rT && ok(ou) && (pages[ou + 5u] & 0xffffu) != 0xffffu; let D1 = r < S.rB - 1 && ok(od) && (pages[od + 5u] & 0xffffu) != 0xffffu;
    NB = select(select(0u, 1u, L1 || R1 || U1 || D1), 2u, (L1 && R1) || (U1 && D1));
  }
  if (BIO != 0u && m != M_CONC && !SEAB) { cc = bioTint(BIO, cc, m, depth, SJ, hs, f32(c) * CELL, NB, C2.y); }
  let LY = (w0 >> 11u) & 15u;
  if (LY != 0u && !SEAB) {
    let bn = select(tBiome(tC), u32(col(si, c, 6u).z), SEG); let Lb = bv(bn, 0u);
    if (f32(LY) <= Lb.w) { let f = u32(bv(bn, 1u + (LY - 1u) * 4u).w); if (!((f & 2u) != 0u && hasS)) { cc = layerCol(bn, LY - 1u, c, r, min(1.0, depth / 12.0), hs, w5); } }
  }
  let ug = (w0 >> 15u) & 3u;   // (its shape's HIDE INTERIOR: 1 seen all the way in, 2 dark inside, 0 as before - ugCell)
  // the light from above
  var k2 = 1.0 - min(0.18, depth * 0.006);
  let ec = (d0 >> 16u) & 3u;
  if (up == M_AIR) { k2 *= select(1.22, 1.04, m == M_GRASS || m == M_CONC || soft); }
  else if (dn == M_AIR) { k2 *= 0.62; }
  else if (r + 3 < S.rB && (matAt(si, c, r + 2) == M_AIR || matAt(si, c, r + 3) == M_AIR) && ec == 3u) { k2 *= 1.0 - select(0.16, 0.28, matAt(si, c, r + 2) == M_AIR) * BSx.z; }
  if (((d1 >> 16u) & 1u) != 0u) { k2 *= select(0.85, 1.0, up == M_AIR); }
  let gq = d1 & 0xffffu;
  if (gq != 0xffffu) { let t = 1.0 - (f32(gq) / 256.0) / 72.0; let sh = 1.0 - 0.8 * t * t * (3.0 - 2.0 * t); k2 *= 1.0 - (1.0 - sh) * sstep(0.0, 4.0, depth); }
  let sc = f32((w0 >> 3u) & 255u) / 255.0;
  cc = vec3f(cc.x * k2 * (1.0 - 0.72 * sc) + 14.0 * sc, cc.y * k2 * (1.0 - 0.75 * sc) + 10.0 * sc, cc.z * k2 * (1.0 - 0.75 * sc) + 8.0 * sc);
  let dist = f32(d0 & 0xffffu) / 256.0;
  let SE6 = col(si, c, 6u).x; let dd = select(dist, min(dist, f32(r) - SE6), f32(r) >= SE6);   // (under a segment: from the ground in front's own top)
  let fd = select(fadeAt(dd * CELL, c, r), 0.0, ug == 1u);
  if (ug == 1u) { cc = cc * (1.0 - 0.8 * sstep(0.0, 700.0, depth * CELL)); }
  else if (fd > 0.0) { cc = mix(cc, select(LT_DEEP, LT_DEEP_D, DSx), fd); }
  return cc;
}
// a root hanging under the cell r - b (b 1..4) into the air at (c, r) (paintLandChunk0's roots): its colour, or none (x < 0)
fn rootAt(si: u32, c: i32, r: i32) -> vec4f {
  let S = slots[si];
  for (var b = 1; b <= 4; b++) {
    let rs = r - b; if (rs < S.rT) { break; }
    let o = cellAt(si, c, rs); if (!ok(o)) { break; }
    let m = pages[o] & 7u; if (m == M_AIR) { continue; }
    if (m == M_CONC) { break; }
    let up = select(M_AIR, matAt(si, c, rs - 1), rs > S.rT); if (up == M_AIR) { break; }
    if (((pages[o + 2u] >> 16u) & 3u) != 3u) { break; }
    let w5 = pages[o + 5u];
    if ((w5 & (1u << 23u)) == 0u) { break; }                   // (the processor's pick against its biome's BOTTOM ROOTS)
    let n = 1 + i32((w5 >> 24u) & 3u); if (b > n) { break; }
    return vec4f(vec3f(58.0, 40.0, 26.0) * (1.0 - f32(b) * 0.08), 1.0);
  }
  return vec4f(-1.0);
}
/* ---- THE OLD PICTURES' PLACES (drawLandGround: each slice's tiles, its smooth edge and its rims were pictures laid on the screen - zoomed out, their
   halved copies - ltFar; the same pixels come out here: each screen pixel is given the picture pixel each of them showed there, and that pixel's cell).
   An instance's numbers, worked out by the processor in doubles as the old drawing did (ggDrawTo): its slot, X0 X1 (the slice's columns on the
   screen), YT YB (its canvas's top and bottom), its neighbours' bottoms, the rims' and the edge's whole-slice bands' places (UT UB, UY0 UY1), the
   rims' light way ---- */
struct Inst { si: u32, X0: f32, X1: f32, YT: f32, YB: f32, YBL: f32, YBR: f32, p0: f32, p1: f32, p2: f32, p3: f32, lx: f32, ly: f32, nb: f32, lv: f32, p4: f32 }
fn instOf(ii: u32) -> Inst { let o = FD_INST + ii * 4u; let a = FD[o]; let b = FD[o + 1u]; let c = FD[o + 2u]; let d = FD[o + 3u];
  return Inst(u32(a.x), a.y, a.z, a.w, b.x, b.y, b.z, b.w, c.x, c.y, c.z, c.w, d.x, d.y, d.z, d.w); }
struct VO { @builtin(position) p: vec4f, @location(0) @interpolate(flat) ii: u32 }
@vertex fn vs(@builtin(vertex_index) vi: u32, @builtin(instance_index) ii: u32) -> VO {
  let I = instOf(ii); let K = cam();
  let u = f32(vi & 1u); let v = f32((vi >> 1u) & 1u);
  let X = mix(I.X0 - 1.0, I.X1 + 1.0, u) + K.ox; let Y = mix(I.YT - 2.0 + K.oy, K.th, v);
  var o: VO; o.p = vec4f(X / K.tw * 2.0 - 1.0, Y / K.th * 2.0 - 1.0, 0.0, 1.0); o.ii = ii;
  return o;
}
// the hour's light on a colour (the colour's bytes x E.fx's - the ground's sprites take the same, gsTint)
fn lit(cc: vec3f) -> vec3f { return clamp(round(cc), vec3f(0.0), vec3f(255.0)) / 255.0 * FD[0].xyz; }
// a pixel of slice si's tile picture (cell column c, cell row r): the cell's colour, or a blade's or a root's in the air over / under it; none: x < 0
fn tilePx(si: u32, c: i32, r: i32, sp: vec2f) -> vec3f {
  let S = slots[si];
  if (r < S.rT || r >= S.rB) { return vec3f(-1.0); }
  if (!mine(si, c, f32(r))) { return vec3f(-1.0); }              // (the other set's rows: the islands' over the split row - islSplitEnd - in their own tile)
  let o = cellAt(si, c, r);
  if (o == NONE || o == NONE - 2u) { return vec3f(-1.0); }       // (not there yet: it loads in)
  if (o == BLACK) { return UG; }
  if ((pages[o] & 7u) != M_AIR) { return cellCol(si, c, r, o, sp); }
  var outc = vec3f(-1.0);
  let down = i32(pages[o + 1u] & 0xffffu);
  // a root hanging under an overhang; a blade standing up out of a grass top under it (the blade painted after: blades a column cols v2.z, their colour v2.w)
  let rt = rootAt(si, c, r); if (rt.x >= 0.0) { outc = rt.xyz; }
  if (sp.x < 0.0) {
    if (down >= 1 && down <= 3 && f32(down) <= col(si, c, 2u).z) {
      let ot = cellAt(si, c, r + down);
      if (ok(ot) && (pages[ot] & 7u) == M_GRASS) { let gc = select(PAL_G[0], PAL_G[2], col(si, c, 2u).w > 0.5); outc = gc * (1.0 - f32(down) * 0.06); }
    }
  } else if (down >= 1 && down <= 35 && col(si, c, 2u).z > 0.0) {   // (35: the blades' 3 cells over the smooth line at its highest - GEDGE_UP 31)
    // (user Nov 13 16:36: "Shouldn't grass and plants be on the same grid?") the blades in the world's art pixels: each art column of the cell its own
    // blade (or none), its height up to the column's (cells x AN) - n the art pixel's place over the grass top, 1 the first
    let ot = cellAt(si, c, r + down);
    if (ok(ot) && (pages[ot] & 7u) == M_GRASS) {
      let k = c * i32(AN) + i32(sp.x * AN); let hk = gh(k, 0, 0x6Bu);
      let bh = select(0.0, ceil(col(si, c, 2u).z * AN * (0.25 + 0.75 * gh(k, 1, 0x6Bu))), hk >= 0.3);
      // (user Nov 13 18:38, one ground: counted from the smooth line over the grass top - edgeAt's line at this art column - not from the cell's step)
      let t = r + down; let wt = pages[ot + 1u]; let la = f32(t) - f32((wt >> 16u) & 255u) / 8.0; let lb = f32(t) - f32(wt >> 24u) / 8.0;
      let hq = f32(t * 4 - i32(floor((la + (lb - la) * (floor(sp.x * AN) + 0.5) / AN) * 4.0 + 0.5)));
      let n = floor((f32(down) - sp.y) * AN) + 1.0 - hq;
      if (n >= 1.0 && n <= bh) { let gc = select(PAL_G[0], PAL_G[2], (col(si, c, 2u).w > 0.5) != (hk > 0.8)); outc = gc * (1.0 - n / AN * 0.06); }
    }
  }
  return outc;
}
// the smooth edge at quarter cell (i, r4) of column c (r4: a quarter row, global): the top cell's colour where it's under the ground's smooth line
// (gedgeLine, 50-land-terrain.js) and over the run's top t (in the air over it), or none - w: the top cell's rim over it (rimMake's top flag), the
// line's top lit as the cell's top was
fn edgeAt(si: u32, c: i32, i: i32, r4: i32, sub: bool) -> vec4f {
  let S = slots[si]; let r = r4 >> 2u; if (r < S.rT || r >= S.rB) { return vec4f(-1.0); }
  let o = cellAt(si, c, r); if (!ok(o) || (pages[o] & 7u) != M_AIR) { return vec4f(-1.0); }
  let w0 = pages[o]; let down = i32(pages[o + 1u] & 0xffffu); if (down <= 0 || down >= 0xffff) { return vec4f(-1.0); }
  let t = r + down; if (!mine(si, c, f32(t))) { return vec4f(-1.0); }
  let ot = cellAt(si, c, t); if (!ok(ot)) { return vec4f(-1.0); }
  let wt = pages[ot + 1u]; let aD = i32((wt >> 16u) & 255u); let bD = i32(wt >> 24u); if (aD == 0 && bD == 0) { return vec4f(-1.0); }
  let oa = cellAt(si, c, t - 1); let first = (w0 & (1u << 19u)) != 0u; let op = ok(oa) && (pages[oa] & (1u << 20u)) != 0u; if (!(first || op)) { return vec4f(-1.0); }
  let a = f32(t) - f32(aD) / 8.0; let bb = f32(t) - f32(bD) / 8.0;   // (gedgeLine: the line's heights at the column's sides, eighths of a cell)
  let yy = i32(floor((a + (bb - a) * (f32(i) + 0.5) / 4.0) * 4.0 + 0.5));
  if (r4 < yy || r4 >= t * 4) { return vec4f(-1.0); }
  return vec4f(cellCol(si, c, t, ot, select(vec2f(-1.0), vec2f((floor((f32(i) + 0.5) * AN / 4.0) + 0.5) / AN, 0.5 / AN), sub)), f32((pages[ot + 2u] >> 22u) & 3u));   // (the art pixel over it: the top cell's top row's)
}
// (a cell's side lit as it faces the light: f its rim's strength (0 none, 1, 2 the full), w how much it faces the light) over cc
fn rimOver(cc: vec4f, f: u32, w: f32) -> vec4f {
  if (f == 0u || w < 0.03) { return cc; }
  let a = select(120.0, 255.0, f == 2u) / 255.0 * min(1.0, w * FD[1].w);
  return vec4f(cc.xyz * (1.0 - a) + FD[1].xyz * a, cc.w * (1.0 - a) + a);   // (premultiplied: over what's under, the ground or what's behind it)
}
@fragment fn fs(fi: VO) -> @location(0) vec4f {
  let I = instOf(fi.ii); let si = I.si; let S = slots[si]; let K = cam();
  LV = min(u32(I.lv), 3u);   // (Nov 10: capped - a level from the instance's words never walks more than 4 levels)
  if (fi.p.x < K.vx0 || fi.p.x >= K.vx1) { discard; }
  let X = fi.p.x - K.ox; let Y = (K.th - fi.p.y) - K.oy;          // (the view's own pixels - PX / PY's; the target's rows are WebGL's: bottom up)
  if (X < I.X0 || X >= I.X1) { discard; }
  let px = floor(X); let py = floor(Y);
  // the dark under the slices, a pixel wider than each and from a row over its bottom - over its neighbours' first and last columns too
  if (which() == 0u && (py >= I.YB - 1.0 || (px == I.X0 && py >= I.YBL - 1.0) || (px == I.X1 - 1.0 && py >= I.YBR - 1.0))) { return vec4f(UG / 255.0, 1.0); }   // (the islands': none)
  // the cell under the pixel: the slice's columns across [X0, X1), its rows (from 4 over its top) down [YT, YB)
  let w = S.w; let fx = (X - I.X0) / (I.X1 - I.X0) * f32(w); let q = clamp(i32(floor(fx)), 0, w - 1); let c = S.c0 + q;
  let rr = (Y - I.YT) / (I.YB - I.YT) * f32(S.rB - S.rT + 4) + f32(S.rT - 4); let r = i32(floor(rr));
  var cc = vec4f(0.0);
  // (an art pixel a screen pixel or more: the cell painted in the world's art pixels, AN across and down - sp the one this pixel's in, its middle; else the cell whole)
  let big = (I.X1 - I.X0) / f32(w) >= AN;
  let sp = select(vec2f(-1.0), (floor(clamp(vec2f(fx - f32(q), rr - f32(r)), vec2f(0.0), vec2f(0.999)) * AN) + 0.5) / AN, big);
  let tc = tilePx(si, c, r, sp); if (tc.x >= 0.0) { cc = vec4f(lit(tc), 1.0); }
  // the smooth edge over the cells' steps (a cell 2 pixels or more)
  // (user Nov 13 18:08, light lines inside a slope: the rims belong on the line, not on the cells' steps buried under it - the top's rim on the line's
  // top art pixel; a cell's top or side rim only where no line lies over it)
  let eon = (I.X1 - I.X0) / f32(w) >= 2.0; let i4 = clamp(i32(floor((fx - f32(q)) * 4.0)), 0, 3); let r4 = i32(floor(rr * 4.0));
  if (eon) { let ec = edgeAt(si, c, i4, r4, big); if (ec.x >= 0.0) { cc = vec4f(lit(ec.xyz), 1.0); if (big && FD[1].w >= 0.02 && edgeAt(si, c, i4, r4 - 1, big).x < 0.0) { cc = rimOver(cc, u32(ec.w), -I.ly * 0.7); } } }
  // the rims in the sun and the moon (rimMake): a cell's sides with the air a cell or two off, each as it faces the light
  if (FD[1].w >= 0.02 && I.X1 - I.X0 >= 2.0 && r >= S.rT && r < S.rB && mine(si, c, f32(r))) {
    let o = cellAt(si, c, r);
    if (ok(o) && (pages[o] & 7u) != M_AIR) {
      let d0 = pages[o + 2u];
      // (its left, right and top sides in turn - not tables indexed by the loop: Intel D3D12 scratch memory, Nov 11)
      // (painted in art pixels: each side's rim on the art pixels along it only - an art pixel thick)
      let lc = !(eon && c > S.c0 && edgeAt(si, c - 1, 3, r4, big).x >= 0.0); let rc = !(eon && c + 1 < S.c0 + S.w && edgeAt(si, c + 1, 0, r4, big).x >= 0.0);
      let tcl = !(eon && edgeAt(si, c, i4, r * 4 - 1, big).x >= 0.0);   // (a line over it: buried)
      if ((!big || sp.x < 1.0 / AN) && lc) { cc = rimOver(cc, (d0 >> 18u) & 3u, -I.lx); } if ((!big || sp.x > 1.0 - 1.0 / AN) && rc) { cc = rimOver(cc, (d0 >> 20u) & 3u, I.lx); } if ((!big || sp.y < 1.0 / AN) && tcl) { cc = rimOver(cc, (d0 >> 22u) & 3u, -I.ly * 0.7); }
    }
  }
  // the grass burnt black along the ground's top (drawScar's rule - the plants' fire): from a ragged height over the top (2 to 5 units) to 2.5 under it
  // black blades and ash (lighter where only scorched), browner for 5 under that - over what's there, in the air too (column word 27: ggScar)
  let SC = col(si, c, 6u).w;
  if (SC > 0.0 && which() == 0u) {
    let lv = floor(SC / 65536.0); let g = LT_Y0 + (SC - lv * 65536.0) * 0.25 * CELL; let y = (Y + K.topPx) / K.sv; let up = 2.0 + 3.0 * gh(c, 7, 31u);
    if (y >= g - up && y < g + 7.5) {
      let deep = y >= g + 2.5; let a = select(select(0.6, 0.88, lv > 1.5), 0.55, deep);
      let k = select(select(vec3f(40.0, 32.0, 22.0), vec3f(26.0, 21.0, 17.0), lv > 1.5), vec3f(52.0, 38.0, 24.0), deep) / 255.0;
      cc = vec4f(k * a + cc.xyz * (1.0 - a), a + cc.w * (1.0 - a));
    }
  }
  if (cc.w <= 0.0) { discard; }
  return cc;
}
// ---- THE FIELD BEHIND AND THE BACK WALL (paintLandBack0): a column's numbers (ggBackCols), each cell worked out here ----
fn bcol(si: u32, c: i32, v: u32) -> vec4f { return bcols[STRATA + (si * 64u + u32(c - slots[si].c0)) * BCV + v]; }
// (meadowNoise / ltSmooth: a smooth value noise on the cell lattice)
fn vnoise(u: f32, v: f32, s: u32) -> f32 {
  let i = i32(floor(u)); let j = i32(floor(v)); let fu = u - floor(u); let fv = v - floor(v); let su = fu * fu * (3.0 - 2.0 * fu); let sv = fv * fv * (3.0 - 2.0 * fv);
  return mix(mix(gh(i, j, s), gh(i + 1, j, s), su), mix(gh(i, j + 1, s), gh(i + 1, j + 1, s), su), sv);
}
// (ltTC) where two terrain types meet, which side's field a cell is: 0 the left type's, 1 the right's (the seam wandering with depth)
fn tcSide(si: u32, c: i32, r: i32) -> u32 {
  let C0 = col(si, c, 0u); let b = C0.w; let dep = clamp((LT_Y0 + f32(r) * CELL - C0.z) / LT_MIX_D, 0.0, 1.0); let reach = (LT_MIX + (LT_MIX_DEEP - LT_MIX) * dep) / CELL;
  let off = ((0.6 * vnoise(f32(c) / 7.0, f32(r) / 5.0, 31u) + 0.25 * vnoise(f32(c) / 2.5, f32(r) / 2.0, 32u) + 0.15 * gh(c, r, 33u)) * 2.0 - 1.0) * reach;
  return select(1u, 0u, f32(c) + 0.5 < b + off);
}
// (fieldCol) a cell of the field standing on a ground at row sr, FH cells tall
fn fieldCol(si: u32, c: i32, r: i32, sr: f32, FH: f32, ds0: bool, pb: f32) -> vec3f {
  let fl = u32(bcol(si, c, 1u).x); var ds = ds0;
  if (col(si, c, 0u).w >= 0.0) { ds = select((fl & 64u) != 0u, (fl & 128u) != 0u, tcSide(si, c, r) == 1u); }
  let h = gh(c, r, 34u); let f = (f32(r) - (sr - FH)) / max(1.0, FH);
  var cc: vec3f;
  if (!ds) {
    let t = 0.62 * vnoise(f32(c) / 11.0, f32(r) / 4.0, 35u) + 0.38 * h; let streak = ((c * 7 + (r >> 1u)) % 5 == 0) && gh(c, 0, 36u) < 0.6;
    cc = select(select(select(MEADOW[3], MEADOW[2], t < 0.84), MEADOW[1], t < 0.55), MEADOW[0], t < 0.28);
    if (streak && t < 0.84) { cc = select(MEADOW[1], MEADOW[0], t < 0.55); }
    if (f > 0.86 && h < 0.5) { cc = MEADOW[0]; }
  } else {
    let t = 0.85 * vnoise(f32(c) * 0.6 / 11.0, f32(r) * 0.8 / 4.0, 35u) + 0.15 * h;
    cc = select(select(DFIELD[0], DFIELD[2], t > 0.78), DFIELD[1], t < 0.3); if (h < 0.025) { cc = DFIELD[3]; }
  }
  if (f < 0.12) { cc = mix(cc, vec3f(199.0, 208.0, 217.0), 0.25); } else if (h > 1.0 - pb) { cc = select(vec3f(176.0, 172.0, 160.0), vec3f(192.0, 122.0, 80.0), ds); }
  return select(cc * vec3f(0.7, 0.74, 0.8) + vec3f(0.0, 0.0, 6.0), cc * vec3f(0.76, 0.74, 0.76) + vec3f(0.0, 0.0, 6.0), ds);   // (darker and cooler than the ground in front)
}
// a blade or drift standing up out of a field's top, b cells over it
fn tipCol(ds: bool, b: i32) -> vec3f { let tc = select(select(MEADOW[2], MEADOW[3], b > 1), DFIELD[0], ds); return tc * vec3f(0.7, 0.74, 0.8) + vec3f(0.0, 0.0, 6.0); }
fn inGap(si: u32, c: i32, r: i32) -> bool { let G = bcol(si, c, 6u); let y = LT_Y0 + f32(r) * CELL; return (y >= G.x && y < G.y) || (y >= G.z && y < G.w); }
// the cell's colour behind the ground, or none (x < 0)
fn backCell(si: u32, c: i32, r: i32) -> vec3f {
  let S = slots[si]; if (r >= S.rB) { return vec3f(-1.0); }
  let B0 = bcol(si, c, 0u); let B1 = bcol(si, c, 1u); let fl = u32(B1.x); if ((fl & 1u) == 0u && (fl & 2u) == 0u && B0.y == 0.0 && B0.x == 0.0) { return vec3f(-1.0); }
  let sr = B0.x; let sw = B0.y; let FH = B0.z; let r0 = i32(B0.w); let ds0 = (fl & 4u) != 0u; let pb = bcol(si, c, 2u).w;
  var out = vec3f(-1.0);
  if (r < r0) { if (FH > 1.5 && r >= r0 - i32(B1.z)) { out = tipCol(ds0, r0 - r); } }
  else if (!(f32(r) >= sw && inGap(si, c, r))) {
    if (f32(r) < sr) { if (FH > 0.5) { out = fieldCol(si, c, r, sr, FH, ds0, pb); } }
    else if (f32(r) < sw) {
      // (bowlCol) a lake's bowl: its far slopes in its bed's colour, lines running round it, darker and cooler further up, the far bank's field dithered in
      let h = gh(c, r, 37u); let D = max(1.0, sw - sr); let u = clamp((f32(r) + 0.5 - sr) / D, 0.0, 1.0); let x = f32(c) * CELL;
      let g = select(select(bcol(si, c, 4u).xyz, bcol(si, c, 5u).xyz, h > 0.8), bcol(si, c, 3u).xyz, h < 0.2);
      let ln = u * 8.0 + 0.35 * sin(x / 37.0 + bcol(si, c, 3u).w) * cos(x / 13.0 + bcol(si, c, 4u).w); let fr = ln - floor(ln);
      let far = 1.0 - u; let lt = (0.5 + 0.46 * u) * select(select(1.0, 1.12, fr > 0.86), 0.74, fr < 0.14) * (0.96 + 0.08 * h);
      out = g * lt + vec3f(2.0, 8.0, 22.0) * far;
      let th = (f32(((r & 3) * 4 + (c & 3)) * 7 % 16) + 0.5) / 16.0; let v = u / 0.22;
      if (FH > 0.5 && v < 1.0 && th > v * v) { out = fieldCol(si, c, max(0, i32(floor(sr)) - 1), sr, FH, ds0, pb); }
    } else {
      // the back wall: the caves' tile (landBackArt), an art pixel 2 world units, in the column's cave colour, in shadow
      if (arrayLength(&art) > 4u && art[0] > 0u) {
        let AW = i32(art[0]); let AH = i32(art[1]); let X = (f32(c) + 0.5) * CELL; let Y = LT_Y0 + (f32(r) + 0.5) * CELL;
        let px = ((i32(floor(X / 2.0)) % AW) + AW) % AW; let py = ((i32(floor(Y / 2.0)) % AH) + AH) % AH; let t = art[4u + u32(py * AW + px)];
        let tc = vec3f(f32(t & 255u), f32((t >> 8u) & 255u), f32((t >> 16u) & 255u));
        if ((fl & 32u) != 0u) { let L = dot(tc, vec3f(0.3, 0.45, 0.25)); out = min(vec3f(255.0), bcol(si, c, 2u).xyz * L * 1.4); } else { out = min(vec3f(255.0), tc * 1.4); }
      } else { out = vec3f(36.0, 30.0, 28.0); }
    }
  }
  // the ground under an overhang: its own field, in the open air there (fieldLines)
  if ((fl & 1u) != 0u && inGap(si, c, r)) {
    let FLs = bcol(si, c, 7u);
    for (var n = 0; n < 2; n++) {
      let srl = select(FLs.z, FLs.x, n == 0); let FHl = select(FLs.w, FLs.y, n == 0); if (srl > 1e8) { continue; }
      let rl0 = max(S.rT, i32(floor(srl - FHl)));
      if (r >= rl0 && f32(r) < srl) { out = fieldCol(si, c, r, srl, FHl, ds0, pb); }
      else if (FHl > 1.5 && r < rl0 && r >= rl0 - i32(B1.z)) { out = tipCol(ds0, rl0 - r); }
    }
  }
  if (out.x < 0.0) { return out; }
  // (backTint) in the column's biome's colours (ICE, SWAMP, VOLCANIC), MOUNTAIN's grey
  let b = u32(B1.y);
  if (b != 0u) { return bioTint(b, out, M_GRASS, select(4.0, 0.0, b == 1u), false, gh(c, r, 38u), f32(c) * CELL, 0u, 1.0); }
  if ((fl & 8u) != 0u) { let L = dot(out, vec3f(0.3, 0.59, 0.11)) * 0.85; return vec3f(L * 0.95, L * 0.97, L); }
  return out;
}
// the field behind and the back wall drawn (landBackDraw): the wall in the ground's light, the field over the land's line in its deck's atmosphere (I.p1:
// its haze, p2 p3 lx its colour); I.p0 1: only the wall under the land's line where a field's things stood (landBackCover)
@fragment fn fsBack(fi: VO) -> @location(0) vec4f {
  let I = instOf(fi.ii); let si = I.si; let S = slots[si]; let K = cam();
  if (fi.p.x < K.vx0 || fi.p.x >= K.vx1) { discard; }
  let X = fi.p.x - K.ox; let Y = (K.th - fi.p.y) - K.oy;
  if (X < I.X0 || X >= I.X1 || Y >= I.YB) { discard; }
  let w = S.w; let q = clamp(i32(floor((X - I.X0) / (I.X1 - I.X0) * f32(w))), 0, w - 1); let c = S.c0 + q;
  let rr = (Y - I.YT) / (I.YB - I.YT) * f32(S.rB - S.rT + 4) + f32(S.rT - 4); let r = i32(floor(rr));
  let B1 = bcol(si, c, 1u); let over = rr < B1.w;
  if (I.p0 > 0.5 && (over || (u32(B1.x) & 16u) == 0u)) { discard; }
  let cc = backCell(si, c, r); if (cc.x < 0.0) { discard; }
  let v = clamp(round(cc), vec3f(0.0), vec3f(255.0)) / 255.0;
  if (over && I.p0 < 0.5) { return vec4f(v * FD[0].xyz * (1.0 - I.p1) + vec3f(I.p2, I.p3, I.lx) * I.p1, 1.0); }
  return vec4f(v * FD[0].xyz, 1.0);
}
// ---- THE STONES KNOCKED LOOSE, FALLING (stoneSprite / drawLooseStones): each its cells on a grid of its own round where it is now - from a cell
// left of and over its box -, coloured by the ground's stone rule from its outline (the processor's, stonePoly), in the hour's light. The draw's
// stones (binding 1) are only these; an instance: si its place among them, X0 X1 YT YB its box (the view's pixels), p0 1 in the desert's
// colours (ltPal), p1 its seed (its id) ----
@vertex fn vsLoose(@builtin(vertex_index) vi: u32, @builtin(instance_index) ii: u32) -> VO {
  let I = instOf(ii); let K = cam(); let u = f32(vi & 1u); let v = f32((vi >> 1u) & 1u);
  let X = mix(I.X0, I.X1, u) + K.ox; let Y = mix(I.YT, I.YB, v) + K.oy;
  var o: VO; o.p = vec4f(X / K.tw * 2.0 - 1.0, Y / K.th * 2.0 - 1.0, 0.0, 1.0); o.ii = ii;
  return o;
}
@fragment fn fsLoose(fi: VO) -> @location(0) vec4f {
  let I = instOf(fi.ii); let K = cam(); let b = I.si * SW; let o = stones[b];
  if (fi.p.x < K.vx0 || fi.p.x >= K.vx1) { discard; }
  let wx = (fi.p.x - K.ox + K.camPx) / K.sv; let wy = ((K.th - fi.p.y) - K.oy + K.topPx) / K.sv;   // (the pixel in the world)
  let gx = o.x - o.z - CELL; let gy = o.y - o.w - CELL; let i = floor((wx - gx) / ACELL); let j = floor((wy - gy) / ACELL);   // (its own grid of the world's art pixels)
  let dx = (gx + (i + 0.5) * ACELL - o.x) / o.z; let dy = (gy + (j + 0.5) * ACELL - o.y) / o.w;
  if (dx * dx + dy * dy > 1.0 || !stoneHit(b, dx, dy).ok) { discard; }
  let St = stoneLook(b, dx, dy, gh(i32(i), i32(j), u32(I.p1))); let k0 = stones[b + 2u].x; let des = I.p0 > 0.5;
  var cc: vec3f;
  if (stones[b + 1u].y > 0.5) {
    cc = select(select(select(pal(M_ROCK, des, 4u), select(pal(M_ROCK, des, 1u), pal(M_ROCK, des, 0u), k0 < 0.5), St.t > -0.25), pal(M_ROCK, des, 5u), St.t > 0.22), pal(M_ROCK, des, 2u), St.t > 0.6);
    if (St.e < 0.85 * ACELL / CELL && St.t < 0.25) { cc = pal(M_ROCK, des, 4u); }
  } else {
    cc = select(select(select(pal(M_DIRT, des, 6u), select(select(pal(M_DIRT, des, 0u), pal(M_DIRT, des, 2u), k0 > 0.66), pal(M_DIRT, des, 1u), k0 < 0.33), St.t > -0.3), pal(M_DIRT, des, 4u), St.t > 0.25), pal(M_DIRT, des, 5u), St.t > 0.62 && o.z > 6.0);
    if (St.e < 0.85 * ACELL / CELL && St.t < 0.25) { cc = pal(M_DIRT, des, 6u); }
  }
  return vec4f(lit(stint(cc, b)), 1.0);
}
