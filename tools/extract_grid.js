// Extractor de grilla — threshold HSV por píxel
// Fondo purpura: H≈291°, S≈94%. Sprites: desaturados/oscuros.
// Regla: H en rango purpura AND S alta AND V sobre umbral → transparente
// node tools/extract_grid.js cars | motos

const { Jimp } = require('jimp');
const path = require('path');
const fs   = require('fs');

const CONFIGS = {
  cars: {
    src:        'c:/Users/Titin/Downloads/ChatGPT Image 3 ago 2026, 03_09_55 a.m..png',
    dest:       'assets/sprites/cars/frames',
    cols: 3, rows: 3,
    // Elimina fondo Y sombras (autos no las necesitan)
    vMinBg:     0.48,  // quita todo purpura con V > 48% de 100
  },
  motos: {
    src:        'c:/Users/Titin/Downloads/ChatGPT Image 3 ago 2026, 03_19_09 a.m..png',
    dest:       'assets/sprites/motorcycles/frames',
    cols: 3, rows: 3,
    // Solo elimina el purpura brillante; sombras oscuras (V≈38-66%) se conservan
    vMinBg:     0.74,
  },
};

function rgbToHsv(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
  let h = 0;
  if (d > 0) {
    if      (max === r) h = ((g - b) / d + 6) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else                h = (r - g) / d + 4;
    h *= 60;
  }
  return [h, max === 0 ? 0 : d / max, max]; // h°, s[0-1], v[0-1]
}

function hueDist(a, b) {
  const d = Math.abs(a - b) % 360;
  return d > 180 ? 360 - d : d;
}

async function extract(cfg) {
  fs.mkdirSync(cfg.dest, { recursive: true });

  const src  = await Jimp.read(cfg.src);
  const W    = src.bitmap.width;
  const H    = src.bitmap.height;
  const data = src.bitmap.data;

  // Muestrear color de fondo desde las 4 esquinas
  let bgH = 0, bgS = 0, bgV = 0;
  for (const [x, y] of [[2,2],[W-3,2],[2,H-3],[W-3,H-3]]) {
    const [h, s, v] = rgbToHsv(data[(y*W+x)*4], data[(y*W+x)*4+1], data[(y*W+x)*4+2]);
    bgH += h; bgS += s; bgV += v;
  }
  bgH /= 4; bgS /= 4; bgV /= 4;
  console.log(`BG HSV: H=${bgH.toFixed(0)}° S=${(bgS*100).toFixed(0)}% V=${(bgV*100).toFixed(0)}%`);

  // Tolerancias de matiz y saturación para detectar el fondo
  const DH = 30;      // tolerancia de hue en grados
  const DS = 0.22;    // tolerancia de saturación

  function isBg(r, g, b) {
    const [h, s, v] = rgbToHsv(r, g, b);
    return hueDist(h, bgH) < DH && Math.abs(s - bgS) < DS && v > cfg.vMinBg;
  }

  // Máscara: 1=sprite, 0=fondo
  const mask = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) {
    mask[i] = isBg(data[i*4], data[i*4+1], data[i*4+2]) ? 0 : 1;
  }

  // Densidad para detectar separadores de grilla
  const colDens = new Float32Array(W);
  const rowDens = new Float32Array(H);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++)
      if (mask[y*W+x]) { colDens[x]++; rowDens[y]++; }

  function findSeparators(dens, total, count) {
    const K = 8, sm = new Float32Array(total);
    const margin = Math.round(total * 0.05);
    for (let i = K; i < total-K; i++) {
      let s = 0;
      for (let k = -K; k <= K; k++) s += dens[i+k];
      sm[i] = s / (2*K+1);
    }
    const peak = Math.max(...sm);
    const thr  = peak * 0.03;
    const segs = [];
    let inGap = false, gs = 0;
    for (let i = margin; i < total-margin; i++) {
      if (!inGap && sm[i] <= thr) { inGap = true; gs = i; }
      else if (inGap && sm[i] > thr) { segs.push(Math.round((gs+i)/2)); inGap = false; }
    }
    if (inGap) segs.push(Math.round((gs + total) / 2));

    if (segs.length === count) return segs;
    if (segs.length > count) {
      const step = total / (count + 1);
      const chosen = new Set();
      for (let c = 1; c <= count; c++) {
        const target = step * c;
        let best = segs[0], bd = Infinity;
        for (const s of segs) { const dd = Math.abs(s - target); if (dd < bd) { bd = dd; best = s; } }
        chosen.add(best);
      }
      return [...chosen].sort((a,b) => a-b);
    }
    // fallback: equidistantes
    return Array.from({length: count}, (_, i) => Math.round(total * (i+1) / (count+1)));
  }

  const colSeps = findSeparators(colDens, W, cfg.cols - 1);
  const rowSeps = findSeparators(rowDens, H, cfg.rows - 1);
  console.log('Col seps:', colSeps, '| Row seps:', rowSeps);

  const colB = [0, ...colSeps, W];
  const rowB = [0, ...rowSeps, H];

  let idx = 0;
  for (let row = 0; row < cfg.rows; row++) {
    for (let col = 0; col < cfg.cols; col++) {
      const x0=colB[col], x1=colB[col+1], y0=rowB[row], y1=rowB[row+1];
      const cw=x1-x0, ch=y1-y0;

      // Bounding box del contenido
      let minX=cw, maxX=0, minY=ch, maxY=0;
      for (let y=0; y<ch; y++) for (let x=0; x<cw; x++) {
        if (mask[(y0+y)*W+(x0+x)]) {
          if (x<minX) minX=x; if (x>maxX) maxX=x;
          if (y<minY) minY=y; if (y>maxY) maxY=y;
        }
      }
      if (maxX < minX) { console.log(`frame_${idx}: vacío`); idx++; continue; }

      const fw=maxX-minX+1, fh=maxY-minY+1;
      const dst = new Jimp({ width: fw, height: fh, color: 0x00000000 });
      const dstData = dst.bitmap.data;

      for (let y=0; y<fh; y++) for (let x=0; x<fw; x++) {
        const gi = (y0+minY+y)*W + (x0+minX+x);
        if (!mask[gi]) continue;
        const di = (y*fw+x)*4, si = gi*4;
        dstData[di]   = data[si];
        dstData[di+1] = data[si+1];
        dstData[di+2] = data[si+2];
        dstData[di+3] = 255;
      }

      const name = `frame_${String(idx).padStart(2,'0')}.png`;
      await dst.write(path.join(cfg.dest, name));
      console.log(`${name}: ${fw}x${fh}`);
      idx++;
    }
  }
  console.log('Listo →', cfg.dest);
}

const mode = process.argv[2] || 'cars';
if (!CONFIGS[mode]) { console.error('Uso: node extract_grid.js cars|motos'); process.exit(1); }
extract(CONFIGS[mode]).catch(console.error);
