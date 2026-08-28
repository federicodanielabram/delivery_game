// Extrae los 9 autos traseros del spritesheet 3x3 con fondo morado
// Salida: assets/sprites/cars/frames/frame_00.png .. frame_08.png

const { Jimp } = require('jimp');
const path = require('path');
const fs   = require('fs');

const SRC  = 'c:/Users/Titin/Downloads/ChatGPT Image 3 ago 2026, 03_09_55 a.m..png';
const DEST = 'assets/sprites/cars/frames';

// Referencia de fondo: purpura saturado
const BG_R = 165, BG_G = 22, BG_B = 185;
const BG_THRESH = 55; // distancia euclidea al fondo

function isBg(r, g, b) {
  // Distancia al color de fondo
  const dr = r - BG_R, dg = g - BG_G, db = b - BG_B;
  if (Math.sqrt(dr*dr + dg*dg + db*db) < BG_THRESH) return true;
  // También eliminar sombras (morado oscuro): alta saturacion purpura, valor bajo
  // Sat purpura: B y R altos relativo a G
  const maxC = Math.max(r, g, b);
  const minC = Math.min(r, g, b);
  const sat = maxC > 0 ? (maxC - minC) / maxC : 0;
  // Hue purpura: R>G, B>G, B>R o similar
  if (sat > 0.35 && b > g * 2.0 && r > g * 1.5 && maxC < 160) return true;
  return false;
}

(async () => {
  fs.mkdirSync(DEST, { recursive: true });

  const src  = await Jimp.read(SRC);
  const W    = src.bitmap.width;
  const H    = src.bitmap.height;
  const data = src.bitmap.data;

  // Crear máscara de fondo eliminado
  const mask = new Uint8Array(W * H); // 1 = opaco (auto), 0 = fondo
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = (y * W + x) * 4;
      mask[y * W + x] = isBg(data[i], data[i+1], data[i+2]) ? 0 : 1;
    }
  }

  // Densidad horizontal y vertical para detectar gaps
  const colDens = new Float32Array(W);
  const rowDens = new Float32Array(H);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++)
      if (mask[y * W + x]) { colDens[x]++; rowDens[y]++; }

  // Encontrar 2 separadores de columna → 3 columnas
  // Suavizar densidad
  function findGaps(dens, n, count) {
    const smooth = new Float32Array(n);
    const K = 6;
    for (let i = K; i < n - K; i++) {
      let s = 0;
      for (let k = -K; k <= K; k++) s += dens[i + k];
      smooth[i] = s / (2 * K + 1);
    }
    // Candidatos a gap: densidad por debajo del umbral
    const maxDens = Math.max(...smooth);
    const threshold = maxDens * 0.04;
    const gaps = [];
    let inGap = false, gapStart = 0;
    for (let i = 0; i < n; i++) {
      if (smooth[i] <= threshold && !inGap) { inGap = true; gapStart = i; }
      else if (smooth[i] > threshold && inGap) {
        gaps.push(Math.round((gapStart + i) / 2));
        inGap = false;
      }
    }
    if (inGap) gaps.push(Math.round((gapStart + n) / 2));
    // Filtrar gaps muy al borde (primeros/ultimos 5%)
    const margin = Math.round(n * 0.05);
    const filtered = gaps.filter(g => g > margin && g < n - margin);
    // Si hay más gaps de los esperados, tomar los más centrados (mayor separacion)
    if (filtered.length > count) {
      filtered.sort((a, b) => a - b);
      // Tomar los más equidistantes
      const step = n / (count + 1);
      const chosen = [];
      for (let c = 0; c < count; c++) {
        const target = step * (c + 1);
        let best = filtered[0], bestDist = Infinity;
        for (const g of filtered) {
          const d = Math.abs(g - target);
          if (d < bestDist) { bestDist = d; best = g; }
        }
        chosen.push(best);
      }
      return chosen.sort((a, b) => a - b);
    }
    return filtered.sort((a, b) => a - b);
  }

  const colGaps = findGaps(colDens, W, 2); // 2 separadores → 3 columnas
  const rowGaps = findGaps(rowDens, H, 2); // 2 separadores → 3 filas

  console.log('Col gaps:', colGaps);
  console.log('Row gaps:', rowGaps);

  if (colGaps.length !== 2 || rowGaps.length !== 2) {
    console.error('No se detectaron los 6 bordes esperados. Ajustar parámetros.');
    process.exit(1);
  }

  const colBounds = [0, colGaps[0], colGaps[1], W];
  const rowBounds = [0, rowGaps[0], rowGaps[1], H];

  let frameIdx = 0;
  for (let row = 0; row < 3; row++) {
    for (let col = 0; col < 3; col++) {
      const x0 = colBounds[col];
      const x1 = colBounds[col + 1];
      const y0 = rowBounds[row];
      const y1 = rowBounds[row + 1];
      const cw = x1 - x0;
      const ch = y1 - y0;

      // Encontrar bounding box del auto dentro de la celda
      let minX = cw, maxX = 0, minY = ch, maxY = 0;
      for (let y = 0; y < ch; y++) {
        for (let x = 0; x < cw; x++) {
          if (mask[(y0 + y) * W + (x0 + x)]) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      if (maxX < minX) { console.log(`frame_${frameIdx}: vacío`); frameIdx++; continue; }

      const fw = maxX - minX + 1;
      const fh = maxY - minY + 1;
      const dst = new Jimp({ width: fw, height: fh, color: 0x00000000 });
      const dstData = dst.bitmap.data;

      for (let y = 0; y < fh; y++) {
        for (let x = 0; x < fw; x++) {
          const sx = x0 + minX + x;
          const sy = y0 + minY + y;
          const si = (sy * W + sx) * 4;
          const di = (y * fw + x) * 4;
          if (mask[sy * W + sx]) {
            dstData[di]   = data[si];
            dstData[di+1] = data[si+1];
            dstData[di+2] = data[si+2];
            dstData[di+3] = 255;
          }
        }
      }

      const outFile = path.join(DEST, `frame_${String(frameIdx).padStart(2,'0')}.png`);
      await dst.write(outFile);
      console.log(`frame_${String(frameIdx).padStart(2,'0')}: ${fw}x${fh} (celda ${row},${col})`);
      frameIdx++;
    }
  }

  console.log('Listo. 9 frames guardados en', DEST);
})().catch(console.error);
