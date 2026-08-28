// Uso: node tools/process_drone.js <video> <carpeta_salida>
// Extrae frames del video de drone, tapa el watermark de Kling, aplica chroma key
// y estabiliza la posición centrando en el centroide ponderado por alpha de cada frame.

const { Jimp } = require('jimp');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const CHROMA_THRESHOLD = 80;
const WM_LEFT_FRAC    = 0.75;
const WM_TOP_FRAC     = 0.91;
const ALPHA_MIN       = 64;   // ignorar semi-transparentes del borde al calcular centroide

// Centro de masa ponderado por alpha — mucho más estable que el bbox ante blur de hélices
function getCentroid(data, width, height) {
  let sumX = 0, sumY = 0, totalA = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const a = data[(y * width + x) * 4 + 3];
      if (a >= ALPHA_MIN) {
        sumX += x * a;
        sumY += y * a;
        totalA += a;
      }
    }
  }
  if (totalA === 0) return { cx: width / 2, cy: height / 2 };
  return { cx: sumX / totalA, cy: sumY / totalA };
}

async function main() {
  const [,, videoPath, outputFolder] = process.argv;
  if (!videoPath || !outputFolder) {
    console.log('Uso: node tools/process_drone.js <video> <carpeta_salida>');
    process.exit(1);
  }

  fs.mkdirSync(outputFolder, { recursive: true });

  const tmpDir = path.join(os.tmpdir(), 'drone_frames_' + Date.now());
  fs.mkdirSync(tmpDir, { recursive: true });

  console.log('Extrayendo frames...');
  execSync(
    `ffmpeg -i "${videoPath}" -vsync 0 -vf scale=1920:1920:flags=lanczos "${path.join(tmpDir, 'frame_%04d.png')}" -y`,
    { stdio: 'pipe' }
  );

  const frameFiles = fs.readdirSync(tmpDir).filter(f => f.endsWith('.png')).sort();
  console.log(`${frameFiles.length} frames extraídos. Aplicando chroma key...`);

  const imgs = [];
  const centroids = [];

  // Paso 1: chroma key + calcular centroide de cada frame
  for (let i = 0; i < frameFiles.length; i++) {
    const img = await Jimp.read(path.join(tmpDir, frameFiles[i]));
    const { width, height } = img.bitmap;
    const data = img.bitmap.data;

    // Tapar watermark
    const wmLeft = Math.floor(width  * WM_LEFT_FRAC);
    const wmTop  = Math.floor(height * WM_TOP_FRAC);
    for (let y = wmTop; y < height; y++) {
      for (let x = wmLeft; x < width; x++) {
        const idx = (y * width + x) * 4;
        data[idx] = 0; data[idx+1] = 255; data[idx+2] = 0; data[idx+3] = 255;
      }
    }

    // Chroma key
    for (let idx = 0; idx < data.length; idx += 4) {
      const R = data[idx], G = data[idx+1], B = data[idx+2];
      const greenness = G - Math.max(R, B);
      if (greenness >= CHROMA_THRESHOLD) {
        data[idx+3] = 0;
      } else if (greenness > 0) {
        data[idx+3] = Math.round(data[idx+3] * (1 - greenness / CHROMA_THRESHOLD));
      }
    }

    centroids.push(getCentroid(data, width, height));
    imgs.push(img);
    process.stdout.write(`\r  chroma ${i + 1}/${frameFiles.length}`);
  }

  // Centro objetivo: mediana de los centroides (más robusta que el promedio ante outliers)
  const sortedX = centroids.map(c => c.cx).sort((a, b) => a - b);
  const sortedY = centroids.map(c => c.cy).sort((a, b) => a - b);
  const mid = Math.floor(centroids.length / 2);
  const targetCx = Math.round(sortedX[mid]);
  const targetCy = Math.round(sortedY[mid]);
  console.log(`\nCentroide mediana: (${targetCx}, ${targetCy}). Estabilizando...`);

  const { width, height } = imgs[0].bitmap;

  // Paso 2: centrar cada frame con composite
  for (let i = 0; i < imgs.length; i++) {
    const dx = Math.round(targetCx - centroids[i].cx);
    const dy = Math.round(targetCy - centroids[i].cy);

    let out = imgs[i];
    if (dx !== 0 || dy !== 0) {
      const blank = new Jimp({ width, height, color: 0x00000000 });
      blank.composite(imgs[i], dx, dy);
      out = blank;
    }

    const outName = `drone_${String(i + 1).padStart(4, '0')}.png`;
    await out.write(path.join(outputFolder, outName));
    process.stdout.write(`\r  ${i + 1}/${imgs.length}  (dx=${dx.toString().padStart(4)}, dy=${dy.toString().padStart(4)})  `);
  }

  fs.rmSync(tmpDir, { recursive: true, force: true });
  console.log(`\nListo! ${imgs.length} frames en ${outputFolder}`);
}

main().catch(console.error);
