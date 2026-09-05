// Muestra los primeros 6px de cada borde del bus
const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const folder = process.argv[2];
async function main() {
  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  for (const file of files) {
    const img = await Jimp.read(path.join(folder, file));
    const { width, height, data } = img.bitmap;
    const mx = Math.floor(width / 2);
    const my = Math.floor(height / 2);
    console.log(`\n${file}  ${width}x${height}`);

    const sample = (label, pixels) => {
      console.log(`  ${label}:`);
      for (const [x, y] of pixels) {
        const i = (y * width + x) * 4;
        console.log(`    (${x},${y})  rgba(${data[i]},${data[i+1]},${data[i+2]},${data[i+3]})`);
      }
    };

    sample('izq (y=mid)', [[0,my],[1,my],[2,my],[3,my],[4,my],[5,my]]);
    sample('der (y=mid)', [[width-6,my],[width-5,my],[width-4,my],[width-3,my],[width-2,my],[width-1,my]]);
    sample('top (x=mid)', [[mx,0],[mx,1],[mx,2],[mx,3],[mx,4],[mx,5]]);
    sample('bot (x=mid)', [[mx,height-6],[mx,height-5],[mx,height-4],[mx,height-3],[mx,height-2],[mx,height-1]]);
  }
}
main().catch(console.error);
