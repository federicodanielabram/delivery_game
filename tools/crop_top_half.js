// Uso: node tools/crop_top_half.js <input_dir> <output_dir>
// Recorta cada PNG al 50% superior y guarda en output_dir.

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

async function main() {
  const inDir  = process.argv[2];
  const outDir = process.argv[3];
  const fixedH = process.argv[4] ? parseInt(process.argv[4]) : null;
  if (!inDir || !outDir) { console.log('Uso: node tools/crop_top_half.js <input_dir> <output_dir> [altura_fija]'); process.exit(1); }

  fs.mkdirSync(outDir, { recursive: true });
  const files = fs.readdirSync(inDir).filter(f => f.endsWith('.png')).sort();

  for (const f of files) {
    const img = await Jimp.read(path.join(inDir, f));
    const cropH = fixedH ? Math.min(fixedH, img.bitmap.height) : Math.floor(img.bitmap.height / 2);
    const cropped = await img.clone().crop({ x: 0, y: 0, w: img.bitmap.width, h: cropH });
    await cropped.write(path.join(outDir, f));
    console.log(`${f}: ${img.bitmap.width}×${img.bitmap.height} → ${img.bitmap.width}×${cropH}`);
  }
  console.log('Listo!');
}
main().catch(console.error);
