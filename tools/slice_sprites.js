// Uso: node tools/slice_sprites.js <src> <output_dir>
// Detecta automáticamente las filas y columnas de autos buscando bandas de fondo.
// No asume grilla fija — funciona aunque los autos no estén centrados en su celda.

const { Jimp } = require('jimp');
const path = require('path');
const fs = require('fs');

async function main() {
  const src    = process.argv[2];
  const outDir = process.argv[3];

  if (!src || !outDir) {
    console.log('Uso: node tools/slice_sprites.js <src> <output_dir>');
    process.exit(1);
  }

  fs.mkdirSync(outDir, { recursive: true });

  const img  = await Jimp.read(src);
  const data = img.bitmap.data;
  const W    = img.bitmap.width;
  const H    = img.bitmap.height;

  // Paso 1: sacar fondo magenta
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i+1], b = data[i+2];
    if (r > g * 1.8 && b > g * 1.5 && r > 90 && b > 70) {
      data[i+3] = 0;
    } else if (r > g * 1.3 && b > g * 1.2 && r > 60) {
      data[i]   = Math.round(Math.min(r, g * 1.25));
      data[i+2] = Math.round(Math.min(b, g * 1.25));
    }
  }

  // Cuenta píxeles no-transparentes por fila y por columna
  function rowDensity() {
    const d = new Int32Array(H);
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++)
        if (data[(y * W + x) * 4 + 3] > 10) d[y]++;
    return d;
  }

  function colDensityInRange(y0, y1) {
    const d = new Int32Array(W);
    for (let x = 0; x < W; x++)
      for (let y = y0; y <= y1; y++)
        if (data[(y * W + x) * 4 + 3] > 10) d[x]++;
    return d;
  }

  // Convierte un array de densidades en bandas [inicio, fin] con contenido.
  // gap: fusiona bandas separadas por <= gap píxeles vacíos (cierra huecos internos).
  // minSize: descarta bandas más chicas (ruido).
  function toBands(density, gap, minSize) {
    const n = density.length;
    const THRESH = 1;
    const raw = [];
    let start = -1;
    for (let i = 0; i <= n; i++) {
      const filled = i < n && density[i] >= THRESH;
      if (filled && start === -1) start = i;
      else if (!filled && start !== -1) { raw.push([start, i - 1]); start = -1; }
    }

    // Fusionar bandas cercanas
    const merged = [];
    for (const b of raw) {
      if (merged.length && b[0] - merged[merged.length-1][1] <= gap) {
        merged[merged.length-1][1] = b[1];
      } else {
        merged.push([...b]);
      }
    }

    // Filtrar ruido
    return merged.filter(b => b[1] - b[0] + 1 >= minSize);
  }

  // Paso 2: detectar filas de autos
  const rDens = rowDensity();
  const rowBands = toBands(rDens, 8, 20);
  console.log(`Filas detectadas: ${rowBands.length}`);

  let idx = 0;
  for (const [ry0, ry1] of rowBands) {
    // Paso 3: detectar autos individuales dentro de la fila
    const cDens = colDensityInRange(ry0, ry1);
    const carBands = toBands(cDens, 12, 20);
    console.log(`  Fila y=${ry0}..${ry1} → ${carBands.length} autos`);

    for (const [cx0, cx1] of carBands) {
      // Bounding box exacto dentro de la región detectada
      let minX = cx1, maxX = cx0, minY = ry1, maxY = ry0;
      for (let y = ry0; y <= ry1; y++) {
        for (let x = cx0; x <= cx1; x++) {
          if (data[(y * W + x) * 4 + 3] > 10) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      const cropW = maxX - minX + 1;
      const cropH = maxY - minY + 1;
      const cropped = await img.clone().crop({ x: minX, y: minY, w: cropW, h: cropH });
      const outPath = path.join(outDir, `frame_${String(idx).padStart(2,'0')}.png`);
      await cropped.write(outPath);
      console.log(`    frame_${String(idx).padStart(2,'0')}: ${cropW}×${cropH}px`);
      idx++;
    }
  }

  console.log(`✓ ${idx} frames guardados en ${outDir}`);
}

main().catch(e => { console.error(e); process.exit(1); });
