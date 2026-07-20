// Limpia el spill verde del chroma en los bordes de todos los PNGs de una carpeta.
// - Borra los pixeles de borde con verde fuerte (halo del chroma).
// - Neutraliza el tinte verde suave que queda (sin erosionar la silueta).
// Uso: node tools/despill_edges.js <carpeta> [passes]

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

async function despill(imgPath, passes) {
  const img = await Jimp.read(imgPath);
  const { width, height } = img.bitmap;
  const data = img.bitmap.data;

  const touchesTransparent = (x, y) => {
    if (x > 0          && data[((y) * width + (x - 1)) * 4 + 3] === 0) return true;
    if (x < width - 1  && data[((y) * width + (x + 1)) * 4 + 3] === 0) return true;
    if (y > 0          && data[((y - 1) * width + x) * 4 + 3] === 0) return true;
    if (y < height - 1 && data[((y + 1) * width + x) * 4 + 3] === 0) return true;
    return false;
  };

  // Borrar verde fuerte del borde (varias pasadas para comer el halo)
  let removed = 0;
  for (let pass = 0; pass < passes; pass++) {
    const toClear = [];
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const p = (y * width + x) * 4;
        if (data[p + 3] === 0) continue;
        const r = data[p], g = data[p + 1], b = data[p + 2];
        if (g > r + 12 && g > b + 12 && touchesTransparent(x, y)) toClear.push(p);
      }
    }
    for (const p of toClear) data[p + 3] = 0;
    removed += toClear.length;
  }

  // Neutralizar el tinte verde suave que quede en el borde
  let neutral = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const p = (y * width + x) * 4;
      if (data[p + 3] === 0) continue;
      const r = data[p], g = data[p + 1], b = data[p + 2];
      if (g > r + 3 && g > b + 3 && touchesTransparent(x, y)) {
        data[p + 1] = Math.max(r, b);  // baja el verde al nivel de r/b
        neutral++;
      }
    }
  }

  await img.write(imgPath);
  return removed + neutral;
}

async function main() {
  const folder = process.argv[2];
  const passes = parseInt(process.argv[3] ?? '2');
  if (!folder) { console.log('Uso: node tools/despill_edges.js <carpeta> [passes]'); process.exit(1); }
  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  let total = 0;
  for (let i = 0; i < files.length; i++) {
    total += await despill(path.join(folder, files[i]), passes);
    process.stdout.write(`\r  ${i + 1}/${files.length}`);
  }
  console.log(`\n${folder}: ${total}px limpiados en ${files.length} frames`);
}
main().catch(console.error);
