// Uso: node tools/process_spritesheet.js <imagen> <salida> [cols] [rows]
// Hace chroma key del fondo magenta y guarda el spritesheet con fondo transparente.
// Default: 3 columnas, 4 filas.

const { Jimp } = require('jimp');
const path = require('path');

async function main() {
  const src  = process.argv[2];
  const dst  = process.argv[3];
  const cols = parseInt(process.argv[4] ?? '3');
  const rows = parseInt(process.argv[5] ?? '4');

  if (!src || !dst) {
    console.log('Uso: node tools/process_spritesheet.js <imagen> <salida> [cols] [rows]');
    process.exit(1);
  }

  const img  = await Jimp.read(src);
  const data = img.bitmap.data;
  let removed = 0;

  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2];
    // Magenta pura y fringe por ratio: R y B dominan claramente sobre G
    if (r > g * 1.8 && b > g * 1.5 && r > 90 && b > 70) {
      data[i + 3] = 0;
      removed++;
    } else if (r > g * 1.3 && b > g * 1.2 && r > 60) {
      // Despill: reducir el cast magenta en bordes sin eliminar el pixel
      data[i]     = Math.round(Math.min(r, g * 1.25));
      data[i + 2] = Math.round(Math.min(b, g * 1.25));
    }
  }

  await img.write(dst);
  const total = data.length / 4;
  const fw = Math.floor(img.bitmap.width  / cols);
  const fh = Math.floor(img.bitmap.height / rows);
  console.log(`✓ ${path.basename(src)} → ${path.basename(dst)}`);
  console.log(`  ${cols}×${rows} frames — cada frame ${fw}×${fh}px`);
  console.log(`  Pixels eliminados: ${removed} / ${total} (${(removed/total*100).toFixed(1)}%)`);
}

main().catch(e => { console.error(e); process.exit(1); });
