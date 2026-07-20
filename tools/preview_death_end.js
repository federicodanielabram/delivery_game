// Zoom en los últimos 6 frames de death (la caída y el frame estático final)
const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const BASE     = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies';
const VARIANTS = ['waiter', 'waiter_dark', 'waiter_light'];

const SCALE = 3;
const CELL_W = 180 * SCALE, CELL_H = 110 * SCALE;
const LAST_N = 6;

(async () => {
  const refDir  = path.join(BASE, 'waiter', 'death');
  const allFiles = fs.readdirSync(refDir)
    .filter(f => f.endsWith('.png') && !f.includes('.import') && !f.includes('bk'))
    .sort();
  const lastFiles = allFiles.slice(-LAST_N);

  const COLS = LAST_N, ROWS = VARIANTS.length;
  const sheet = new Jimp({ width: COLS * CELL_W, height: ROWS * CELL_H, color: 0x222233ff });

  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const src = path.join(BASE, VARIANTS[r], 'death', lastFiles[c]);
      try {
        const img = await Jimp.read(src);
        img.scaleToFit({ w: CELL_W - 4, h: CELL_H - 4 });
        sheet.composite(img, c * CELL_W + 2, r * CELL_H + 2);
      } catch (e) { console.warn(`No encontré: ${src}`); }
    }
  }

  const out = path.join(BASE, 'comparison_death_end.png');
  await sheet.write(out);
  console.log(`Últimos ${LAST_N} frames de death × ${ROWS} variantes: ${out}`);
  console.log('Frames:', lastFiles.join(', '));
})().catch(console.error);
