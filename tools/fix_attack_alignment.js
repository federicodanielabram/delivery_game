// Reprocesa frames de ataque pinando el centro X de los pies a una posicion fija.
// Uso: node tools/fix_attack_alignment.js <carpeta> [targetX]
// targetX: X destino de los pies en el canvas 200x200. Default: centro del idle (99)

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const CANVAS_W = 200;
const CANVAS_H = 200;
const FOOT_ZONE = 0.25; // usar el 25% inferior del personaje para detectar pies

async function feetCenterX(img) {
  // Bounding box del personaje
  let minY = 99999, maxY = 0;
  img.scan(0, 0, img.width, img.height, (x, y, idx) => {
    if (img.bitmap.data[idx + 3] > 128) {
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  });
  const charH = maxY - minY;
  const footThreshold = maxY - charH * FOOT_ZONE;

  // Centro X de los pixeles en la zona de pies
  let sumX = 0, count = 0;
  img.scan(0, 0, img.width, img.height, (x, y, idx) => {
    if (img.bitmap.data[idx + 3] > 128 && y >= footThreshold) {
      sumX += x; count++;
    }
  });
  return count > 0 ? sumX / count : CANVAS_W / 2;
}

async function main() {
  const folder  = process.argv[2];
  const targetX = process.argv[3] ? parseInt(process.argv[3]) : 99;

  if (!folder) {
    console.log('Uso: node tools/fix_attack_alignment.js <carpeta> [targetX]');
    process.exit(1);
  }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  console.log(`${files.length} frames — pineando pies a X=${targetX}`);

  for (let i = 0; i < files.length; i++) {
    const fpath = path.join(folder, files[i]);
    const img   = await Jimp.read(fpath);

    const cx = await feetCenterX(img);
    const shift = Math.round(targetX - cx);

    const canvas = new Jimp({ width: CANVAS_W, height: CANVAS_H, color: 0x00000000 });
    canvas.composite(img, shift, 0);

    await canvas.write(fpath);
    process.stdout.write(`\r  ${i + 1}/${files.length}  (shift=${shift > 0 ? '+' : ''}${shift})`);
  }
  console.log('\nListo!');
}

main().catch(console.error);
