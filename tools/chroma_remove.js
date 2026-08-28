// Uso: node tools/chroma_remove.js <carpeta>
// Elimina el fondo chroma verde (#00FF00) de todos los PNGs de la carpeta.
// Usa "greenness" (G - max(R,B)) para deteccion, con suavizado en bordes.

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

const THRESHOLD = 80;

async function main() {
  const folder = process.argv[2];
  if (!folder) { console.log('Uso: node tools/chroma_remove.js <carpeta>'); process.exit(1); }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  console.log(`Removiendo chroma de ${files.length} frames...`);

  for (let i = 0; i < files.length; i++) {
    const fpath = path.join(folder, files[i]);
    const img = await Jimp.read(fpath);
    const data = img.bitmap.data;

    for (let idx = 0; idx < data.length; idx += 4) {
      const R = data[idx], G = data[idx + 1], B = data[idx + 2];
      const greenness = G - Math.max(R, B);
      if (greenness >= THRESHOLD) {
        data[idx + 3] = 0;
      } else if (greenness > 0) {
        data[idx + 3] = Math.round(data[idx + 3] * (1 - greenness / THRESHOLD));
      }
    }

    await img.write(fpath);
    process.stdout.write(`\r  ${i + 1}/${files.length}`);
  }
  console.log('\nListo!');
}
main().catch(console.error);
