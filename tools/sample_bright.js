const { Jimp } = require("jimp");
const path = require("path");

async function sampleBright(imgPath, minBrightness = 180) {
  const img = await Jimp.read(imgPath);
  let rSum = 0, gSum = 0, bSum = 0, count = 0;
  img.scan(0, 0, img.bitmap.width, img.bitmap.height, (x, y, idx) => {
    const a = img.bitmap.data[idx + 3];
    if (a < 240) return;
    const r = img.bitmap.data[idx];
    const g = img.bitmap.data[idx + 1];
    const b = img.bitmap.data[idx + 2];
    const brightness = (r + g + b) / 3;
    if (brightness >= minBrightness) {
      rSum += r; gSum += g; bSum += b; count++;
    }
  });
  if (count === 0) return null;
  return { r: rSum/count, g: gSum/count, b: bSum/count, count };
}

async function main() {
  const walkFiles = [5, 10, 15, 20, 25, 30].map(i =>
    `assets/sprites/enemies/waiter/walk/walk___${String(i).padStart(3,'0')}.png`);
  const hurtFiles = [5, 10, 15, 20, 25, 30].map(i =>
    `assets/sprites/enemies/waiter/hurt/hurt____${String(i).padStart(3,'0')}.png`);

  let walkR=0, walkG=0, walkB=0, walkN=0;
  let hurtR=0, hurtG=0, hurtB=0, hurtN=0;

  for (const f of walkFiles) {
    const s = await sampleBright(f);
    if (s) { walkR += s.r * s.count; walkG += s.g * s.count; walkB += s.b * s.count; walkN += s.count; }
  }
  for (const f of hurtFiles) {
    const s = await sampleBright(f);
    if (s) { hurtR += s.r * s.count; hurtG += s.g * s.count; hurtB += s.b * s.count; hurtN += s.count; }
  }

  walkR /= walkN; walkG /= walkN; walkB /= walkN;
  hurtR /= hurtN; hurtG /= hurtN; hurtB /= hurtN;

  console.log(`Walk bright pixels: R=${walkR.toFixed(1)} G=${walkG.toFixed(1)} B=${walkB.toFixed(1)} (${walkN}px)`);
  console.log(`Hurt bright pixels: R=${hurtR.toFixed(1)} G=${hurtG.toFixed(1)} B=${hurtB.toFixed(1)} (${hurtN}px)`);
  console.log(`Corrección:        R×${(walkR/hurtR).toFixed(3)} G×${(walkG/hurtG).toFixed(3)} B×${(walkB/hurtB).toFixed(3)}`);
}

main().catch(console.error);
