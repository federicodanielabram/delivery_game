// Uso: node tools/process_animation.js <video> <carpeta_salida> <prefijo> [--ref-folder <carpeta>]
// --ref-folder: usa el frame 1 de esa animacion como referencia de tamaño del personaje
// --scale-from-video: escala el frame completo del video al canvas (preserva proporciones del video, sin recortar bbox)

const { Jimp } = require('jimp');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

let CANVAS_W   = 200;
let CANVAS_H   = 200;
let MAX_CHAR_W = 180;
let MAX_CHAR_H = 160;
let FOOT_Y     = 192;
let ALPHA_CUT  = 128;   // umbral del hard-cut de alpha; subirlo elimina motion-blur/estelas

async function charBbox(img) {
  let minX = 99999, maxX = 0, minY = 99999, maxY = 0;
  img.scan(0, 0, img.width, img.height, function(x, y, idx) {
    if (this.bitmap.data[idx + 3] > 10) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  });
  return { minX, maxX, minY, maxY };
}

function _cleanEdges(img) {
  const data = img.bitmap.data;
  const len  = data.length;
  for (let idx = 0; idx < len; idx += 4) {
    const a = data[idx + 3];
    if (a === 0) continue;
    const r = data[idx];
    const g = data[idx + 1];
    const b = data[idx + 2];
    // Pixel con tinte verde y semi-transparente → green spill de borde, eliminar
    const greenSpill = g - Math.max(r, b);
    if (a < 240 && greenSpill > 10) {
      data[idx + 3] = 0;
      continue;
    }
    // Hard cut: o totalmente opaco o totalmente transparente
    data[idx + 3] = a < ALPHA_CUT ? 0 : 255;
    // Despill: el personaje no tiene ningun verde, asi que cualquier pixel que
    // conservamos con verde dominante (motion blur teñida de verde) se recolorea
    // bajando el canal verde al maximo de r y b → gris/negro, matcheando la ropa.
    if (data[idx + 3] === 255 && greenSpill > 4) {
      data[idx + 1] = Math.max(r, b);
    }
  }
}

