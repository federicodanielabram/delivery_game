// Elimina grupos de pixeles aislados del personaje principal (logo, artefactos)
// Uso: node tools/clean_isolated.js <carpeta>

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

async function cleanIsolated(imgPath) {
  const img = await Jimp.read(imgPath);
  const { width, height } = img.bitmap;
  const data = img.bitmap.data;

  const opaque = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i++) {
    opaque[i] = data[i * 4 + 3] > 0 ? 1 : 0;
  }

  const visited = new Uint8Array(width * height);
  const components = [];

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = y * width + x;
      if (!opaque[i] || visited[i]) continue;

      // BFS con 8-conectividad
      const queue = [i];
      const component = [i];
      visited[i] = 1;
      let head = 0;
      while (head < queue.length) {
        const cur = queue[head++];
        const cy = Math.floor(cur / width);
        const cx = cur % width;
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            if (dy === 0 && dx === 0) continue;
            const ny = cy + dy;
            const nx = cx + dx;
            if (ny < 0 || ny >= height || nx < 0 || nx >= width) continue;
            const ni = ny * width + nx;
            if (opaque[ni] && !visited[ni]) {
              visited[ni] = 1;
              queue.push(ni);
              component.push(ni);
            }
          }
        }
      }
      components.push(component);
    }
  }

  if (components.length <= 1) return 0;

  // Conservar solo el componente mas grande
  let largest = components[0];
  for (const comp of components) {
    if (comp.length > largest.length) largest = comp;
  }

  const keep = new Uint8Array(width * height);
  for (const i of largest) keep[i] = 1;

  let removed = 0;
  for (let i = 0; i < width * height; i++) {
    if (opaque[i] && !keep[i]) {
      data[i * 4 + 3] = 0;
      removed++;
    }
  }

  if (removed > 0) await img.write(imgPath);
  return removed;
}

async function main() {
  const folder = process.argv[2];
  if (!folder) {
    console.log('Uso: node tools/clean_isolated.js <carpeta>');
    process.exit(1);
  }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();
  console.log(`Procesando ${files.length} frames en ${folder}...`);

  let cleaned = 0;
  for (let f = 0; f < files.length; f++) {
    const removed = await cleanIsolated(path.join(folder, files[f]));
    if (removed > 0) {
      process.stdout.write(`\r  ${f + 1}/${files.length} — ${files[f]}: ${removed}px eliminados`);
      cleaned++;
    } else {
      process.stdout.write(`\r  ${f + 1}/${files.length}`);
    }
  }

  console.log(`\nListo. ${cleaned}/${files.length} frames limpiados.`);
}

main().catch(console.error);
