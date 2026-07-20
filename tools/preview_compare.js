// Genera una grilla de comparación: 3 variantes × 4 animaciones (frame 1 de cada una)
// Output: comparison.png en la carpeta enemies/

const { Jimp } = require('jimp');
const path = require('path');

const BASE = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies';

const VARIANTS = ['waiter', 'waiter_dark', 'waiter_light'];
const ANIMS    = [
  { name: 'walk',   file: 'walk___001.png'  },
  { name: 'throw',  file: 'throw____001.png' },
  { name: 'hurt',   file: 'hurt____001.png'  },
  { name: 'death',  file: 'death____001.png' },
];

const CELL_W = 180, CELL_H = 220;
const COLS = ANIMS.length, ROWS = VARIANTS.length;

(async () => {
  const sheet = new Jimp({ width: COLS * CELL_W, height: ROWS * CELL_H, color: 0x222233ff });

  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const src = path.join(BASE, VARIANTS[r], ANIMS[c].name, ANIMS[c].file);
      try {
        const img = await Jimp.read(src);
        // Escala para que quepa en la celda manteniendo proporción
        img.scaleToFit({ w: CELL_W - 8, h: CELL_H - 8 });
        sheet.composite(img, c * CELL_W + 4, r * CELL_H + 4);
      } catch (e) {
        console.warn(`No encontré: ${src}`);
      }
    }
  }

  const out = path.join(BASE, 'comparison.png');
  await sheet.write(out);
  console.log(`Preview guardado en: ${out}`);
})().catch(console.error);
