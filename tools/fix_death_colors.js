// Reduce saturación de los death frames para igualar el look de walk/throw.
// Crea backup en death_backup/ antes de sobreescribir.

const { Jimp } = require("jimp");
const path = require("path");
const fs   = require("fs");

const DEATH_FOLDERS = [
  "C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\waiter\\death",
  "C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\waiter_dark\\death",
  "C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\waiter_light\\death",
];

// 0.0 = escala de grises completa, 1.0 = sin cambio
const SAT_FACTOR = 0.60;

function hue2rgb(p, q, t) {
  if (t < 0) t += 1;
  if (t > 1) t -= 1;
  if (t < 1 / 6) return p + (q - p) * 6 * t;
  if (t < 1 / 2) return q;
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
  return p;
}

async function processFolder(folder) {
  const files = fs.readdirSync(folder)
    .filter(f => f.endsWith(".png") && !f.includes(".import"));

  const backup = path.join(folder, "death_backup");
  if (!fs.existsSync(backup)) fs.mkdirSync(backup);

  for (const file of files) {
    const src = path.join(folder, file);
    // backup
    fs.copyFileSync(src, path.join(backup, file));

    const img = await Jimp.read(src);

    img.scan(0, 0, img.bitmap.width, img.bitmap.height, function (x, y, idx) {
      const a = this.bitmap.data[idx + 3];
      if (a === 0) return;

      const r = this.bitmap.data[idx]     / 255;
      const g = this.bitmap.data[idx + 1] / 255;
      const b = this.bitmap.data[idx + 2] / 255;

      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      const l   = (max + min) / 2;
      let h = 0, s = 0;

      if (max !== min) {
        const d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        switch (max) {
          case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
          case g: h = ((b - r) / d + 2) / 6;               break;
          case b: h = ((r - g) / d + 4) / 6;               break;
        }
      }

      const ns = s * SAT_FACTOR;

      let nr, ng, nb;
      if (ns === 0) {
        nr = ng = nb = l;
      } else {
        const q2 = l < 0.5 ? l * (1 + ns) : l + ns - l * ns;
        const p2 = 2 * l - q2;
        nr = hue2rgb(p2, q2, h + 1 / 3);
        ng = hue2rgb(p2, q2, h);
        nb = hue2rgb(p2, q2, h - 1 / 3);
      }

      this.bitmap.data[idx]     = Math.round(nr * 255);
      this.bitmap.data[idx + 1] = Math.round(ng * 255);
      this.bitmap.data[idx + 2] = Math.round(nb * 255);
    });

    await img.write(src);
    console.log("OK:", path.relative(process.cwd(), src));
  }
}

(async () => {
  for (const folder of DEATH_FOLDERS) {
    console.log("\n→", folder);
    await processFolder(folder);
  }
  console.log("\nListo. Backups en death_backup/ dentro de cada carpeta.");
})().catch(console.error);
