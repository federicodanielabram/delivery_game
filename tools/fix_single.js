// Uso: node tools/fix_single.js <imagen_fuente> <numero_frame>
// Aplica chroma key + crop + scale + posicionamiento y guarda en walk/

const { Jimp } = require('jimp');
const { execSync } = require('child_process');
const path = require('path');
const os = require('os');

const SRC_MINX = 104, SRC_MINY = 42, SRC_W = 802, SRC_H = 1005;
const SCALE    = 0.165;
const OFF_X    = 21;
const CANVAS_W = 200, CANVAS_H = 200;
const FOOT_Y   = 192;
const DST_W    = Math.round(SRC_W * SCALE);
const DST_H    = Math.round(SRC_H * SCALE);
const OFF_Y    = FOOT_Y - DST_H;

const OUT_FOLDER = 'assets/sprites/enemies/waiter/walk/';

function _cleanEdges(img) {
  const data = img.bitmap.data;
  const len  = data.length;
  for (let idx = 0; idx < len; idx += 4) {
    const a = data[idx + 3];
    if (a === 0) continue;
    const r = data[idx];
    const g = data[idx + 1];
    const b = data[idx + 2];
    const greenSpill = g - Math.max(r, b);
    if (a < 240 && greenSpill > 10) { data[idx + 3] = 0; continue; }
    data[idx + 3] = a < 128 ? 0 : 255;
  }
}

async function main() {
  const src       = process.argv[2];
  const frameNum  = process.argv[3];
  if (!src || !frameNum) { console.log('Uso: node tools/fix_single.js <imagen> <numero>'); process.exit(1); }

  const tmp = path.join(os.tmpdir(), `fix_single_${frameNum}.png`);
  execSync(`ffmpeg -y -i "${src}" -vf "colorkey=0x00FF00:0.3:0.1" -frames:v 1 -pix_fmt rgba -update 1 "${tmp}"`, { stdio: 'pipe' });

  const img = await Jimp.read(tmp);
  img.crop({ x: SRC_MINX, y: SRC_MINY, w: SRC_W, h: SRC_H });
  img.resize({ w: DST_W, h: DST_H });
  _cleanEdges(img);

  const canvas = new Jimp({ width: CANVAS_W, height: CANVAS_H, color: 0x00000000 });
  canvas.composite(img, OFF_X, OFF_Y);

  const outFile = path.join(OUT_FOLDER, `walk___${String(frameNum).padStart(3, '0')}.png`);
  await canvas.write(outFile);
  console.log(`Guardado: ${outFile}`);
}
main().catch(console.error);
