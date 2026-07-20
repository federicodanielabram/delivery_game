// Muestra todos los frames de death para los 3 variantes
const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const BASE     = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies';
const VARIANTS = ['waiter', 'waiter_dark', 'waiter_light'];

const CELL_W = 160, CELL_H = 140;

(async () => {
  // Detectar cuántos frames hay
  const refDir = path.join(BASE, 'waiter', 'death');
  const allFiles = fs.readdirSync(refDir)
    .filter(f => f.endsWith('.png') && !f.includes('.import') && !f.includes('bk'))
    .sort();
  const COLS = allFiles.length;
  const ROWS = VARIANTS.length;

  const sheet = new Jimp({ width: COLS * CELL_W, height: ROWS * CELL_H, color: 0x222233ff });

  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const src = path.join(BASE, VARIANTS[r], 'death', allFiles[c]);
      try {
        const img = await Jimp.read(src);
        img.scaleToFit({ w: CELL_W - 4, h: CELL_H - 4 });
        sheet.composite(img, c * CELL_W + 2, r * CELL_H + 2);
      } catch (e) { console.warn(`No encontré: ${src}`); }
    }
  }

  const out = path.join(BASE, 'comparison_death.png');
  await sheet.write(out);
  console.log(`Death frames (${COLS} frames × ${ROWS} variantes): ${out}`);
})().catch(console.error);
