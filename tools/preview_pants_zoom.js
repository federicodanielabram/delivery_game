// Zoom en la mitad inferior del sprite para comparar pantalones entre animaciones
const { Jimp } = require('jimp');
const path = require('path');

const BASE = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies';
const VARIANTS = ['waiter', 'waiter_dark', 'waiter_light'];
const FRAMES = [
  { anim: 'walk',  file: 'walk___001.png'   },
  { anim: 'throw', file: 'throw____001.png'  },
  { anim: 'hurt',  file: 'hurt____001.png'   },
  { anim: 'death', file: 'death____001.png'  },
];

const SCALE = 3;
const CELL_W = 130 * SCALE, CELL_H = 80 * SCALE;
const COLS = FRAMES.length, ROWS = VARIANTS.length;

(async () => {
  const sheet = new Jimp({ width: COLS * CELL_W, height: ROWS * CELL_H, color: 0x222233ff });

  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const src = path.join(BASE, VARIANTS[r], FRAMES[c].anim, FRAMES[c].file);
      try {
        const img = await Jimp.read(src);
        const { width, height } = img.bitmap;
        // Recorta la mitad inferior (pantalones/zapatos)
        const cropY = Math.floor(height * 0.45);
        const cropH = height - cropY;
        img.crop({ x: 0, y: cropY, w: width, h: cropH });
        img.scaleToFit({ w: CELL_W - 4, h: CELL_H - 4 });
        sheet.composite(img, c * CELL_W + 2, r * CELL_H + 2);
      } catch (e) {
        console.warn(`No encontré: ${src}`);
      }
    }
  }

  const out = path.join(BASE, 'comparison_pants.png');
  await sheet.write(out);
  console.log(`Zoom guardado en: ${out}`);
})().catch(console.error);
