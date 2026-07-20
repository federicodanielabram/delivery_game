// Uso: node tools/clean_edges_folder.js <carpeta_raiz>
// Aplica _cleanEdges() a todos los PNGs dentro de la carpeta (recursivo), omite /refs/

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

function _cleanEdges(img) {
  const data = img.bitmap.data;
  const len  = data.length;
  for (let idx = 0; idx < len; idx += 4) {
    const a = data[idx + 3];
    if (a === 0) continue;
    const r = data[idx], g = data[idx + 1], b = data[idx + 2];
    const greenSpill = g - Math.max(r, b);
    if (a < 240 && greenSpill > 10) { data[idx + 3] = 0; continue; }
    data[idx + 3] = a < 128 ? 0 : 255;
  }
}

function collectPngs(folder, results = []) {
  for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
    const full = path.join(folder, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'refs') continue;
      collectPngs(full, results);
    } else if (entry.name.endsWith('.png')) {
      results.push(full);
    }
  }
  return results;
}

async function main() {
  const root = process.argv[2];
  if (!root) { console.log('Uso: node tools/clean_edges_folder.js <carpeta>'); process.exit(1); }

  const files = collectPngs(root);
  console.log(`Procesando ${files.length} frames en ${root}...`);

  for (let i = 0; i < files.length; i++) {
    const img = await Jimp.read(files[i]);
    _cleanEdges(img);
    await img.write(files[i]);
    process.stdout.write(`\r  ${i + 1}/${files.length}`);
  }
  console.log('\nListo!');
}
main().catch(console.error);
