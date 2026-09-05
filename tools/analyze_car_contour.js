// Traza el borde superior de cada auto PNG y genera datos GDScript para
// ConcavePolygonShape2D. Muestra en pantalla los valores por auto.
// Uso: node tools/analyze_car_contour.js [sprite_dir]

const { Jimp } = require('jimp');
const path = require('path');
const fs   = require('fs');

const STEP      = 16;    // muestreo cada N px de canvas (→ ~4.5px en juego a escala 0.2782)
const ALPHA_MIN = 40;    // alpha mínimo para considerar píxel del auto
const SMOOTH_R  = 8;     // radio de suavizado (±px en el array de muestras)

async function getContour(img) {
  const { data, width: W, height: H } = img.bitmap;

  // Topmost opaque pixel per column
  const topRow = new Int32Array(W).fill(H); // H = no pixel
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (topRow[x] === H && data[(y * W + x) * 4 + 3] >= ALPHA_MIN) {
        topRow[x] = y;
      }
    }
  }

  // Sample every STEP columns; height_from_bottom = H - topRow[x]
  const samples = [];
  for (let x = 0; x < W; x += STEP) {
    // tomar el mínimo topRow en la ventana [x, x+STEP)
    let minTop = H;
    for (let dx = 0; dx < STEP && x + dx < W; dx++) {
      if (topRow[x + dx] < minTop) minTop = topRow[x + dx];
    }
    const h = minTop === H ? 0 : (H - minTop);
    samples.push(h);
  }

  // Suavizado ligero (media de ±SMOOTH_R vecinos con valor > 0)
  const smoothed = samples.map((v, i) => {
    if (v === 0) return 0;
    let sum = 0, cnt = 0;
    for (let d = -SMOOTH_R; d <= SMOOTH_R; d++) {
      const ni = i + d;
      if (ni >= 0 && ni < samples.length && samples[ni] > 0) {
        sum += samples[ni]; cnt++;
      }
    }
    return Math.round(sum / cnt);
  });

  return { samples: smoothed, W, H };
}

async function main() {
  const spriteDir = process.argv[2] || 'assets/sprites/cars/side_test';
  const files = fs.readdirSync(spriteDir)
    .filter(f => f.match(/^car_side_\d+\.png$/))
    .sort();

  console.log(`Analizando contorno de ${files.length} autos (step=${STEP}px)\n`);

  const allContours = {};

  for (const f of files) {
    const idx = parseInt(f.match(/\d+/)[0]);
    const img = await Jimp.read(path.join(spriteDir, f));
    const { samples, W, H } = await getContour(img);

    // Encontrar rango válido
    let first = -1, last = -1;
    for (let i = 0; i < samples.length; i++) {
      if (samples[i] > 0) { if (first === -1) first = i; last = i; }
    }

    allContours[idx] = { samples, W, H, first, last };
    console.log(`${f}: ${samples.length} muestras, válidas [${first}..${last}]`);
    // Mostrar mini-gráfico ASCII
    const MAX_H = Math.max(...samples);
    const BAR_H = 8;
    for (let row = BAR_H; row >= 1; row--) {
      let line = '  ';
      for (const s of samples) {
        const bar = Math.round((s / MAX_H) * BAR_H);
        line += bar >= row ? '█' : ' ';
      }
      console.log(line);
    }
    console.log('');
  }

  // Generar constante GDScript
  console.log('# ── Copiar esto en car_mid_layer.gd ────────────────────────────────────────');
  console.log(`# CAR_CONTOURS[frame_idx] = array de alturas (en px de canvas) muestreadas cada ${STEP}px`);
  let out = `const CAR_CONTOUR_STEP: float = ${STEP}.0\n`;
  out += 'const CAR_CONTOURS: Dictionary = {\n';
  for (const [idx, { samples }] of Object.entries(allContours)) {
    out += `\t${idx}: [${samples.join(', ')}],\n`;
  }
  out += '}';
  console.log(out);
}

main().catch(e => { console.error(e); process.exit(1); });
