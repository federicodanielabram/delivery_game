// Ajuste HSL a todos los PNGs de una carpeta (solo pixels opacos).
// Uso: node tools/hsl_adjust.js <carpeta> [satFactor] [lightFactor] [hueShiftDeg]
// Sube saturacion/brillo sin tintar los negros (a diferencia del multiply por canal).

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h = 0, s = 0; const l = (max + min) / 2;
  const d = max - min;
  if (d !== 0) {
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
    }
    h /= 6;
  }
  return [h, s, l];
}

function hue2rgb(p, q, t) {
  if (t < 0) t += 1;
  if (t > 1) t -= 1;
  if (t < 1 / 6) return p + (q - p) * 6 * t;
  if (t < 1 / 2) return q;
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
  return p;
}

function hslToRgb(h, s, l) {
  let r, g, b;
  if (s === 0) { r = g = b = l; }
  else {
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }
  return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
}

async function main() {
  const folder   = process.argv[2];
  const satF     = parseFloat(process.argv[3] ?? '1.25');
  const lightF   = parseFloat(process.argv[4] ?? '1.05');
  const hueShift = parseFloat(process.argv[5] ?? '0') / 360.0;
  if (!folder) { console.log('Uso: node tools/hsl_adjust.js <carpeta> [sat] [light] [hueDeg]'); process.exit(1); }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  console.log(`HSL — sat×${satF} light×${lightF} hue+${hueShift * 360}°  (${files.length} frames)`);

  for (let i = 0; i < files.length; i++) {
    const fpath = path.join(folder, files[i]);
    const img   = await Jimp.read(fpath);
    const data  = img.bitmap.data;
    for (let idx = 0; idx < data.length; idx += 4) {
      if (data[idx + 3] < 255) continue;
      let [h, s, l] = rgbToHsl(data[idx], data[idx + 1], data[idx + 2]);
      h = (h + hueShift) % 1; if (h < 0) h += 1;
      s = Math.min(1, s * satF);
      l = Math.min(1, l * lightF);
      const [r, g, b] = hslToRgb(h, s, l);
      data[idx] = r; data[idx + 1] = g; data[idx + 2] = b;
    }
    await img.write(fpath);
    process.stdout.write(`\r  ${i + 1}/${files.length}`);
  }
  console.log('\nListo!');
}
main().catch(console.error);
