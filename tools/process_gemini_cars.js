// Uso: node tools/process_gemini_cars.js <outDir> <file1> <file2> ...
// Elimina el damero de Gemini (baked-in) con flood fill desde los bordes.
// Exporta cada auto como PNG con alpha real, canvas normalizado y bottom-aligned.

const { Jimp } = require('jimp');
const path = require('path');
const fs   = require('fs');

const PADDING  = 16;
const TOLERANCE = 55; // qué tan diferente puede ser un px del damero y seguir siendo fondo
const LUMA_BG   = 160; // píxeles con luma > esto EN EL BORDE también se eliminan (JPEG blend)

function colorDist(r1,g1,b1, r2,g2,b2) {
  return Math.abs(r1-r2) + Math.abs(g1-g2) + Math.abs(b1-b2);
}
function luma(r,g,b) { return 0.299*r + 0.587*g + 0.114*b; }

async function detectCheckerboard(data, W, H) {
  // Muestrea las 4 esquinas para encontrar los 2 colores del damero
  // (el auto nunca ocupa las 4 esquinas al mismo tiempo)
  const freq = {};
  const sw = Math.min(100, Math.floor(W * 0.07));
  const sh = Math.min(100, Math.floor(H * 0.07));
  const corners = [
    [0, 0, sw, sh],
    [W-sw, 0, W, sh],
    [0, H-sh, sw, H],
    [W-sw, H-sh, W, H],
  ];
  for (const [x0,y0,x1,y1] of corners) {
    for (let y=y0;y<y1;y++) for (let x=x0;x<x1;x++) {
      const pi=(y*W+x)*4;
      // Solo contar píxeles "neutros" (R≈G≈B, el damero es gris)
      const r=data[pi],g=data[pi+1],b=data[pi+2];
      if (Math.max(Math.abs(r-g),Math.abs(r-b),Math.abs(g-b)) > 20) continue;
      const key=`${Math.round(r/8)*8},${Math.round(g/8)*8},${Math.round(b/8)*8}`;
      freq[key]=(freq[key]||0)+1;
    }
  }
  const sorted=Object.entries(freq).sort((a,b)=>b[1]-a[1]);
  const parse=k=>k.split(',').map(Number);
  const [r1,g1,b1]=parse(sorted[0][0]);
  let r2=r1,g2=g1,b2=b1;
  for (let i=1;i<sorted.length;i++){
    const [r,g,b]=parse(sorted[i][0]);
    if(colorDist(r,g,b,r1,g1,b1)>15){[r2,g2,b2]=[r,g,b];break;}
  }
  return [[r1,g1,b1],[r2,g2,b2]];
}

