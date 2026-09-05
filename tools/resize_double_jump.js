// Redimensiona los frames de double_jump para que el personaje quede al mismo tamaño
// que los sprites de run (153px de alto en canvas 200x200).
// Uso: node tools/resize_double_jump.js <input_folder> <output_folder>

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const TARGET_CHAR_H = 153;  // alto del personaje en run__001
const TARGET_CANVAS = 200;  // canvas de salida

async function getContentBounds(img) {
  const { width, height, data } = img.bitmap;
  let minX = width, maxX = 0, minY = height, maxY = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const a = data[(y * width + x) * 4 + 3];
      if (a > 32) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return { minX, maxX, minY, maxY, w: maxX - minX + 1, h: maxY - minY + 1 };
}

async function main() {
  const inFolder  = process.argv[2];
  const outFolder = process.argv[3];
  if (!inFolder || !outFolder) {
    console.log('Uso: node tools/resize_double_jump.js <input> <output>');
    process.exit(1);
  }
  fs.mkdirSync(outFolder, { recursive: true });

  // Medir frame 59 para calcular escala (personaje de referencia)
  const ref = await Jimp.read(path.join(inFolder, 'frame_059.png'));
  const rb  = await getContentBounds(ref);
  const scale = TARGET_CHAR_H / rb.h;
  console.log(`Ref frame_059: char=${rb.w}x${rb.h} | scale=${scale.toFixed(4)} | canvas ${ref.bitmap.width}→${TARGET_CANVAS}`);

  const files = fs.readdirSync(inFolder).filter(f => f.endsWith('.png')).sort();
  for (let i = 0; i < files.length; i++) {
    const fpath = path.join(inFolder, files[i]);
    const img   = await Jimp.read(fpath);

    // Escalar todo el canvas con el mismo factor
    const newW = Math.round(img.bitmap.width  * scale);
    const newH = Math.round(img.bitmap.height * scale);
    img.resize({ w: newW, h: newH });

    // Centrar en canvas TARGET_CANVAS x TARGET_CANVAS
    const out  = new Jimp({ width: TARGET_CANVAS, height: TARGET_CANVAS, color: 0x00000000 });
    const offX = Math.round((TARGET_CANVAS - newW) / 2);
    const offY = TARGET_CANVAS - newH; // alinear base (pies) al fondo del canvas
    out.composite(img, offX, offY);

    // Nombre de salida: double_jump__001.png ...
    const num    = String(i + 1).padStart(3, '0');
    const outPath = path.join(outFolder, `double_jump__${num}.png`);
    await out.write(outPath);
    process.stdout.write(`\r  ${i + 1}/${files.length}`);
  }
  console.log('\nListo!');
}
main().catch(console.error);
