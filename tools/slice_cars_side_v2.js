// Uso: node tools/slice_cars_side_v2.js <src> <output_dir> [--thresh <n>] [--padding <px>]
// Flood-fill desde los 4 bordes: elimina el magenta externo tocando los bordes del auto.
// Suaviza la transición borde-auto y hace despill del tinte magenta en los píxeles de borde.

const { Jimp } = require('jimp');
const path = require('path');
const fs   = require('fs');

const DEFAULT_THRESH  = 50;  // min(R,B)-G > thresh → magenta
const DEFAULT_PADDING = 16;
const DEFAULT_DESPILL = 0.6; // 0=sin despill, 1=despill completo en todo el auto

async function main() {
  const src    = process.argv[2];
  const outDir = process.argv[3];
  const thIdx  = process.argv.indexOf('--thresh');
  const padIdx = process.argv.indexOf('--padding');
  const dsIdx  = process.argv.indexOf('--despill');
  const THRESH  = thIdx  >= 0 ? parseInt(process.argv[thIdx  + 1])   : DEFAULT_THRESH;
  const PADDING = padIdx >= 0 ? parseInt(process.argv[padIdx + 1])   : DEFAULT_PADDING;
  const DESPILL = dsIdx  >= 0 ? parseFloat(process.argv[dsIdx + 1]) : DEFAULT_DESPILL;

  if (!src || !outDir) {
    console.log('Uso: node tools/slice_cars_side_v2.js <src> <output_dir> [--thresh <n>] [--padding <px>]');
    process.exit(1);
  }

  fs.mkdirSync(outDir, { recursive: true });

  const img  = await Jimp.read(src);
  const data = img.bitmap.data;
  const W    = img.bitmap.width;
  const H    = img.bitmap.height;

  function magentaness(i) {
    return Math.min(data[i], data[i+2]) - data[i+1]; // min(R,B) - G
  }

  // === PASO 1: Flood fill BFS desde todos los bordes ===
  // mask: 0=fondo (magenta externo), 1=auto, 255=sin visitar
  const mask  = new Uint8Array(W * H).fill(255);
  const queue = new Int32Array(W * H * 2); // [x, y, x, y, ...]
  let qHead = 0, qTail = 0;

  function seed(x, y) {
    const idx = y * W + x;
    if (mask[idx] !== 255) return;
    const pi = idx * 4;
    if (magentaness(pi) > THRESH) {
      mask[idx] = 0;
      queue[qTail++] = x;
      queue[qTail++] = y;
    } else {
      mask[idx] = 1;
    }
  }

  for (let x = 0; x < W; x++) { seed(x, 0); seed(x, H-1); }
  for (let y = 1; y < H-1; y++) { seed(0, y); seed(W-1, y); }

  const DX = [-1, 1,  0, 0];
  const DY = [ 0, 0, -1, 1];

  while (qHead < qTail) {
    const x = queue[qHead++];
    const y = queue[qHead++];
    for (let d = 0; d < 4; d++) {
      const nx = x + DX[d], ny = y + DY[d];
      if (nx < 0 || nx >= W || ny < 0 || ny >= H) continue;
      const ni = ny * W + nx;
      if (mask[ni] !== 255) continue;
      const pi = ni * 4;
      if (magentaness(pi) > THRESH) {
        mask[ni] = 0;
        queue[qTail++] = nx;
        queue[qTail++] = ny;
      } else {
        mask[ni] = 1;
      }
    }
  }

  // Píxeles sin visitar = interior del auto encerrado → auto
  for (let i = 0; i < W * H; i++) {
    if (mask[i] === 255) mask[i] = 1;
  }

  // === PASO 2: Aplicar alpha + despill ===
  // El despill se aplica a TODOS los píxeles del auto, no solo los del borde.
  // Calcula cuánto "tinte magenta" tiene cada píxel y lo reduce proporcionalmente.
  // Los neones genuinamente magenta/violeta también se ven afectados (intencional:
  // si el spill es global, el despill también debe serlo).
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i  = y * W + x;
      const pi = i * 4;

      if (mask[i] === 0) {
        data[pi+3] = 0;
        continue;
      }

      // Chequear si es píxel de borde (adyacente al fondo) para suavizar alpha
      let adjBg = false;
      for (let d = 0; d < 4; d++) {
        const nx = x + DX[d], ny = y + DY[d];
        if (nx < 0 || nx >= W || ny < 0 || ny >= H) continue;
        if (mask[ny * W + nx] === 0) { adjBg = true; break; }
      }

      const r  = data[pi], g = data[pi+1], b = data[pi+2];
      const mg = Math.min(r, b) - g; // magentaness

      // Alpha en borde: suavizar según cuánto magenta queda
      if (adjBg && mg > 0) {
        const t = Math.min(mg / THRESH, 1.0);
        data[pi+3] = Math.round(255 * (1 - t));
      }

      // Despill global: si el píxel tiene tinte magenta, reducir R y B
      if (mg > 0 && DESPILL > 0) {
        const remove = mg * DESPILL;
        data[pi]   = Math.max(0, Math.round(r - remove));
        data[pi+2] = Math.max(0, Math.round(b - remove));
      }

      // Islotes magenta (sombras del fondo, glows): eliminar globalmente.
      if (mg > 40) {
        data[pi+3] = Math.round(255 * Math.max(0, 1 - (mg - 40) / 60));
      }
    }
  }

  // === PASO 3: Detectar bounding boxes de cada auto ===
  function rowDensity() {
    const d = new Int32Array(H);
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++)
        if (mask[y * W + x] === 1) d[y]++;
    return d;
  }

  function colDensityInRange(y0, y1) {
    const d = new Int32Array(W);
    for (let x = 0; x < W; x++)
      for (let y = y0; y <= y1; y++)
        if (mask[y * W + x] === 1) d[x]++;
    return d;
  }

  function toBands(density, gap, minSize) {
    const n = density.length;
    const raw = [];
    let start = -1;
    for (let i = 0; i <= n; i++) {
      const filled = i < n && density[i] >= 1;
      if (filled && start === -1) start = i;
      else if (!filled && start !== -1) { raw.push([start, i - 1]); start = -1; }
    }
    const merged = [];
    for (const b of raw) {
      if (merged.length && b[0] - merged[merged.length-1][1] <= gap)
        merged[merged.length-1][1] = b[1];
      else
        merged.push([...b]);
    }
    return merged.filter(b => b[1] - b[0] + 1 >= minSize);
  }

  const rDens    = rowDensity();
  const rowBands = toBands(rDens, 8, 20);
  console.log(`Filas detectadas: ${rowBands.length}`);

  const boxes = [];
  for (const [ry0, ry1] of rowBands) {
    const cDens    = colDensityInRange(ry0, ry1);
    const carBands = toBands(cDens, 12, 20);
    console.log(`  Fila y=${ry0}..${ry1} → ${carBands.length} autos`);
    for (const [cx0, cx1] of carBands) {
      let minX = cx1, maxX = cx0, minY = ry1, maxY = ry0;
      for (let y = ry0; y <= ry1; y++) {
        for (let x = cx0; x <= cx1; x++) {
          if (mask[y * W + x] === 1) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      boxes.push({ minX, minY, maxX, maxY });
    }
  }

  // === PASO 4: Exportar en canvas normalizado (bottom-aligned) ===
  const maxCarW = Math.max(...boxes.map(b => b.maxX - b.minX + 1));
  const maxCarH = Math.max(...boxes.map(b => b.maxY - b.minY + 1));
  const canvasW = maxCarW + PADDING * 2;
  const canvasH = maxCarH + PADDING * 2;

  console.log(`\nCanvas normalizado: ${canvasW}×${canvasH}px  (padding=${PADDING})`);

  for (let i = 0; i < boxes.length; i++) {
    const b    = boxes[i];
    const carW = b.maxX - b.minX + 1;
    const carH = b.maxY - b.minY + 1;

    const canvas     = new Jimp({ width: canvasW, height: canvasH, color: 0x00000000 });
    const canvasData = canvas.bitmap.data;

    const destX = Math.round((canvasW - carW) / 2);
    const destY = canvasH - carH - PADDING; // bottom-aligned

    for (let y = 0; y < carH; y++) {
      for (let x = 0; x < carW; x++) {
        const si = ((b.minY + y) * W + (b.minX + x)) * 4;
        if (data[si+3] < 4) continue;
        const di = ((destY + y) * canvasW + (destX + x)) * 4;
        canvasData[di]   = data[si];
        canvasData[di+1] = data[si+1];
        canvasData[di+2] = data[si+2];
        canvasData[di+3] = data[si+3];
      }
    }

    const outPath = path.join(outDir, `car_side_${String(i).padStart(2, '0')}.png`);
    await canvas.write(outPath);
    console.log(`  car_side_${String(i).padStart(2,'0')}: ${carW}×${carH}px → ${canvasW}×${canvasH}`);
  }

  console.log(`\n✓ ${boxes.length} autos guardados en ${outDir}`);
}

main().catch(e => { console.error(e); process.exit(1); });
