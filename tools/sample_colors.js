// Muestra los colores más frecuentes de un frame para identificar piel/pelo.
// Uso: node tools/sample_colors.js <imagen.png>

const { Jimp } = require('jimp');

function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h, s, l = (max + min) / 2;
  if (max === min) { h = s = 0; }
  else {
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

async function main() {
  const img = await Jimp.read(process.argv[2]);
  const W = img.bitmap.width, H = img.bitmap.height;
  const data = img.bitmap.data;
  const buckets = {};

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const idx = (y * W + x) * 4;
      if (data[idx + 3] < 200) continue;
      const r = data[idx], g = data[idx+1], b = data[idx+2];
      const [h, s, l] = rgbToHsl(r, g, b);
      // Agrupamos en cubos de 10 para hue, 10 para sat, 10 para lum
      const key = `H${Math.round(h/10)*10} S${Math.round(s/10)*10} L${Math.round(l/10)*10}`;
      buckets[key] = (buckets[key] || 0) + 1;
    }
  }

  const sorted = Object.entries(buckets).sort((a, b) => b[1] - a[1]).slice(0, 20);
  console.log('Top 20 colores (HSL agrupado):');
  for (const [key, count] of sorted) {
    console.log(`  ${key}  →  ${count}px`);
  }
}

main().catch(console.error);
