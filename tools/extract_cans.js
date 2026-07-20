// Extrae las 9 latas de la grilla 3x3, saca el fondo verde, recorta y rota a horizontal.
// Uso: node tools/extract_cans.js <imagen> <carpeta_salida>

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

function isGreen(r, g, b) {
  // Verde chroma vivo del fondo: g alto y domina claramente sobre r y b
  return g > 140 && g > r * 1.35 && g > b * 1.35;
}

async function processCell(img, gx, gy, cellW, cellH, outPath) {
  const cell = img.clone().crop({ x: gx * cellW, y: gy * cellH, w: cellW, h: cellH });
  const { width, height } = cell.bitmap;
  const data = cell.bitmap.data;

  // Marcar candidatos verdes
  const green = new Uint8Array(width * height);
  for (let p = 0; p < width * height; p++) {
    const r = data[p * 4], g = data[p * 4 + 1], b = data[p * 4 + 2];
    green[p] = isGreen(r, g, b) ? 1 : 0;
  }

  // Flood fill desde un marco interior (las lineas negras de la grilla estan
  // en la orilla y bloquearian el seed desde el borde exacto). A 'm' px hacia
  // adentro ya es verde puro de fondo.
  const bg = new Uint8Array(width * height);
  const stack = [];
  const m = 12;
  for (let x = m; x < width - m; x++) {
    stack.push(m * width + x);              // fila superior interior
    stack.push((height - 1 - m) * width + x); // fila inferior interior
  }
  for (let y = m; y < height - m; y++) {
    stack.push(y * width + m);             // col izq interior
    stack.push(y * width + width - 1 - m); // col der interior
  }
  while (stack.length) {
    const i = stack.pop();
    if (bg[i] || !green[i]) continue;
    bg[i] = 1;
    const cy = Math.floor(i / width), cx = i % width;
    if (cx > 0)          stack.push(i - 1);
    if (cx < width - 1)  stack.push(i + 1);
    if (cy > 0)          stack.push(i - width);
    if (cy < height - 1) stack.push(i + width);
  }

  // Aplicar transparencia al fondo
  for (let p = 0; p < width * height; p++) {
    if (bg[p]) data[p * 4 + 3] = 0;
  }

  // De-spill: comer el halo verde en el borde con lo transparente (varias pasadas)
  for (let pass = 0; pass < 3; pass++) {
    const toClear = [];
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const p = y * width + x;
        if (data[p * 4 + 3] === 0) continue;
        const r = data[p * 4], g = data[p * 4 + 1], b = data[p * 4 + 2];
        const greenish = g > 90 && g > r * 1.1 && g > b * 1.1;
        if (!greenish) continue;
        // ¿toca algun pixel transparente?
        let touchesBg = false;
        if (x > 0          && data[(p - 1) * 4 + 3] === 0) touchesBg = true;
        if (x < width - 1  && data[(p + 1) * 4 + 3] === 0) touchesBg = true;
        if (y > 0          && data[(p - width) * 4 + 3] === 0) touchesBg = true;
        if (y < height - 1 && data[(p + width) * 4 + 3] === 0) touchesBg = true;
        if (touchesBg) toClear.push(p);
      }
    }
    for (const p of toClear) data[p * 4 + 3] = 0;
  }

  // Conservar solo el componente opaco mas grande (elimina la tira de la grilla)
  const visited = new Uint8Array(width * height);
  let best = null;
  for (let p0 = 0; p0 < width * height; p0++) {
    if (visited[p0] || data[p0 * 4 + 3] === 0) continue;
    const comp = [p0];
    visited[p0] = 1;
    let head = 0;
    while (head < comp.length) {
      const cur = comp[head++];
      const cy = Math.floor(cur / width), cx = cur % width;
      const nb = [];
      if (cx > 0)          nb.push(cur - 1);
      if (cx < width - 1)  nb.push(cur + 1);
      if (cy > 0)          nb.push(cur - width);
      if (cy < height - 1) nb.push(cur + width);
      for (const ni of nb) {
        if (!visited[ni] && data[ni * 4 + 3] > 0) { visited[ni] = 1; comp.push(ni); }
      }
    }
    if (!best || comp.length > best.length) best = comp;
  }
  if (best) {
    const keep = new Uint8Array(width * height);
    for (const p of best) keep[p] = 1;
    for (let p = 0; p < width * height; p++) {
      if (!keep[p]) data[p * 4 + 3] = 0;
    }
  }

  // Bounding box de lo que queda
  let minX = width, minY = height, maxX = 0, maxY = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (data[(y * width + x) * 4 + 3] > 20) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  const pad = 4;
  minX = Math.max(0, minX - pad); minY = Math.max(0, minY - pad);
  maxX = Math.min(width - 1, maxX + pad); maxY = Math.min(height - 1, maxY + pad);
  cell.crop({ x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 });

  // Rotar a horizontal: la lata apunta hacia arriba -> rotar para que apunte a la derecha
  cell.rotate(-90);

  await cell.write(outPath);
  return `${maxX - minX + 1}x${maxY - minY + 1}`;
}

async function main() {
  const [,, imgPath, outFolder] = process.argv;
  if (!imgPath || !outFolder) {
    console.log('Uso: node tools/extract_cans.js <imagen> <carpeta_salida>');
    process.exit(1);
  }
  fs.mkdirSync(outFolder, { recursive: true });
  const img = await Jimp.read(imgPath);
  const cellW = Math.floor(img.width / 3);
  const cellH = Math.floor(img.height / 3);

  let n = 1;
  for (let gy = 0; gy < 3; gy++) {
    for (let gx = 0; gx < 3; gx++) {
      const out = path.join(outFolder, `can_${String(n).padStart(2, '0')}.png`);
      const size = await processCell(img, gx, gy, cellW, cellH, out);
      console.log(`can_${String(n).padStart(2, '0')}.png  (${size})`);
      n++;
    }
  }
  console.log(`\nListo! ${n - 1} latas en ${outFolder}`);
}

main().catch(console.error);
