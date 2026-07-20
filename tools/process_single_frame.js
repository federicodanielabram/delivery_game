// Procesa un PNG con fondo verde aplicando los mismos parámetros que process_animation.js
// Uso: node tools/process_single_frame.js <input.png> <output.png> <scale> <minX> <minY> <maxX> <maxY>

const { Jimp } = require('jimp');
const { execSync } = require('child_process');
const fs   = require('fs');
const path = require('path');
const os   = require('os');

const CANVAS_W = 200;
const CANVAS_H = 200;
const FOOT_Y   = 192;

function _cleanEdges(img) {
  const data = img.bitmap.data;
  const len  = data.length;
  for (let idx = 0; idx < len; idx += 4) {
    const a = data[idx + 3];
    if (a === 0) continue;
    const r = data[idx], g = data[idx + 1], b = data[idx + 2];
    const greenSpill = g - Math.max(r, b);
    if (a < 240 && greenSpill > 10) { data[idx + 3] = 0; continue; }
    data[idx + 3] = a < 128 ? 0 : 255;
  }
}

async function main() {
  const [,, input, output, scaleStr, minXStr, minYStr, maxXStr, maxYStr] = process.argv;
  if (!input) {
    console.log('Uso: node tools/process_single_frame.js <input.png> <output.png> <scale> <minX> <minY> <maxX> <maxY>');
    process.exit(1);
  }

  const scale = parseFloat(scaleStr);
  const minX  = parseInt(minXStr), minY = parseInt(minYStr);
  const maxX  = parseInt(maxXStr), maxY = parseInt(maxYStr);
  const srcW  = maxX - minX + 1;
  const srcH  = maxY - minY + 1;
  const dstW  = Math.round(srcW * scale);
  const dstH  = Math.round(srcH * scale);
  const offX  = Math.floor((CANVAS_W - dstW) / 2);
  const offY  = FOOT_Y - dstH;

  // Aplicar chroma key verde con ffmpeg
  const tempFile = path.join(os.tmpdir(), 'frame_ck_' + Date.now() + '.png');
  execSync(`ffmpeg -y -i "${input}" -vf "colorkey=0x00FF00:0.3:0.1" -pix_fmt rgba "${tempFile}"`, { stdio: 'inherit' });

  const img = await Jimp.read(tempFile);
  img.crop({ x: minX, y: minY, w: srcW, h: srcH });
  img.resize({ w: dstW, h: dstH });
  _cleanEdges(img);

  const canvas = new Jimp({ width: CANVAS_W, height: CANVAS_H, color: 0x00000000 });
  canvas.composite(img, offX, offY);
  await canvas.write(output);

  fs.unlinkSync(tempFile);
  console.log(`Listo → ${output}  (${dstW}x${dstH} @ ${offX},${offY})`);
}

main().catch(console.error);
