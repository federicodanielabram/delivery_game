// Uso: node tools/fix_frames.js
// Re-procesa frames 6,7,8 del walk del mozo con chroma key más agresivo

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

const VIDEO      = 'c:/Users/Titin/Desktop/videos para extraer frames/wal mozo.mp4';
const OUT_FOLDER = 'assets/sprites/enemies/waiter/walk/';
const FRAMES     = [6, 7, 8];

async function fixFrame(frameIdx) {
  const tmp = path.join(os.tmpdir(), `fix_frame_${frameIdx}.png`);
  const vf  = `select=eq(n\\,${frameIdx - 1}),colorkey=0x00FF00:0.3:0.1`;
  execSync(`ffmpeg -y -i "${VIDEO}" -vf "${vf}" -frames:v 1 -pix_fmt rgba -update 1 "${tmp}"`, { stdio: 'pipe' });

  const img = await Jimp.read(tmp);
  img.crop({ x: SRC_MINX, y: SRC_MINY, w: SRC_W, h: SRC_H });
  img.resize({ w: DST_W, h: DST_H });

  const canvas = new Jimp({ width: CANVAS_W, height: CANVAS_H, color: 0x00000000 });
  canvas.composite(img, OFF_X, OFF_Y);

  const outFile = path.join(OUT_FOLDER, `walk___${String(frameIdx).padStart(3, '0')}.png`);
  await canvas.write(outFile);
  console.log(`Guardado: ${outFile}`);
}

async function main() {
  for (const f of FRAMES) await fixFrame(f);
  console.log('Listo.');
}
main().catch(console.error);
