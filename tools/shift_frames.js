// Uso: node tools/shift_frames.js <carpeta> <dx> <dy>
// Traslada todos los PNGs de una carpeta por (dx,dy) sobre un canvas transparente
// del mismo tamaño (recorta si se sale del canvas). Aplica el MISMO offset a todos
// los frames para reposicionar un set entero sin tocar el movimiento relativo interno.

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

async function main() {
  const folder = process.argv[2];
  const dx = parseInt(process.argv[3]);
  const dy = parseInt(process.argv[4]);

  if (!folder || isNaN(dx) || isNaN(dy)) {
    console.log('Uso: node tools/shift_frames.js <carpeta> <dx> <dy>');
    process.exit(1);
  }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  console.log(`Desplazando ${files.length} frames por (${dx}, ${dy})`);

  for (let i = 0; i < files.length; i++) {
    const fpath = path.join(folder, files[i]);
    const img = await Jimp.read(fpath);
    const { width: W, height: H } = img.bitmap;
    const canvas = new Jimp({ width: W, height: H, color: 0x00000000 });
    canvas.composite(img, dx, dy);
    await canvas.write(fpath);
    process.stdout.write(`\r  ${i + 1}/${files.length}`);
  }
  console.log('\nListo!');
}

main().catch(console.error);