async function main() {
  const [,, videoPath, outputFolder, prefix] = process.argv;

  if (!videoPath || !outputFolder || !prefix) {
    console.log('Uso: node tools/process_animation.js <video> <carpeta_salida> <prefijo> [--ref-folder <carpeta>]');
    process.exit(1);
  }

  const alphaCutIdx = process.argv.indexOf('--alpha-cut');
  if (alphaCutIdx !== -1) {
    ALPHA_CUT = parseInt(process.argv[alphaCutIdx + 1]);
    console.log(`Alpha cut: ${ALPHA_CUT} (elimina motion-blur/estelas mas tenues)`);
  }

  const canvasSizeIdx = process.argv.indexOf('--canvas-size');
  if (canvasSizeIdx !== -1) {
    const n = parseInt(process.argv[canvasSizeIdx + 1]);
    CANVAS_W   = n;
    CANVAS_H   = n;
    MAX_CHAR_W = Math.round(n * 0.90);
    MAX_CHAR_H = Math.round(n * 0.80);
    FOOT_Y     = Math.round(n * 0.96);
  }

  const scaleFromVideo = process.argv.includes('--scale-from-video');

  const refIdx = process.argv.indexOf('--ref-folder');
  const refFolder = refIdx !== -1 ? process.argv[refIdx + 1] : null;

  const forceScaleIdx = process.argv.indexOf('--force-scale');
  const forcedScale = forceScaleIdx !== -1 ? parseFloat(process.argv[forceScaleIdx + 1]) : null;

  const refFrameSrcIdx = process.argv.indexOf('--ref-frame-src');
  const refFrameSrc = refFrameSrcIdx !== -1 ? parseInt(process.argv[refFrameSrcIdx + 1]) - 1 : 0;

  const refFolderFrameIdx = process.argv.indexOf('--ref-folder-frame');
  const refFolderFrame = refFolderFrameIdx !== -1 ? parseInt(process.argv[refFolderFrameIdx + 1]) - 1 : 0;

  const removeWatermark = process.argv.includes('--remove-watermark');
  const removeWatermarkLeft = process.argv.includes('--remove-watermark-left');

  const trimStartIdx = process.argv.indexOf('--trim-start');
  const trimStart = trimStartIdx !== -1 ? parseInt(process.argv[trimStartIdx + 1]) : 0;
  const trimEndIdx = process.argv.indexOf('--trim-end');
  const trimEnd = trimEndIdx !== -1 ? parseInt(process.argv[trimEndIdx + 1]) : 0;

  const brightnessIdx = process.argv.indexOf('--brightness');
  const brightness = brightnessIdx !== -1 ? parseFloat(process.argv[brightnessIdx + 1]) : null;
  const saturationIdx = process.argv.indexOf('--saturation');
  const saturation = saturationIdx !== -1 ? parseFloat(process.argv[saturationIdx + 1]) : null;

  // --kill-bright <0..1>: elimina píxeles muy brillantes (efectos de impacto blancos,
  // destellos) antes de detectar el bbox. El personaje es rojo/negro (luma baja) así que
  // no lo toca. Ej: 0.72 saca el swirl blanco del puñetazo.
  const killBrightIdx = process.argv.indexOf('--kill-bright');
  const killBright = killBrightIdx !== -1 ? parseFloat(process.argv[killBrightIdx + 1]) : null;

  const tempDir = path.join(os.tmpdir(), 'anim_' + Date.now());
  fs.mkdirSync(tempDir, { recursive: true });

  // 1. Extraer frames con chroma key
  console.log('Extrayendo frames...');
  let vfFilters = [];
  if (removeWatermark)     vfFilters.push(`drawbox=x=iw-220:y=ih-70:w=220:h=70:color=0x00FF00@1:t=fill`);
  if (removeWatermarkLeft) vfFilters.push(`drawbox=x=0:y=ih-70:w=220:h=70:color=0x00FF00@1:t=fill`);
  if (brightness !== null || saturation !== null) {
    const br  = brightness !== null ? brightness : 0;
    const sat = saturation !== null ? saturation : 1;
    vfFilters.push(`eq=brightness=${br}:saturation=${sat}`);
  }
  vfFilters.push(`colorkey=0x00FF00:0.3:0.1`);
  if (killBright !== null) {
    // tolerancia ancha para keyear toda la banda brillante (difuso + núcleo blanco sólido)
    vfFilters.push(`lumakey=threshold=${killBright}:tolerance=0.35`);
    console.log(`Kill-bright: lumakey threshold=${killBright} tol=0.35 (elimina destellos/efectos blancos)`);
  }
  execSync(
    `ffmpeg -y -i "${videoPath}" -vf "${vfFilters.join(',')}" -pix_fmt rgba "${path.join(tempDir, 'frame_%04d.png')}"`,
    { stdio: 'inherit' }
  );

  let frames = fs.readdirSync(tempDir).filter(f => f.endsWith('.png')).sort();
  if (trimStart > 0 || trimEnd > 0) {
    frames = frames.slice(trimStart, trimEnd > 0 ? frames.length - trimEnd : undefined);
    console.log(`Trim: saltando ${trimStart} al inicio, ${trimEnd} al final`);
  }
  console.log(`${frames.length} frames extraidos`);

  // ─── MODO scale-from-video ────────────────────────────────────────────────
  // Escala el frame completo del video al canvas sin recortar bbox.
  // Garantiza que el contenido no se salga de cuadro si el video fue generado
  // con márgenes suficientes (como los videos de Kling 960×960).
  if (scaleFromVideo) {
    const firstImg = await Jimp.read(path.join(tempDir, frames[0]));
    const videoW = firstImg.width;
    const videoH = firstImg.height;
    const scale = Math.min(CANVAS_W / videoW, CANVAS_H / videoH);
    const dstW = Math.round(videoW * scale);
    const dstH = Math.round(videoH * scale);
    const offX = Math.floor((CANVAS_W - dstW) / 2);
    const offY = Math.floor((CANVAS_H - dstH) / 2);

    console.log(`scale-from-video: video=${videoW}x${videoH}, scale=${scale.toFixed(4)}, dst=${dstW}x${dstH}, canvas=${CANVAS_W}x${CANVAS_H}`);

    fs.mkdirSync(outputFolder, { recursive: true });
    fs.readdirSync(outputFolder)
      .filter(f => f.endsWith('.png'))
      .forEach(f => fs.unlinkSync(path.join(outputFolder, f)));

    console.log('Procesando frames...');
    for (let i = 0; i < frames.length; i++) {
      const img = await Jimp.read(path.join(tempDir, frames[i]));
      img.resize({ w: dstW, h: dstH });
      _cleanEdges(img);

      const canvas = new Jimp({ width: CANVAS_W, height: CANVAS_H, color: 0x00000000 });
      canvas.composite(img, offX, offY);

      const num = String(i + 1).padStart(3, '0');
      await canvas.write(path.join(outputFolder, `${prefix}_${num}.png`));

      process.stdout.write(`\r  ${i + 1}/${frames.length}`);
    }

    fs.rmSync(tempDir, { recursive: true, force: true });
    console.log(`\nListo! ${frames.length} frames en ${outputFolder}`);
    return;
  }
  // ─────────────────────────────────────────────────────────────────────────

  // 2. Detectar bounding box maximo en todos los frames
  let minX = 99999, minY = 99999, maxX = 0, maxY = 0;

  console.log('Detectando bounding box...');
  for (const f of frames) {
    const img = await Jimp.read(path.join(tempDir, f));
    img.scan(0, 0, img.width, img.height, function(x, y, idx) {
      const a = this.bitmap.data[idx + 3];
      if (a > 10) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    });
  }

  const srcW = maxX - minX + 1;
  const srcH = maxY - minY + 1;
  console.log(`Personaje: x=${minX}-${maxX}, y=${minY}-${maxY} (${srcW}x${srcH}px)`);

  // 3. Calcular scale — por ref-folder o automatico
  let scale;

  let refCenterX = null;
  let frame1BboxInSrc = null;

  if (refFolder) {
    // Medir bbox del personaje en el frame de referencia del video actual
    const refSrcFrame = Math.min(refFrameSrc, frames.length - 1);
    const frame1Img = await Jimp.read(path.join(tempDir, frames[refSrcFrame]));
    const f1 = await charBbox(frame1Img);
    const frame1SrcH = f1.maxY - f1.minY + 1;
    frame1BboxInSrc = f1;
    if (refSrcFrame > 0) console.log(`Usando frame ${refSrcFrame + 1} como referencia de alineación`);

    // Medir bbox del personaje en el frame indicado de la referencia (canvas ya procesado)
    const refFiles = fs.readdirSync(refFolder).filter(f => f.endsWith('.png')).sort();
    const refFileIdx = Math.min(refFolderFrame, refFiles.length - 1);
    if (refFolderFrame > 0) console.log(`Usando frame ${refFileIdx + 1} de ref-folder como referencia de tamaño`);
    const refImg = await Jimp.read(path.join(refFolder, refFiles[refFileIdx]));
    const ref = await charBbox(refImg);
    const refCharH = ref.maxY - ref.minY + 1;
    refCenterX = (ref.minX + ref.maxX) / 2;  // centro X del personaje en canvas de referencia

    // Si hay --force-scale, usa esa escala pero conserva el X de la referencia
    if (forcedScale) {
      scale = forcedScale;
      console.log(`Ref: centerX=${refCenterX.toFixed(1)} | Escala forzada: x${scale.toFixed(3)}`);
    } else {
      scale = refCharH / frame1SrcH;
      console.log(`Ref: ${refCharH}px alto, centerX=${refCenterX.toFixed(1)} | Frame 1 src: ${frame1SrcH}px | Scale forzado: x${scale.toFixed(3)}`);
    }
  } else if (forcedScale) {
    scale = forcedScale;
    console.log(`Escala forzada: x${scale.toFixed(3)}`);
  } else {
    scale = Math.min(MAX_CHAR_W / srcW, MAX_CHAR_H / srcH);
    console.log(`Escala auto: x${scale.toFixed(3)}`);
  }

  // 4. Procesar cada frame
  fs.mkdirSync(outputFolder, { recursive: true });
  fs.readdirSync(outputFolder)
    .filter(f => f.endsWith('.png'))
    .forEach(f => fs.unlinkSync(path.join(outputFolder, f)));

  const dstW = Math.round(srcW * scale);
  const dstH = Math.round(srcH * scale);
  const offY = FOOT_Y - dstH;

  // Alinear centro X del personaje con la referencia (si hay ref-folder)
  let offX;
  if (refCenterX !== null && frame1BboxInSrc !== null) {
    const f1CenterXInSrc = (frame1BboxInSrc.minX + frame1BboxInSrc.maxX) / 2;
    const f1CenterXScaled = (f1CenterXInSrc - minX) * scale;  // posicion del centro en el recorte escalado
    offX = Math.round(refCenterX - f1CenterXScaled);
    console.log(`Alineacion X: f1 center src=${f1CenterXInSrc.toFixed(1)}, scaled=${f1CenterXScaled.toFixed(1)}, offX=${offX}`);
  } else {
    offX = Math.floor((CANVAS_W - dstW) / 2);
  }

  console.log(`Output: ${dstW}x${dstH} en canvas ${CANVAS_W}x${CANVAS_H}`);
  console.log('Procesando frames...');

  for (let i = 0; i < frames.length; i++) {
    const img = await Jimp.read(path.join(tempDir, frames[i]));
    img.crop({ x: minX, y: minY, w: srcW, h: srcH });
    img.resize({ w: dstW, h: dstH });
    _cleanEdges(img);

    const canvas = new Jimp({ width: CANVAS_W, height: CANVAS_H, color: 0x00000000 });
    canvas.composite(img, offX, offY);

    const num = String(i + 1).padStart(3, '0');
    await canvas.write(path.join(outputFolder, `${prefix}_${num}.png`));

    process.stdout.write(`\r  ${i + 1}/${frames.length}`);
  }

  fs.rmSync(tempDir, { recursive: true, force: true });

  console.log(`\nListo! ${frames.length} frames en ${outputFolder}`);
}

main().catch(console.error);
