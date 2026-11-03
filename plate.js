/* Procedural blue-hour plate: rustic house set back in a clearing.
   mk(w,h) must return a canvas. Returns { plate, mask, horizon, win:{x,y} } (normalised). */
function mulberry(a) {
  return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
}
function buildScene(mk) {
  const TAU = Math.PI * 2;
  const PW = 2400, PH = 1350, HZ = Math.round(PH * 0.63);
  const R = mulberry(11);
  const rr = (a, b) => a + R() * (b - a);
  const lerp = (a, b, t) => a + (b - a) * t;
  const fbm = (x, s) => Math.sin(x + s) * .5 + Math.sin(x * 2.3 + s * 1.7) * .3 + Math.sin(x * 5.1 + s * 2.9) * .2;
  const sstep = (a, b, v) => { const t = Math.max(0, Math.min(1, (v - a) / (b - a))); return t * t * (3 - 2 * t); };

  const plate = mk(PW, PH), x = plate.getContext('2d');
  let X = x;   // drawing target used by ridge/tree helpers (swapped while drawing a softened layer)
  // draw fn into a scratch layer, then down/up-sample it onto `dst` to fake lens defocus
  const soft = (dst, scale, fn) => {
    const t = mk(PW, PH), prev = X; X = t.getContext('2d'); fn(); X = prev;
    const sm = mk(Math.round(PW * scale), Math.round(PH * scale)), sc = sm.getContext('2d');
    sc.imageSmoothingEnabled = true; sc.imageSmoothingQuality = 'high';
    sc.drawImage(t, 0, 0, sm.width, sm.height);
    dst.imageSmoothingEnabled = true; dst.imageSmoothingQuality = 'high';
    dst.drawImage(sm, 0, 0, PW, PH);
  };
  const hx = PW * .6, gY = HZ + 26;

  /* ---- sky ---- */
  let g = x.createLinearGradient(0, 0, 0, HZ + 30);
  g.addColorStop(0, '#050a1e'); g.addColorStop(.28, '#0c1840'); g.addColorStop(.52, '#1d386c');
  g.addColorStop(.78, '#46669a'); g.addColorStop(.93, '#8f8aa0'); g.addColorStop(1, '#c4978c');
  x.fillStyle = g; x.fillRect(0, 0, PW, PH);

  // afterglow
  x.save(); x.translate(PW * .18, HZ + 10); x.scale(2.6, 1);
  g = x.createRadialGradient(0, 0, 0, 0, 0, 380);
  g.addColorStop(0, 'rgba(255,170,120,.62)'); g.addColorStop(.5, 'rgba(235,125,120,.22)'); g.addColorStop(1, 'rgba(200,100,120,0)');
  x.fillStyle = g; x.fillRect(-1000, -600, 2000, 1200); x.restore();

  // stars
  for (let i = 0; i < 300; i++) {
    const sx = rr(0, PW), sy = rr(0, HZ * .62), a = rr(.15, .85) * (1 - sy / (HZ * .7));
    x.fillStyle = `rgba(225,232,255,${a})`;
    const r = R() < .06 ? 1.6 : rr(.5, 1.1);
    x.beginPath(); x.arc(sx, sy, r, 0, TAU); x.fill();
  }
  // low cloud bank with rose-lit undersides near the horizon
  for (let i = 0; i < 14; i++) {
    const cx = rr(0, PW), cy = HZ - rr(40, 230), w = rr(260, 700), h = rr(18, 46);
    x.save(); x.translate(cx, cy); x.rotate(rr(-.03, .03));
    g = x.createLinearGradient(0, -h, 0, h);
    g.addColorStop(0, 'rgba(70,85,135,.0)'); g.addColorStop(.45, 'rgba(70,85,135,.28)');
    g.addColorStop(.8, `rgba(${200 - cy / 12 | 0},120,130,.22)`); g.addColorStop(1, 'rgba(200,120,120,0)');
    x.fillStyle = g; x.scale(w / 100, 1);
    x.beginPath(); x.ellipse(0, 0, 100, h, 0, 0, TAU); x.fill(); x.restore();
  }
  // thin high cloud streaks
  for (let i = 0; i < 9; i++) {
    x.save(); x.translate(rr(0, PW), rr(HZ * .25, HZ * .8)); x.rotate(rr(-.06, .02)); x.scale(rr(3, 7), 1);
    g = x.createRadialGradient(0, 0, 0, 0, 0, 70);
    g.addColorStop(0, 'rgba(150,165,205,.13)'); g.addColorStop(1, 'rgba(150,165,205,0)');
    x.fillStyle = g; x.fillRect(-200, -80, 400, 160); x.restore();
  }

  /* ---- distant ridges ---- */
  const ridge = (base, amp, seed, fr, col) => {
    X.fillStyle = col; X.beginPath(); X.moveTo(0, PH);
    for (let px = 0; px <= PW; px += 6) X.lineTo(px, base - (fbm(px * fr, seed) + 1) / 2 * amp);
    X.lineTo(PW, PH); X.closePath(); X.fill();
  };
  soft(x, .22, () => { ridge(HZ - 32, 74, 2.2, .0019, '#42597f'); });
  soft(x, .3, () => { ridge(HZ - 12, 52, 5.1, .0027, '#30476d'); });

  /* ---- trees ---- */
  function tree(px, py, h, col, type) {
    X.fillStyle = col;
    if (type === 0) {
      const tiers = 7;
      for (let i = 0; i < tiers; i++) {
        const t = i / tiers, ty = py - h + h * t * .92, w = h * (.07 + .17 * t) * (.9 + R() * .2);
        X.beginPath(); X.moveTo(px, ty - h * .02);
        X.lineTo(px + w, ty + h * .17); X.lineTo(px + w * .55, ty + h * .14);
        X.lineTo(px - w * .55, ty + h * .14); X.lineTo(px - w, ty + h * .17);
        X.closePath(); X.fill();
      }
      X.fillRect(px - h * .015, py - h * .06, h * .03, h * .07);
    } else {
      X.fillRect(px - h * .015, py - h * .32, h * .03, h * .34);
      for (let i = 0; i < 10; i++) {
        const a = R() * TAU, r = R() * h * .2;
        X.beginPath(); X.arc(px + Math.cos(a) * r * 1.1, py - h * .62 + Math.sin(a) * r * .8, h * (.14 + R() * .1), 0, TAU); X.fill();
      }
    }
  }
  const row = (yBase, h0, h1, col, step, skipMid) => {
    for (let px = -40; px < PW + 40; px += rr(step * .6, step * 1.4)) {
      const d = Math.abs(px - hx) / (PW * .5);
      if (skipMid && d < skipMid) continue;
      const k = .45 + .9 * sstep(.05, .9, d);
      tree(px, yBase + rr(-6, 6), rr(h0, h1) * k, col, R() < .62 ? 0 : 1);
    }
  };
  soft(x, .34, () => row(HZ + 4, 60, 110, '#16264a', 22));
  soft(x, .6, () => row(HZ + 12, 90, 170, '#0e182f', 30));

  /* ---- meadow ---- */
  g = x.createLinearGradient(0, HZ, 0, PH);
  g.addColorStop(0, '#2b3c54'); g.addColorStop(.08, '#1d2c41'); g.addColorStop(.35, '#101b29'); g.addColorStop(1, '#04080e');
  x.fillStyle = g; x.beginPath(); x.moveTo(0, PH);
  for (let px = 0; px <= PW; px += 8) x.lineTo(px, HZ + 10 - fbm(px * .004, 3) * 6);
  x.lineTo(PW, PH); x.closePath(); x.fill();

  // grass texture, batched by depth bucket
  const NB = 6;
  const cols = ['#3d5872', '#33495f', '#283d51', '#1d2f40', '#15232f', '#0e1923'];
  x.globalAlpha = .55; x.lineCap = 'round';
  for (let b = 0; b < NB; b++) {
    x.strokeStyle = cols[b]; x.lineWidth = .8 + b * .4; x.beginPath();
    for (let i = 0; i < 2400; i++) {
      // depth within this bucket, concentrated toward the horizon overall
      const t = (b + R()) / NB, y = HZ + 12 + (PH - HZ - 12) * t, px = rr(-20, PW + 20);
      if (R() > 1.15 - t * .9) continue;
      const L = 3 + t * 40, lean = rr(-.3, .3) * L;
      x.moveTo(px, y); x.quadraticCurveTo(px + lean * .5, y - L * .6, px + lean, y - L);
    }
    x.stroke();
  }
  x.globalAlpha = 1;

  // large-scale tonal patches and low mist so the field isn't uniform
  for (let i = 0; i < 70; i++) {
    const cx = rr(0, PW), t = Math.pow(R(), 1.3), cy = HZ + 20 + (PH - HZ - 20) * t, r = rr(120, 380) * (.4 + t);
    const light = R() < .5;
    g = x.createRadialGradient(cx, cy, 0, cx, cy, r);
    g.addColorStop(0, light ? 'rgba(70,95,125,.07)' : 'rgba(0,4,10,.16)'); g.addColorStop(1, 'rgba(0,0,0,0)');
    x.save(); x.translate(0, cy); x.scale(1, .32); x.translate(0, -cy);
    x.fillStyle = g; x.fillRect(cx - r, cy - r, r * 2, r * 2); x.restore();
  }
  for (const [yy, a] of [[HZ + 36, .12], [HZ + 120, .07], [HZ + 260, .035]]) {
    g = x.createLinearGradient(0, yy - 60, 0, yy + 60);
    g.addColorStop(0, 'rgba(120,145,190,0)'); g.addColorStop(.5, `rgba(120,145,190,${a})`); g.addColorStop(1, 'rgba(120,145,190,0)');
    x.fillStyle = g; x.fillRect(0, yy - 60, PW, 120);
  }
  // horizon haze
  g = x.createLinearGradient(0, HZ - 90, 0, HZ + 90);
  g.addColorStop(0, 'rgba(120,145,190,0)'); g.addColorStop(.5, 'rgba(130,150,190,.22)'); g.addColorStop(1, 'rgba(120,145,190,0)');
  x.fillStyle = g; x.fillRect(0, HZ - 90, PW, 180);

  // dirt track catching sky light, leading to the house
  g = x.createLinearGradient(0, gY, 0, PH);
  g.addColorStop(0, 'rgba(88,112,140,.16)'); g.addColorStop(.5, 'rgba(70,92,120,.06)'); g.addColorStop(1, 'rgba(60,80,104,0)');
  x.fillStyle = g; x.beginPath();
  x.moveTo(hx - 14, gY + 2); x.lineTo(hx + 14, gY + 2);
  x.quadraticCurveTo(hx + 60, HZ + 260, hx + 230, PH); x.lineTo(hx - 120, PH);
  x.quadraticCurveTo(hx - 30, HZ + 260, hx - 14, gY + 2); x.closePath(); x.fill();

  /* ---- house & shed ---- */
  const hw = 230, hh = 100, bx = hx - hw / 2, by = gY - hh;
  // shed
  x.fillStyle = '#0d121d'; x.fillRect(bx - 330, gY - 62, 150, 62);
  x.fillStyle = '#080b13'; x.beginPath(); x.moveTo(bx - 342, gY - 61); x.lineTo(bx - 255, gY - 108); x.lineTo(bx - 168, gY - 61); x.closePath(); x.fill();
  // body
  x.fillStyle = '#151b29'; x.fillRect(bx, by, hw, hh);
  x.fillStyle = 'rgba(0,0,0,.16)';
  for (let yy = by + 6; yy < gY; yy += 7) x.fillRect(bx, yy, hw, 1);
  // porch
  x.fillStyle = '#0c111b'; x.fillRect(bx + hw, by + 38, 70, 5);
  x.fillRect(bx + hw + 2, by + 42, 4, hh - 42); x.fillRect(bx + hw + 62, by + 42, 4, hh - 42);
  x.fillStyle = '#10151f'; x.fillRect(bx + hw, gY - 8, 70, 8);
  // roof
  x.fillStyle = '#090d16'; x.beginPath(); x.moveTo(bx - 20, by + 3); x.lineTo(hx, by - 80); x.lineTo(bx + hw + 20, by + 3); x.closePath(); x.fill();
  x.fillRect(hx + 52, by - 76, 22, 52);
  // door
  x.fillStyle = '#0a0e17'; x.fillRect(hx - 12, gY - 52, 24, 52);
  // windows
  const wins = [[bx + 34, by + 34, 26, 34, 1], [bx + hw - 60, by + 34, 26, 34, 1], [hx - 10, by - 48, 20, 24, .75]];
  for (const [wx, wy, w, h, k] of wins) {
    g = x.createLinearGradient(0, wy, 0, wy + h);
    g.addColorStop(0, `rgba(255,226,160,${k})`); g.addColorStop(1, `rgba(255,150,70,${k})`);
    x.fillStyle = g; x.fillRect(wx, wy, w, h);
    x.fillStyle = '#0a0e17'; x.fillRect(wx + w / 2 - 1, wy, 2, h); x.fillRect(wx, wy + h / 2 - 1, w, 2);
  }
  // baked glow
  x.globalCompositeOperation = 'lighter';
  for (const [wx, wy, w, h, k] of wins) {
    g = x.createRadialGradient(wx + w / 2, wy + h / 2, 0, wx + w / 2, wy + h / 2, 90);
    g.addColorStop(0, `rgba(255,160,70,${.5 * k})`); g.addColorStop(.35, `rgba(255,140,60,${.16 * k})`); g.addColorStop(1, 'rgba(255,120,50,0)');
    x.fillStyle = g; x.fillRect(wx - 100, wy - 100, w + 200, h + 200);
  }
  x.save(); x.translate(hx, gY + 12); x.scale(1, .13);
  g = x.createRadialGradient(0, 0, 0, 0, 0, 260);
  g.addColorStop(0, 'rgba(255,150,70,.34)'); g.addColorStop(1, 'rgba(255,130,50,0)');
  x.fillStyle = g; x.fillRect(-300, -300, 600, 600); x.restore();
  x.globalCompositeOperation = 'source-over';
  // smoke
  for (let i = 0; i < 8; i++) {
    const t = i / 8, cx = hx + 63 + t * 70 + fbm(i, 2) * 8, cy = by - 80 - t * 150;
    g = x.createRadialGradient(cx, cy, 0, cx, cy, 10 + t * 34);
    g.addColorStop(0, `rgba(150,165,200,${.1 * (1 - t)})`); g.addColorStop(1, 'rgba(150,165,200,0)');
    x.fillStyle = g; x.fillRect(cx - 60, cy - 60, 120, 120);
  }

  // rail fence running toward the house
  x.strokeStyle = '#0b111b'; x.fillStyle = '#0b111b'; x.lineCap = 'butt';
  const fp = [];
  for (let i = 0; i <= 8; i++) {
    const t = i / 8, px = lerp(PW * .1, bx - 60, Math.pow(t, .9)), py = lerp(PH * .93, gY + 8, t), h = lerp(120, 24, t);
    fp.push({ px, py, h });
  }
  for (let i = 0; i < fp.length; i++) {
    const a = fp[i], w = Math.max(2, a.h * .07);
    x.fillRect(a.px - w / 2, a.py - a.h, w, a.h);
    if (i < fp.length - 1) {
      const b = fp[i + 1];
      for (const k of [.3, .72]) {
        x.lineWidth = Math.max(1.5, (a.h + b.h) * .02);
        x.beginPath(); x.moveTo(a.px, a.py - a.h * k); x.lineTo(b.px, b.py - b.h * k); x.stroke();
      }
    }
  }

  /* ---- foreground mask (trunks, canopy, undergrowth) ---- */
  const mask = mk(PW, PH), m = mask.getContext('2d');
  const trunkEdge = (cx, wb, wt, seed, lean) => {
    const steps = 90, L = [], Rr = [];
    for (let i = 0; i <= steps; i++) {
      const t = i / steps, y = -30 + (PH + 60) * t;
      let w = lerp(wt, wb, Math.pow(t, 1.5));
      w *= 1 + fbm(y * .006, seed) * .12 + (t > .9 ? (t - .9) * 2.2 : 0);          // bulges + root flare
      const mid = cx + Math.sin(t * 2.2 + seed) * lean + fbm(y * .004, seed + 3) * 14;
      L.push([mid - w / 2 + fbm(y * .05, seed) * 2.5, y]); Rr.push([mid + w / 2 + fbm(y * .05, seed + 8) * 2.5, y]);
    }
    return { L, Rr };
  };
  const trunk = (cx, wb, wt, seed, lean) => {
    const { L, Rr } = trunkEdge(cx, wb, wt, seed, lean);
    const path = () => { m.beginPath(); L.forEach(([a, b], i) => i ? m.lineTo(a, b) : m.moveTo(a, b)); for (let i = Rr.length - 1; i >= 0; i--) m.lineTo(Rr[i][0], Rr[i][1]); m.closePath(); };
    // base colour with a lateral gradient (lighter toward the clearing)
    const facing = cx < PW / 2;
    g = m.createLinearGradient(cx - wb / 2, 0, cx + wb / 2, 0);
    g.addColorStop(facing ? 0 : 1, '#04060c'); g.addColorStop(facing ? 1 : 0, '#0d1626');
    m.fillStyle = g; path(); m.fill();
    m.save(); path(); m.clip();
    m.lineCap = 'round';
    for (let i = 0; i < 260; i++) {                                                  // furrowed bark
      const t = R(), y = -30 + (PH + 60) * t, w = lerp(wt, wb, Math.pow(t, 1.5)), px = cx - w * .55 + R() * w * 1.1;
      const len = rr(80, 380), dx = rr(-14, 14);
      m.strokeStyle = R() < .6 ? `rgba(2,4,8,${rr(.3, .7)})` : `rgba(40,58,86,${rr(.08, .22)})`;
      m.lineWidth = rr(1, 4.5);
      m.beginPath(); m.moveTo(px, y); m.bezierCurveTo(px + dx, y + len * .3, px - dx, y + len * .7, px + dx * .5, y + len); m.stroke();
    }
    for (let i = 0; i < 10; i++) {                                                   // moss / lichen smudges catching sky light
      const y = rr(PH * .2, PH * .95), px = cx + rr(-wb * .35, wb * .35);
      g = m.createRadialGradient(px, y, 0, px, y, rr(20, 55));
      g.addColorStop(0, 'rgba(60,90,100,.12)'); g.addColorStop(1, 'rgba(60,90,100,0)');
      m.fillStyle = g; m.fillRect(px - 60, y - 60, 120, 120);
    }
    m.restore();
    m.strokeStyle = 'rgba(95,125,175,.3)'; m.lineWidth = 2.5;                       // cool rim light
    m.beginPath(); (facing ? Rr : L).forEach(([a, b], i) => i ? m.lineTo(a, b) : m.moveTo(a, b)); m.stroke();
    return { L, Rr };
  };
  const t1 = trunk(PW * .05, 210, 130, 1.3, 26);
  trunk(PW * .165, 110, 70, 4.4, 18);
  const t3 = trunk(PW * .94, 190, 112, 7.1, 22);
  trunk(PW * .875, 78, 48, 9.6, 14);

  // limbs grow from the inner face of a trunk, then get soft leaf clusters
  const leaves = mk(PW, PH), lc = leaves.getContext('2d');
  const limb = (x0, y0, x1, y1, w0, bend) => {
    m.strokeStyle = '#05080f'; m.lineCap = 'round';
    const pts = [];
    for (let i = 0; i <= 36; i++) {
      const t = i / 36;
      pts.push([lerp(x0, x1, t) + fbm(t * 6, x0) * 6, lerp(y0, y1, t) - Math.sin(t * Math.PI) * bend + fbm(t * 5, y0) * 5]);
    }
    for (let i = 0; i < 36; i++) {
      m.lineWidth = Math.max(2, w0 * Math.pow(1 - i / 36, 1.2));
      m.beginPath(); m.moveTo(pts[i][0], pts[i][1]); m.lineTo(pts[i + 1][0], pts[i + 1][1]); m.stroke();
    }
    for (let i = 8; i <= 36; i += 1) {                                              // twigs + leaf clumps
      const [px, py] = pts[i];
      for (let k = 0; k < 16; k++) {
        lc.save(); lc.translate(px + rr(-46, 46), py + rr(-34, 40)); lc.rotate(rr(-.9, .9));
        lc.fillStyle = R() < .12 ? '#0b1626' : '#04070d';
        lc.beginPath(); lc.ellipse(0, 0, rr(5, 17), rr(2.5, 7), 0, 0, TAU); lc.fill(); lc.restore();
      }
    }
  };
  const e1 = t1.Rr[Math.round(90 * .2)], e1b = t1.Rr[Math.round(90 * .36)];
  const e3 = t3.L[Math.round(90 * .16)], e3b = t3.L[Math.round(90 * .3)];
  limb(e1[0] - 10, e1[1], PW * .36, PH * .1, 30, 70);
  limb(e1b[0] - 10, e1b[1], PW * .27, PH * .31, 18, 40);
  limb(e3[0] + 10, e3[1], PW * .64, PH * .07, 28, 70);
  limb(e3b[0] + 10, e3b[1], PW * .73, PH * .28, 16, 40);

  // canopy clusters in the top corners (drawn to `leaves`, defocused below)
  for (let i = 0; i < 3600; i++) {
    const left = R() < .5, u = Math.pow(R(), 1.4), cx = left ? u * PW * .36 : PW - u * PW * .36;
    const cy = Math.pow(R(), 2.2) * PH * .2 * (1 - u * .55) + 2;
    lc.save(); lc.translate(cx, cy); lc.rotate(rr(-.6, .6));
    lc.fillStyle = R() < .1 ? '#0b1626' : '#04070d';
    lc.beginPath(); lc.ellipse(0, 0, rr(5, 19), rr(2.5, 8), 0, 0, TAU); lc.fill(); lc.restore();
  }
  {
    const sm = mk(Math.round(PW * .42), Math.round(PH * .42)), sc = sm.getContext('2d');
    sc.imageSmoothingEnabled = true; sc.imageSmoothingQuality = 'high';
    sc.drawImage(leaves, 0, 0, sm.width, sm.height);
    m.imageSmoothingEnabled = true; m.imageSmoothingQuality = 'high';
    m.drawImage(sm, 0, 0, PW, PH);
    m.globalAlpha = .55; m.drawImage(leaves, 0, 0); m.globalAlpha = 1;               // keep a little crisp detail
  }

  // undergrowth along the bottom edge (near the lens, so defocused)
  {
    const gr = mk(PW, PH), gc = gr.getContext('2d');
    gc.fillStyle = '#03050a';
    for (let i = 0; i < 900; i++) {
      const u = R(), edge = Math.pow(R(), 1.7), px = u < .5 ? edge * PW * .45 : PW - edge * PW * .45;
      const h = rr(30, 90) + (1 - edge) * rr(0, 190), lean = rr(-60, 60), w = rr(3, 9);
      gc.beginPath(); gc.moveTo(px - w, PH + 4);
      gc.quadraticCurveTo(px + lean * .4, PH - h * .6, px + lean, PH - h);
      gc.quadraticCurveTo(px + lean * .4 + w, PH - h * .6, px + w, PH + 4); gc.fill();
    }
    for (const [cx, cy, rx, ry] of [[PW * .02, PH, 330, 150], [PW * .98, PH, 300, 130], [PW * .2, PH + 20, 240, 70], [PW * .8, PH + 20, 220, 60]]) {
      gc.beginPath(); gc.ellipse(cx, cy, rx, ry, 0, 0, TAU); gc.fill();
    }
    const sm = mk(Math.round(PW * .5), Math.round(PH * .5)), sc = sm.getContext('2d');
    sc.imageSmoothingEnabled = true; sc.imageSmoothingQuality = 'high';
    sc.drawImage(gr, 0, 0, sm.width, sm.height);
    m.drawImage(sm, 0, 0, PW, PH);
    m.globalAlpha = .5; m.drawImage(gr, 0, 0); m.globalAlpha = 1;
  }

  /* ---- finishing: dither / sensor grain on the plate ---- */
  {
    const id = x.getImageData(0, 0, PW, PH), d = id.data;
    for (let i = 0; i < d.length; i += 4) {
      const n = (R() - .5) * 9, lum = (d[i] + d[i + 1] + d[i + 2]) / 765, k = .5 + (1 - lum) * .7;   // stronger in shadows
      d[i] += n * k; d[i + 1] += n * k; d[i + 2] += n * k * 1.1;
    }
    x.putImageData(id, 0, 0);
  }

  return { plate, mask, horizon: HZ / PH, win: { x: hx / PW, y: (by + 50) / PH } };
}
if (typeof module !== 'undefined') module.exports = { buildScene };
