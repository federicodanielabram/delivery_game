// Elimina el watermark de Kling (esquina inferior derecha) de los frames del double jump
// Uso: node tools/remove_watermark.js <carpeta>

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const WM_W = 45;  // ancho del área a borrar
const WM_H = 14;  // alto del área a borrar

async function main() {
  const folder = process.argv[2];
  if (!folder) { console.log('Uso: node tools/remove_watermark.js <carpeta>'); process.exit(1); }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png') && !f.endsWith('.import')).sort();
  for (let i = 0; i < files.length; i++) {
    const fpath = path.join(folder, files[i]);
    const img   = await Jimp.read(fpath);
    const { width, height } = img.bitmap;
    // Borrar esquina inferior derecha
    for (let y = height - WM_H; y < height; y++) {
      for (let x = width - WM_W; x < width; x++) {
        img.setPixelColor(0x00000000, x, y);
      }
    }
    await img.write(fpath);
    process.stdout.write(`\r  ${i + 1}/${files.length}`);
  }
  console.log('\nListo!');
}
main().catch(console.error);
