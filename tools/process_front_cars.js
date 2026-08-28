// Uso: node tools/process_front_cars.js <out_dir> <file1> <file2> ...
// Saca el fondo magenta y guarda como frame_00.png, frame_01.png, etc.

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

async function removeMagenta(img) {
  const data = img.bitmap.data;
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i+1], b = data[i+2];
    if (r > g * 1.8 && b > g * 1.5 && r > 90 && b > 70) {
      data[i+3] = 0;
    } else if (r > g * 1.3 && b > g * 1.2 && r > 60) {
      const blend = Math.min((r / (g * 1.3) - 1) / 0.5, 1.0);
      data[i+3] = Math.round(data[i+3] * (1 - blend));
      data[i]   = Math.round(Math.min(r, g * 1.25));
      data[i+2] = Math.round(Math.min(b, g * 1.25));
    }
  }
}

async function main() {
  const outDir = process.argv[2];
  const files  = process.argv.slice(3);
  if (!outDir || files.length === 0) {
    console.log('Uso: node tools/process_front_cars.js <out_dir> <file1> ...');
    process.exit(1);
  }
  fs.mkdirSync(outDir, { recursive: true });

  for (let i = 0; i < files.length; i++) {
    const img = await Jimp.read(files[i]);
    await removeMagenta(img);
    const outPath = path.join(outDir, `frame_${String(i).padStart(2,'0')}.png`);
    await img.write(outPath);
    console.log(`frame_${String(i).padStart(2,'0')}.png ← ${path.basename(files[i])} (${img.bitmap.width}×${img.bitmap.height})`);
  }
  console.log('Listo!');
}
main().catch(console.error);
