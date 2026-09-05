// Invierte el efecto de chroma_magenta.js en pixels que no quedaron en 0.
// Uso: node tools/restore_bus_alpha.js <carpeta>

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const THRESHOLD = 80;
const folder = process.argv[2];

async function main() {
  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  for (const file of files) {
    const fpath = path.join(folder, file);
    const img = await Jimp.read(fpath);
    const { data } = img.bitmap;
    for (let i = 0; i < data.length; i += 4) {
      const a = data[i + 3];
      if (a === 0) continue; // transparente total: borde o chroma fuerte, no tocar
      const R = data[i], G = data[i + 1], B = data[i + 2];
      const magentaness = Math.min(R, B) - G;
      if (magentaness > 0 && magentaness < THRESHOLD) {
        const factor = 1 - magentaness / THRESHOLD;
        // alpha_original = alpha_actual / factor
        data[i + 3] = Math.min(255, Math.round(a / factor));
      }
    }
    await img.write(fpath);
    console.log(`${file} OK`);
  }
  console.log('Listo!');
}
main().catch(console.error);
