// Uso: node tools/color_correct.js <carpeta> [rFactor] [gFactor] [bFactor] [--red-only]
// Aplica corrección de color multiplicativa por canal a todos los PNGs de una carpeta.
// Solo afecta pixels opacos (alpha=255). Defaults: r=0.86 g=0.93 b=1.02
// --red-only: corrige solo pixels donde el rojo es dominante (hoodie/mochila),
//             dejando negros y grises intactos.

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

async function main() {
  const folder  = process.argv[2];
  const rFactor = parseFloat(process.argv[3] ?? '0.86');
  const gFactor = parseFloat(process.argv[4] ?? '0.93');
  const bFactor = parseFloat(process.argv[5] ?? '1.02');
  const redOnly = process.argv.includes('--red-only');

  if (!folder) { console.log('Uso: node tools/color_correct.js <carpeta> [r] [g] [b] [--red-only]'); process.exit(1); }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  console.log(`Corrigiendo ${files.length} frames — R×${rFactor} G×${gFactor} B×${bFactor}${redOnly ? ' (solo rojos)' : ''}`);

  for (let i = 0; i < files.length; i++) {
    const fpath = path.join(folder, files[i]);
    const img   = await Jimp.read(fpath);
    const data  = img.bitmap.data;

    for (let idx = 0; idx < data.length; idx += 4) {
      if (data[idx + 3] < 255) continue;
      if (redOnly) {
        const R = data[idx], G = data[idx + 1], B = data[idx + 2];
        // Solo rojo SATURADO (hoodie/mochila): ratio alto R vs G,B.
        // Excluye la piel (rojo-dominante pero con verde/azul altos).
        if (!(R > 60 && R > G * 2.5 && R > B * 2.5)) continue;
      }
      data[idx]     = Math.min(255, Math.round(data[idx]     * rFactor));
      data[idx + 1] = Math.min(255, Math.round(data[idx + 1] * gFactor));
      data[idx + 2] = Math.min(255, Math.round(data[idx + 2] * bFactor));
    }

    await img.write(fpath);
    process.stdout.write(`\r  ${i + 1}/${files.length}`);
  }
  console.log('\nListo!');
}
main().catch(console.error);
