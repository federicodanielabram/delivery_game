// Borra píxeles en una zona rectangular de frames específicos.
// Uso: node tools/erase_zone.js <carpeta> <xMin> <yMin> <xMax> <yMax> [frameDesde] [frameHasta]

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

async function main() {
  const [,, folder, x1, y1, x2, y2, fromF, toF] = process.argv;
  if (!folder) { console.log('Uso: node tools/erase_zone.js <carpeta> <xMin> <yMin> <xMax> <yMax> [frameDesde] [frameHasta]'); process.exit(1); }

  const XA = parseInt(x1), YA = parseInt(y1), XB = parseInt(x2), YB = parseInt(y2);
  const from = fromF ? parseInt(fromF) - 1 : 0;

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  const to = toF ? parseInt(toF) - 1 : files.length - 1;

  console.log(`Borrando zona (${XA},${YA})-(${XB},${YB}) en frames ${from+1}-${to+1}`);

  for (let fi = from; fi <= to; fi++) {
    const fpath = path.join(folder, files[fi]);
    const img   = await Jimp.read(fpath);
    const W = img.bitmap.width;
    const data = img.bitmap.data;

    for (let y = YA; y <= YB; y++) {
      for (let x = XA; x <= XB; x++) {
        if (x < 0 || x >= img.bitmap.width || y < 0 || y >= img.bitmap.height) continue;
        data[(y * W + x) * 4 + 3] = 0;
      }
    }

    await img.write(fpath);
    process.stdout.write(`\r  frame ${fi + 1} OK`);
  }
  console.log('\nListo!');
}

main().catch(console.error);