async function processFile(src, outPath, canvasW, canvasH) {
  const img  = await Jimp.read(src);
  const data = img.bitmap.data;
  const W    = img.bitmap.width;
  const H    = img.bitmap.height;

  const [[r1,g1,b1],[r2,g2,b2]] = await detectCheckerboard(data, W, H);
  console.log(`  Damero: (${r1},${g1},${b1}) / (${r2},${g2},${b2})`);

  function isBg(pi) {
    const r=data[pi],g=data[pi+1],b=data[pi+2];
    if (colorDist(r,g,b,r1,g1,b1)<=TOLERANCE) return true;
    if (colorDist(r,g,b,r2,g2,b2)<=TOLERANCE) return true;
    // Fallback: píxel muy claro Y neutro (blend JPEG en el borde del damero)
    if (luma(r,g,b) > LUMA_BG && Math.max(Math.abs(r-g),Math.abs(r-b),Math.abs(g-b)) < 35) return true;
    return false;
  }

  // Flood fill BFS desde todos los bordes
  const mask  = new Uint8Array(W * H).fill(255); // 255=sin visitar, 0=fondo, 1=auto
  const queue = new Int32Array(W * H * 2);
  let qHead = 0, qTail = 0;
  const DX = [-1,1,0,0], DY = [0,0,-1,1];

  function seed(x, y) {
    const i = y * W + x;
    if (mask[i] !== 255) return;
    if (isBg(i * 4)) {
      mask[i] = 0;
      queue[qTail++] = x;
      queue[qTail++] = y;
    } else {
      mask[i] = 1;
    }
  }

  for (let x = 0; x < W; x++) { seed(x, 0); seed(x, H-1); }
  for (let y = 1; y < H-1; y++) { seed(0, y); seed(W-1, y); }

  while (qHead < qTail) {
    const x = queue[qHead++], y = queue[qHead++];
    for (let d = 0; d < 4; d++) {
      const nx = x+DX[d], ny = y+DY[d];
      if (nx<0||nx>=W||ny<0||ny>=H) continue;
      const ni = ny*W+nx;
      if (mask[ni] !== 255) continue;
      if (isBg(ni*4)) { mask[ni]=0; queue[qTail++]=nx; queue[qTail++]=ny; }
      else mask[ni] = 1;
    }
  }
  for (let i = 0; i < W*H; i++) if (mask[i]===255) mask[i]=1;

  // Aplicar alpha + suavizado de borde
  for (let i = 0; i < W*H; i++) {
    const pi = i*4;
    if (mask[i]===0) { data[pi+3]=0; continue; }
    const x = i%W, y = Math.floor(i/W);
    let adjBg = false;
    for (let d=0;d<4;d++){
      const nx=x+DX[d],ny=y+DY[d];
      if(nx<0||nx>=W||ny<0||ny>=H) continue;
      if(mask[ny*W+nx]===0){adjBg=true;break;}
    }
    if (adjBg) {
      const pi2=i*4;
      const r=data[pi2],g=data[pi2+1],b=data[pi2+2];
      const d1=colorDist(r,g,b,r1,g1,b1), d2=colorDist(r,g,b,r2,g2,b2);
      const minD=Math.min(d1,d2);
      if (minD < TOLERANCE) {
        data[pi2+3] = Math.round(255 * (minD / TOLERANCE));
      }
    }
  }

  // Bounding box del auto
  let minX=W,maxX=0,minY=H,maxY=0;
  for (let y=0;y<H;y++) for (let x=0;x<W;x++) {
    if (mask[y*W+x]===1 && data[(y*W+x)*4+3]>10) {
      if(x<minX)minX=x; if(x>maxX)maxX=x;
      if(y<minY)minY=y; if(y>maxY)maxY=y;
    }
  }
  const carW=maxX-minX+1, carH=maxY-minY+1;

  // Canvas normalizado bottom-aligned
  const cW = canvasW || (carW + PADDING*2);
  const cH = canvasH || (carH + PADDING*2);
  const canvas     = new Jimp({ width: cW, height: cH, color: 0x00000000 });
  const canvasData = canvas.bitmap.data;
  const destX = Math.round((cW - carW) / 2);
  const destY = cH - carH - PADDING;

  for (let y=0;y<carH;y++) for (let x=0;x<carW;x++) {
    const si=((minY+y)*W+(minX+x))*4;
    if(data[si+3]<4) continue;
    const di=((destY+y)*cW+(destX+x))*4;
    canvasData[di]=data[si]; canvasData[di+1]=data[si+1];
    canvasData[di+2]=data[si+2]; canvasData[di+3]=data[si+3];
  }

  await canvas.write(outPath);
  return { carW, carH, cW, cH };
}

async function main() {
  const outDir = process.argv[2];
  const files  = process.argv.slice(3);
  if (!outDir || files.length===0) {
    console.log('Uso: node tools/process_gemini_cars.js <outDir> <file1> <file2> ...');
    process.exit(1);
  }
  fs.mkdirSync(outDir, { recursive: true });

  // Primer pasada: detectar dimensiones máximas para normalizar canvas
  console.log('Calculando dimensiones...');
  let maxCarW=0, maxCarH=0;
  for (const f of files) {
    const img = await Jimp.read(f);
    const W=img.bitmap.width, H=img.bitmap.height;
    const [[r1,g1,b1],[r2,g2,b2]] = await detectCheckerboard(img.bitmap.data, W, H);
    const data=img.bitmap.data;
    function isBg(pi){
      return colorDist(data[pi],data[pi+1],data[pi+2],r1,g1,b1)<=TOLERANCE ||
             colorDist(data[pi],data[pi+1],data[pi+2],r2,g2,b2)<=TOLERANCE;
    }
    let minX=W,maxX=0,minY=H,maxY=0;
    for(let y=0;y<H;y++) for(let x=0;x<W;x++){
      if(!isBg((y*W+x)*4)){
        if(x<minX)minX=x;if(x>maxX)maxX=x;
        if(y<minY)minY=y;if(y>maxY)maxY=y;
      }
    }
    if(maxX>=minX){
      maxCarW=Math.max(maxCarW,maxX-minX+1);
      maxCarH=Math.max(maxCarH,maxY-minY+1);
    }
  }
  const canvasW = maxCarW + PADDING*2;
  const canvasH = maxCarH + PADDING*2;
  console.log(`Canvas: ${canvasW}×${canvasH}px\n`);

  // Segunda pasada: exportar
  for (let i=0; i<files.length; i++) {
    const name = `car_side_${String(i).padStart(2,'0')}.png`;
    const out  = path.join(outDir, name);
    console.log(`[${i+1}/${files.length}] ${path.basename(files[i])}`);
    const { carW, carH } = await processFile(files[i], out, canvasW, canvasH);
    console.log(`  → ${carW}×${carH}px en canvas ${canvasW}×${canvasH}  (${name})\n`);
  }
  console.log(`✓ ${files.length} autos guardados en ${outDir}`);
}

main().catch(e => { console.error(e); process.exit(1); });
