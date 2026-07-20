// Combina el frame chroma-keyed (transparente) con la edición de Paint:
// borra del frame procesado los píxeles que en Paint quedaron como fondo blanco puro
// pero que NO eran fondo en el original (es decir, los que el usuario pintó de blanco).
// Uso: node tools/apply_paint_mask.js <frame_procesado> <frame_paint> <output>

const { Jimp } = require('jimp');

async function main() {
  const [,,proc, paint, out] = process.argv;
  if (!proc) { console.log('Uso: node tools/apply_paint_mask.js <procesado> <paint> <output>'); process.exit(1); }

  const imgProc  = await Jimp.read(proc);
  const imgPaint = await Jimp.read(paint);

  const W = imgProc.bitmap.width;
  const H = imgProc.bitmap.height;
  const dp = imgProc.bitmap.data;
  const dm = imgPaint.bitmap.data;

  // Borra píxeles opacos en el frame procesado donde Paint puso blanco puro (>240 R,G,B)
  let removed = 0;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const idx = (y * W + x) * 4;
      const pr = dm[idx], pg = dm[idx+1], pb = dm[idx+2];
      // Si Paint lo dejó casi blanco → el usuario lo borró
      if (pr > 240 && pg > 240 && pb > 240) {
        dp[idx + 3] = 0;
        removed++;
      }
    }
  }

  console.log(`Píxeles borrados: ${removed}`);
  await imgProc.write(out);
  console.log('Listo →', out);
}

main().catch(console.error);
