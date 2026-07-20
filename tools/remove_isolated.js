// Elimina componentes de píxeles aislados (platos, piezas) dejando solo el cuerpo principal.
// Uso: node tools/remove_isolated.js <carpeta>

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

async function main() {
  const folder = process.argv[2];
  if (!folder) { console.log('Uso: node tools/remove_isolated.js <carpeta>'); process.exit(1); }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  console.log(`${files.length} frames`);

  for (let fi = 0; fi < files.length; fi++) {
    const fpath = path.join(folder, files[fi]);
    const img   = await Jimp.read(fpath);
    const W = img.bitmap.width;
    const H = img.bitmap.height;
    const data = img.bitmap.data;

    // Mapa de píxeles opacos
    const opaque = new Uint8Array(W * H);
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++)
        if (data[(y * W + x) * 4 + 3] > 64) opaque[y * W + x] = 1;

    // BFS para encontrar componentes conectados (4-conectividad)
    const label = new Int32Array(W * H).fill(-1);
    const components = []; // cada componente: array de índices
    let nextLabel = 0;

    for (let start = 0; start < W * H; start++) {
      if (!opaque[start] || label[start] >= 0) continue;
      const comp = [];
      const queue = [start];
      label[start] = nextLabel;
      while (queue.length > 0) {
        const idx = queue.pop();
        comp.push(idx);
        const x = idx % W, y = Math.floor(idx / W);
        const neighbors = [];
        if (x > 0)     neighbors.push(idx - 1);
        if (x < W - 1) neighbors.push(idx + 1);
        if (y > 0)     neighbors.push(idx - W);
        if (y < H - 1) neighbors.push(idx + W);
        for (const n of neighbors) {
          if (opaque[n] && label[n] < 0) {
            label[n] = nextLabel;
            queue.push(n);
          }
        }
      }
      components.push(comp);
      nextLabel++;
    }

    // El componente más grande es el cuerpo principal
    let mainComp = 0;
    for (let i = 1; i < components.length; i++)
      if (components[i].length > components[mainComp].length) mainComp = i;

    // Borrar todos los demás componentes
    let removed = 0;
    for (let i = 0; i < components.length; i++) {
      if (i === mainComp) continue;
      for (const idx of components[i]) {
        data[idx * 4 + 3] = 0;
      }
      removed += components[i].length;
    }

    await img.write(fpath);
    process.stdout.write(`\r  ${fi + 1}/${files.length}  componentes: ${components.length}  px borrados: ${removed}   `);
  }
  console.log('\nListo!');
}

main().catch(console.error);
