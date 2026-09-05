// Mide bounding box completo (x, y, ancho, alto) del contenido visible de un PNG
// Uso: node tools/measure_sprite_bounds.js <img_a.png> <img_b.png>

const { Jimp } = require('jimp');

async function bounds(fpath) {
  const img = await Jimp.read(fpath);
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
  const w = maxX - minX + 1;
  const h = maxY - minY + 1;
  return { minX, maxX, minY, maxY, w, h, cx: (minX + maxX) / 2, cy: (minY + maxY) / 2, canvas: { width, height } };
}

async function main() {
  const files = process.argv.slice(2);
  if (!files.length) { console.log('Uso: node tools/measure_sprite_bounds.js <a.png> [b.png ...]'); process.exit(1); }
  for (const f of files) {
    const b = await bounds(f);
    const name = f.split(/[\\/]/).pop();
    console.log(`${name}: canvas=${b.canvas.width}x${b.canvas.height} | content=${b.w}x${b.h} | center=(${b.cx.toFixed(0)}, ${b.cy.toFixed(0)}) | top=${b.minY} bottom=${b.maxY}`);
  }
}
main().catch(console.error);
