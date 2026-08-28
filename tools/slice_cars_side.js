// Uso: node tools/slice_cars_side.js <src> <output_dir> [--padding <px>]
// Detecta autos en fondo magenta, exporta cada uno en canvas normalizado
// (mismo tamaño para todos), centrado horizontalmente y alineado al fondo.

const { Jimp } = require('jimp');
const path = require('path');
const fs   = require('fs');

async function main() {
  const src    = process.argv[2];
  const outDir = process.argv[3];
  const padIdx = process.argv.indexOf('--padding');
  const PADDING = padIdx >= 0 ? parseInt(process.argv[padIdx + 1]) : 16;

  if (!src || !outDir) {
    console.log('Uso: node tools/slice_cars_side.js <src> <output_dir> [--padding <px>]');
    process.exit(1);
  }

  fs.mkdirSync(outDir, { recursive: true });

  const img  = await Jimp.read(src);
  const data = img.bitmap.data;
  const W    = img.bitmap.width;
  const H    = img.bitmap.height;

  // Paso 1: eliminar fondo magenta (R alto, B alto, G bajo)
  const alpha = new Uint8Array(W * H); // 1 = píxel del auto
  for (let i = 0; i < W * H; i++) {
    const r = data[i*4], g = data[i*4+1], b = data[i*4+2];
    if (r > g * 1.8 && b > g * 1.5 && r > 90 && b > 70) {
      data[i*4+3] = 0;
      alpha[i] = 0;
    } else if (r > g * 1.3 && b > g * 1.2 && r > 60) {
      const blend = Math.min((r / (g * 1.3) - 1) / 0.5, 1.0);
      data[i*4+3] = Math.round(data[i*4+3] * (1 - blend));
      data[i*4]   = Math.round(Math.min(r, g * 1.25));
      data[i*4+2] = Math.round(Math.min(b, g * 1.25));
      alpha[i] = data[i*4+3] > 10 ? 1 : 0;
    } else {
      alpha[i] = 1;
    }
  }

  // Densidad por fila
  function rowDensity() {
    const d = new Int32Array(H);
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++)
        if (alpha[y * W + x]) d[y]++;
    return d;
  }

  // Densidad por columna dentro de un rango de filas
  function colDensityInRange(y0, y1) {
    const d = new Int32Array(W);
    for (let x = 0; x < W; x++)
      for (let y = y0; y <= y1; y++)
        if (alpha[y * W + x]) d[x]++;
    return d;
  }

  // Convierte densidades en bandas [inicio, fin]
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
      if (merged.length && b[0] - merged[merged.length - 1][1] <= gap)
        merged[merged.length - 1][1] = b[1];
      else
        merged.push([...b]);
    }
    return merged.filter(b => b[1] - b[0] + 1 >= minSize);
  }

  // Paso 2: detectar bounding box de cada auto
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
          if (alpha[y * W + x]) {
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

  // Paso 3: calcular canvas normalizado
  const maxCarW  = Math.max(...boxes.map(b => b.maxX - b.minX + 1));
  const maxCarH  = Math.max(...boxes.map(b => b.maxY - b.minY + 1));
  const canvasW  = maxCarW + PADDING * 2;
  const canvasH  = maxCarH + PADDING * 2;

  console.log(`\nCanvas normalizado: ${canvasW}×${canvasH}px  (padding=${PADDING})`);
  console.log(`Auto más ancho: ${maxCarW}px  |  Auto más alto: ${maxCarH}px`);

  // Paso 4: exportar cada auto centrado horizontalmente, alineado al fondo
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
        if (data[si + 3] < 10) continue;
        const di = ((destY + y) * canvasW + (destX + x)) * 4;
        canvasData[di]     = data[si];
        canvasData[di + 1] = data[si + 1];
        canvasData[di + 2] = data[si + 2];
        canvasData[di + 3] = data[si + 3];
      }
    }

    const outPath = path.join(outDir, `car_side_${String(i).padStart(2, '0')}.png`);
    await canvas.write(outPath);
    console.log(`  car_side_${String(i).padStart(2, '0')}: ${carW}×${carH}px → canvas ${canvasW}×${canvasH}`);
  }

  console.log(`\n✓ ${boxes.length} autos guardados en ${outDir}`);
}

main().catch(e => { console.error(e); process.exit(1); });
