// Uso: node tools/chroma_magenta.js <input.png> <output.png>
// Elimina fondo magenta (R alto, B alto, G bajo) con suavizado en bordes.

const { Jimp } = require('jimp');

const THRESHOLD = 80;

async function main() {
  const [src, dst] = process.argv.slice(2);
  if (!src || !dst) { console.log('Uso: node tools/chroma_magenta.js <input.png> <output.png>'); process.exit(1); }

  const img = await Jimp.read(src);
  const data = img.bitmap.data;

  for (let i = 0; i < data.length; i += 4) {
    const R = data[i], G = data[i + 1], B = data[i + 2];
    // "magentaness": ambos R y B altos, G bajo
    const magentaness = Math.min(R, B) - G;
    if (magentaness >= THRESHOLD) {
      data[i + 3] = 0;
    } else if (magentaness > 0) {
      data[i + 3] = Math.round(data[i + 3] * (1 - magentaness / THRESHOLD));
    }
  }

  await img.write(dst);
  console.log('Listo:', dst);
}
main().catch(console.error);
