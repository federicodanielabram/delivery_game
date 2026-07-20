// Reemplaza el tono de piel de los sprites del mozo manteniendo la ropa igual.
// Uso: node tools/recolor_skin.js <carpeta_origen> <carpeta_destino> <preset>
// Presets: dark | light

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

// ── Presets ──────────────────────────────────────────────────────────────────
const PRESETS = {
  dark:  { targetH: 22, targetS: 50, lScale: 0.70 },  // piel oscura
  light: { targetH: 14, targetS: 28, lScale: 1.30 },  // piel clara
};

// ── Rango de detección de piel ────────────────────────────────────────────────
const SKIN_H_MIN = 5,  SKIN_H_MAX = 38;
const SKIN_S_MIN = 30, SKIN_S_MAX = 95;
const SKIN_L_MIN = 12, SKIN_L_MAX = 75;

function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h = 0, s = 0, l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
      case g: h = ((b - r) / d + 2) / 6; break;
      case b: h = ((r - g) / d + 4) / 6; break;
    }
  }
  return [h * 360, s * 100, l * 100];
}

function hslToRgb(h, s, l) {
  h /= 360; s /= 100; l /= 100;
  let r, g, b;
  if (s === 0) { r = g = b = l; }
  else {
    const hue2rgb = (p, q, t) => {
      if (t < 0) t += 1; if (t > 1) t -= 1;
      if (t < 1/6) return p + (q - p) * 6 * t;
      if (t < 1/2) return q;
      if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
      return p;
    };
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1/3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1/3);
  }
  return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
}

async function recolorFolder(srcFolder, dstFolder, preset) {
  const p = PRESETS[preset];
  if (!p) { console.error('Preset desconocido:', preset, '— usar: dark | light'); process.exit(1); }

  fs.mkdirSync(dstFolder, { recursive: true });
  const files = fs.readdirSync(srcFolder).filter(f => f.endsWith('.png')).sort();
  console.log(`${files.length} frames → ${dstFolder} [${preset}]`);

  for (let fi = 0; fi < files.length; fi++) {
    const img  = await Jimp.read(path.join(srcFolder, files[fi]));
    const data = img.bitmap.data;
    const len  = data.length;

    for (let idx = 0; idx < len; idx += 4) {
      if (data[idx + 3] < 200) continue;
      const r = data[idx], g = data[idx+1], b = data[idx+2];
      const [h, s, l] = rgbToHsl(r, g, b);

      if (h >= SKIN_H_MIN && h <= SKIN_H_MAX &&
          s >= SKIN_S_MIN && s <= SKIN_S_MAX &&
          l >= SKIN_L_MIN && l <= SKIN_L_MAX) {
        // Preserva la variación de L (sombras y luces) pero cambia H y S
        const newL = Math.min(95, Math.max(8, l * p.lScale));
        const [nr, ng, nb] = hslToRgb(p.targetH, p.targetS, newL);
        data[idx] = nr; data[idx+1] = ng; data[idx+2] = nb;
      }
    }

    await img.write(path.join(dstFolder, files[fi]));
    process.stdout.write(`\r  ${fi + 1}/${files.length}`);
  }
  console.log('\nListo!');
}

async function main() {
  const [,, src, dst, preset] = process.argv;
  if (!src) {
    console.log('Uso: node tools/recolor_skin.js <carpeta_origen> <carpeta_destino> <preset>');
    console.log('Presets: dark | light');
    process.exit(1);
  }
  await recolorFolder(src, dst, preset || 'dark');
}

main().catch(console.error);
