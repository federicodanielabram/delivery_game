// Uso: node tools/process_drone_folder.js <carpeta_entrada> <carpeta_salida>
// Toma PNGs con fondo verde, aplica toda la pipeline:
//   escala 1920x1920 → tapa watermark → chroma key → estabiliza → apaga sirena

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const OUT_SIZE         = 1920;
const CHROMA_THRESHOLD = 80;
const WM_LEFT_FRAC     = 0.76;
const WM_TOP_FRAC      = 0.91;
const ALPHA_MIN        = 64;
const ROOF_FRAC        = 0.50;  // top 50% del bbox — las antenas estiran el techo
const BRIGHT_SUM       = 220;
const DIM_FACTOR       = 0.12;

function getCentroid(data, width, height) {
  let sumX = 0, sumY = 0, totalA = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const a = data[(y * width + x) * 4 + 3];
      if (a >= ALPHA_MIN) { sumX += x * a; sumY += y * a; totalA += a; }
    }
  }
  if (totalA === 0) return { cx: width / 2, cy: height / 2 };
  return { cx: sumX / totalA, cy: sumY / totalA };
}

function getBboxTop(data, width, height) {
  for (let y = 0; y < height; y++)
    for (let x = 0; x < width; x++)
      if (data[(y * width + x) * 4 + 3] > ALPHA_MIN) return y;
  return 0;
}

function getBboxBottom(data, width, height) {
  for (let y = height - 1; y >= 0; y--)
    for (let x = 0; x < width; x++)
      if (data[(y * width + x) * 4 + 3] > ALPHA_MIN) return y;
  return height - 1;
}

async function main() {
  const [,, inFolder, outFolder] = process.argv;
  if (!inFolder || !outFolder) {
    console.log('Uso: node tools/process_drone_folder.js <carpeta_entrada> <carpeta_salida>');
    process.exit(1);
  }
  fs.mkdirSync(outFolder, { recursive: true });

  const files = fs.readdirSync(inFolder)
    .filter(f => f.toLowerCase().endsWith('.png'))
    .sort();
  console.log(`${files.length} frames encontrados. Procesando...`);

  const imgs      = [];
  const centroids = [];

  for (let i = 0; i < files.length; i++) {
    let img = await Jimp.read(path.join(inFolder, files[i]));

    // Escalar a 1920x1920
    img.resize({ w: OUT_SIZE, h: OUT_SIZE });

    const { width, height } = img.bitmap;
    const data = img.bitmap.data;

    // Tapar watermark con verde
    const wmL = Math.floor(width * WM_LEFT_FRAC);
    const wmT = Math.floor(height * WM_TOP_FRAC);
    for (let y = wmT; y < height; y++)
      for (let x = wmL; x < width; x++) {
        const idx = (y * width + x) * 4;
        data[idx] = 0; data[idx+1] = 255; data[idx+2] = 0; data[idx+3] = 255;
      }

    // Chroma key + despill
    for (let idx = 0; idx < data.length; idx += 4) {
      const R = data[idx], G = data[idx+1], B = data[idx+2];
      const gn = G - Math.max(R, B);
      if (gn >= CHROMA_THRESHOLD) {
        data[idx+3] = 0;
      } else if (gn > 0) {
        data[idx+3] = Math.round(data[idx+3] * (1 - gn / CHROMA_THRESHOLD));
      }
      // Despill: píxeles opacos con tinte verde → bajar G al nivel de max(R,B)
      if (data[idx+3] > 128 && gn > 4) {
        data[idx+1] = Math.max(R, B);
      }
    }

    centroids.push(getCentroid(data, width, height));
    imgs.push(img);
    process.stdout.write(`\r  chroma ${i + 1}/${files.length}`);
  }

  // Centroide objetivo: mediana
  const sx = centroids.map(c => c.cx).sort((a, b) => a - b);
  const sy = centroids.map(c => c.cy).sort((a, b) => a - b);
  const mid = Math.floor(centroids.length / 2);
  const tcx = Math.round(sx[mid]);
  const tcy = Math.round(sy[mid]);
  console.log(`\nCentroide mediana: (${tcx}, ${tcy}). Estabilizando + apagando sirena...`);

  const { width, height } = imgs[0].bitmap;

  for (let i = 0; i < imgs.length; i++) {
    const dx = Math.round(tcx - centroids[i].cx);
    const dy = Math.round(tcy - centroids[i].cy);

    // Siempre componer sobre canvas RGBA transparente.
    // Sin esto los PNGs sin canal alpha original se guardan como RGB ignorando la chroma key.
    const blank = new Jimp({ width, height, color: 0x00000000 });
    blank.composite(imgs[i], dx, dy);
    const out = blank;

    // Apagar sirena: zona del techo del drone
    const data    = out.bitmap.data;
    const minY    = getBboxTop(data, width, height);
    const maxY    = getBboxBottom(data, width, height);
    const roofEnd = Math.round(minY + (maxY - minY) * ROOF_FRAC);
    let sirenPx   = 0;
    for (let y = minY; y < roofEnd; y++) {
      for (let x = 0; x < width; x++) {
        const idx = (y * width + x) * 4;
        if (data[idx+3] < 32) continue;
        const R = data[idx], G = data[idx+1], B = data[idx+2];
        if (R + G + B > BRIGHT_SUM) {
          data[idx]   = Math.round(R * DIM_FACTOR);
          data[idx+1] = Math.round(G * DIM_FACTOR);
          data[idx+2] = Math.round(B * DIM_FACTOR);
          sirenPx++;
        }
      }
    }

    const outName = `drone_${String(i + 1).padStart(4, '0')}.png`;
    await out.write(path.join(outFolder, outName));
    process.stdout.write(`\r  ${i + 1}/${files.length}  dx=${dx} dy=${dy}  sirena=${sirenPx}px  `);
  }

  console.log(`\nListo! ${files.length} frames → ${outFolder}`);
  console.log(`Actualizar drone.gd: range(1, ${files.length + 1})`);
}

main().catch(console.error);
