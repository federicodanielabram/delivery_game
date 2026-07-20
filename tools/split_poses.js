// Separa las poses individuales de un pose sheet y las guarda con padding para Kling
// Uso: node tools/split_poses.js <imagen_sheet> <nombres_poses_separados_por_coma>

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

const OUT_W = 1080;
const OUT_H = 1920;

// Verde puro del fondo (para detectar separadores de columna)
function isPureGreen(r, g, b) {
  return g > 180 && r < 100 && b < 100;
}

// Verde agresivo (para eliminar también los bordes de celda más claros)
function isAnyGreen(r, g, b) {
  return g > r * 1.4 && g > b * 1.4 && g > 80;
}

async function main() {
  const [,, sheetPath, namesArg] = process.argv;
  if (!sheetPath || !namesArg) {
    console.log('Uso: node tools/split_poses.js <sheet> <nombre1,nombre2,...>');
    process.exit(1);
  }

  const names = namesArg.split(',').map(n => n.trim());

  // Leer imagen original (sin modificar) para detección de separadores
  const original = await Jimp.read(sheetPath);
  const { width, height } = original.bitmap;
  console.log(`Sheet: ${width}x${height}px, ${names.length} poses esperadas`);

  // Imagen limpia para recortes: eliminar TODO lo verde (fondo + bordes de celda)
  const clean = original.clone();
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = (y * width + x) * 4;
      const r = clean.bitmap.data[idx];
      const g = clean.bitmap.data[idx + 1];
      const b = clean.bitmap.data[idx + 2];
      if (isAnyGreen(r, g, b)) clean.bitmap.data[idx + 3] = 0;
    }
  }

  // 1. Detectar columnas separadoras en la imagen ORIGINAL (>95% verde puro)
  const isSep = [];
  for (let x = 0; x < width; x++) {
    let greenCount = 0;
    for (let y = 0; y < height; y++) {
      const idx = (y * width + x) * 4;
      const r = original.bitmap.data[idx];
      const g = original.bitmap.data[idx + 1];
      const b = original.bitmap.data[idx + 2];
      if (isPureGreen(r, g, b)) greenCount++;
    }
    isSep.push(greenCount / height > 0.95);
  }

  // 2. Encontrar regiones entre separadores
  const regions = [];
  let inPose = false, start = 0;
  for (let x = 0; x < width; x++) {
    if (!isSep[x] && !inPose) { inPose = true; start = x; }
    if (isSep[x] && inPose)   { inPose = false; regions.push({ x1: start, x2: x - 1 }); }
  }
  if (inPose) regions.push({ x1: start, x2: width - 1 });

  // Filtrar regiones muy pequeñas (artefactos de labels)
  const filtered = regions.filter(r => (r.x2 - r.x1 + 1) >= 40);
  console.log(`Regiones detectadas: ${filtered.length}`);
  if (filtered.length !== names.length) {
    console.warn(`ADVERTENCIA: se esperaban ${names.length} pero hay ${filtered.length}`);
    filtered.forEach((r, i) => console.log(`  ${i}: x=${r.x1}-${r.x2} (${r.x2 - r.x1 + 1}px)`));
  }

  const outDir = path.join('_source', 'poses_individual');
  fs.mkdirSync(outDir, { recursive: true });

  for (let i = 0; i < Math.min(filtered.length, names.length); i++) {
    const { x1, x2 } = filtered[i];
    const name = names[i];

    // 3. Bounding box exacto usando la imagen LIMPIA (sin verde)
    let minX = x2, maxX = x1, minY = height, maxY = 0;
    for (let col = x1; col <= x2; col++) {
      for (let row = 0; row < height; row++) {
        const idx = (row * width + col) * 4;
        if (clean.bitmap.data[idx + 3] > 10) {
          if (col < minX) minX = col;
          if (col > maxX) maxX = col;
          if (row < minY) minY = row;
          if (row > maxY) maxY = row;
        }
      }
    }

    const charW = maxX - minX + 1;
    const charH = maxY - minY + 1;
    console.log(`\n[${name}] x=${minX}-${maxX}, y=${minY}-${maxY} (${charW}x${charH}px)`);

    // 4. Extraer de la imagen limpia y escalar
    const poseImg = clean.clone();
    poseImg.crop({ x: minX, y: minY, w: charW, h: charH });

    const targetH = Math.round(OUT_H * 0.5);
    const targetW = Math.round(OUT_W * 0.9);
    const scale   = Math.min(targetH / charH, targetW / charW);
    const scaledW = Math.round(charW * scale);
    const scaledH = Math.round(charH * scale);
    poseImg.resize({ w: scaledW, h: scaledH });

    // 5. Canvas verde con pies anclados al 75%
    const canvas = new Jimp({ width: OUT_W, height: OUT_H, color: 0x00FF00FF });
    const footY  = Math.round(OUT_H * 0.75);
    const offX   = Math.floor((OUT_W - scaledW) / 2);
    const offY   = footY - scaledH;
    canvas.composite(poseImg, offX, offY);

    const outPath = path.join(outDir, `${name}.png`);
    await canvas.write(outPath);
    console.log(`  Guardado: ${outPath} (${scaledW}x${scaledH}px, offset ${offX},${offY})`);
  }

  console.log(`\nListo! ${Math.min(filtered.length, names.length)} poses en _source/poses_individual/`);
}

main().catch(console.error);
