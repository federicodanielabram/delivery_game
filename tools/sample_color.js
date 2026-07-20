// Muestrea el color promedio de una región en dos imágenes y calcula la corrección necesaria
const { Jimp } = require('jimp');

async function sampleRegion(img, cx, cy, radius) {
  let r = 0, g = 0, b = 0, n = 0;
  const data = img.bitmap.data;
  const w = img.bitmap.width;
  for (let dy = -radius; dy <= radius; dy++) {
    for (let dx = -radius; dx <= radius; dx++) {
      const px = cx + dx, py = cy + dy;
      if (px < 0 || py < 0 || px >= w || py >= img.bitmap.height) continue;
      const idx = (py * w + px) * 4;
      if (data[idx + 3] < 200) continue;
      r += data[idx]; g += data[idx + 1]; b += data[idx + 2]; n++;
    }
  }
  return n > 0 ? { r: r/n, g: g/n, b: b/n, n } : null;
}

async function main() {
  const ref  = process.argv[2];  // imagen referencia (walk)
  const src  = process.argv[3];  // imagen a corregir (throw)
  const cx   = parseInt(process.argv[4] ?? '95');
  const cy   = parseInt(process.argv[5] ?? '110');
  const rad  = parseInt(process.argv[6] ?? '8');

  const imgRef = await Jimp.read(ref);
  const imgSrc = await Jimp.read(src);

  const colRef = await sampleRegion(imgRef, cx, cy, rad);
  const colSrc = await sampleRegion(imgSrc, cx, cy, rad);

  console.log(`Referencia (walk): R=${colRef.r.toFixed(1)} G=${colRef.g.toFixed(1)} B=${colRef.b.toFixed(1)} (${colRef.n}px)`);
  console.log(`Fuente (throw):    R=${colSrc.r.toFixed(1)} G=${colSrc.g.toFixed(1)} B=${colSrc.b.toFixed(1)} (${colSrc.n}px)`);
  console.log(`Corrección:        R×${(colRef.r/colSrc.r).toFixed(3)} G×${(colRef.g/colSrc.g).toFixed(3)} B×${(colRef.b/colSrc.b).toFixed(3)}`);
}
main().catch(console.error);
