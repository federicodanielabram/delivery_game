// Todos los frames de death del waiter original, grande y en fila
const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const SRC_DIR = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\waiter\\death';
const OUT     = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\death_strip.png';

const CELL_W = 260, CELL_H = 220;

(async () => {
  const files = fs.readdirSync(SRC_DIR)
    .filter(f => f.endsWith('.png') && !f.includes('.import') && !f.includes('bk'))
    .sort();

  const sheet = new Jimp({ width: files.length * CELL_W, height: CELL_H, color: 0x222233ff });

  for (let c = 0; c < files.length; c++) {
    const img = await Jimp.read(path.join(SRC_DIR, files[c]));
    img.scaleToFit({ w: CELL_W - 4, h: CELL_H - 4 });
    sheet.composite(img, c * CELL_W + 2, 2);
  }

  await sheet.write(OUT);
  console.log(`Strip: ${files.length} frames → ${OUT}`);
  console.log(files.map((f,i)=>`${i+1}:${f}`).join('  '));
})().catch(console.error);
