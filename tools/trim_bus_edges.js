// Pone transparentes los N píxeles del borde de cada PNG.
// Uso: node tools/trim_bus_edges.js <carpeta> [px=3]

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const folder = process.argv[2];
const N      = parseInt(process.argv[3] || '3');
if (!folder) { console.log('Uso: node tools/trim_bus_edges.js <carpeta> [px]'); process.exit(1); }

async function main() {
  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  console.log(`Recortando ${N}px de borde en ${files.length} archivos...`);
  for (const file of files) {
    const fpath = path.join(folder, file);
    const img = await Jimp.read(fpath);
    const { width, height } = img.bitmap;
    const data = img.bitmap.data;
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (x < N || x >= width - N || y < N || y >= height - N) {
          const idx = (y * width + x) * 4;
          data[idx + 3] = 0;
        }
      }
    }
    await img.write(fpath);
    console.log(`  ${file} OK`);
  }
  console.log('Listo!');
}
main().catch(console.error);
