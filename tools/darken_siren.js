// Uso: node tools/darken_siren.js <carpeta>
// Apaga los píxeles de la sirena (rojo+azul brillante en el techo del drone)
// dejando intactas las luces de navegación laterales.
// La zona de sirena = top 25% del bounding box del drone en cada frame.

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

const ROOF_FRAC      = 0.25;  // fracción del alto del drone que se considera "techo"
const DIM_FACTOR     = 0.12;  // brillo final (0=negro, 1=sin cambio)
// El bloom de Kling quema los colores a casi-blanco. La estrategia: en la zona del
// techo, el cuerpo del drone es navy oscuro (R+G+B ≈ 190). Todo lo que supere
// BRIGHT_SUM es una fuente de luz (sirena, bloom, glow) y se apaga.
const BRIGHT_SUM     = 220;

function getBbox(data, width, height) {
  let minY = height, maxY = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (data[(y * width + x) * 4 + 3] > 32) {
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return { minY, maxY };
}

async function main() {
  const folder = process.argv[2];
  if (!folder) { console.log('Uso: node tools/darken_siren.js <carpeta>'); process.exit(1); }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  console.log(`Procesando ${files.length} frames...`);

  let totalPixels = 0;

  for (let i = 0; i < files.length; i++) {
    const fpath = path.join(folder, files[i]);
    const img = await Jimp.read(fpath);
    const { width, height } = img.bitmap;
    const data = img.bitmap.data;

    const { minY, maxY } = getBbox(data, width, height);
    const droneH = maxY - minY;
    const roofBottom = Math.round(minY + droneH * ROOF_FRAC);

    let count = 0;
    for (let y = minY; y < roofBottom; y++) {
      for (let x = 0; x < width; x++) {
        const idx = (y * width + x) * 4;
        const R = data[idx], G = data[idx+1], B = data[idx+2], A = data[idx+3];
        if (A < 32) continue;

        if (R + G + B > BRIGHT_SUM) {
          data[idx]   = Math.round(R * DIM_FACTOR);
          data[idx+1] = Math.round(G * DIM_FACTOR);
          data[idx+2] = Math.round(B * DIM_FACTOR);
          count++;
        }
      }
    }

    totalPixels += count;
    await img.write(fpath);
    process.stdout.write(`\r  ${i + 1}/${files.length}  (${count} px apagados en zona Y=${minY}..${roofBottom})`);
  }

  console.log(`\nListo! ${totalPixels} píxeles de sirena apagados en total.`);
}

main().catch(console.error);
