// Mide el centro horizontal del contenido visible de dos PNGs
// Uso: node tools/measure_sprite_offset.js <img_a.png> <img_b.png>

const { Jimp } = require('jimp');

async function centerX(fpath) {
  const img = await Jimp.read(fpath);
  const { width, height, data } = img.bitmap;
  let minX = width, maxX = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const a = data[(y * width + x) * 4 + 3];
      if (a > 32) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
      }
    }
  }
  return { min: minX, max: maxX, center: (minX + maxX) / 2 };
}

async function main() {
  const [a, b] = process.argv.slice(2);
  if (!a || !b) { console.log('Uso: node tools/measure_sprite_offset.js <a.png> <b.png>'); process.exit(1); }
  const ra = await centerX(a);
  const rb = await centerX(b);
  console.log(`A (${a.split(/[\\/]/).pop()}): min=${ra.min} max=${ra.max} center=${ra.center.toFixed(1)}`);
  console.log(`B (${b.split(/[\\/]/).pop()}): min=${rb.min} max=${rb.max} center=${rb.center.toFixed(1)}`);
  console.log(`Offset B-A: ${(rb.center - ra.center).toFixed(1)} px`);
}
main().catch(console.error);
