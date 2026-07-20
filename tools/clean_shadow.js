// Limpia residuos de sombra de Kling en frames procesados.
// Estrategia: busca píxeles con alpha bajo (10-180) debajo del centro del personaje
// que formen grupos aislados del cuerpo principal, y los hace transparentes.
//
// Uso: node tools/clean_shadow.js <carpeta> [--dry-run]

const { Jimp } = require('jimp');
const fs = require('fs');
const path = require('path');

const ALPHA_MIN  = 5;    // mínimo alpha para considerar pixel visible
const ALPHA_SOFT = 200;  // alpha por debajo del cual es "sombra candidata"
const BODY_START_Y = 10; // el cuerpo arranca aquí (ignorar header)

async function getComponents(data, width, height) {
  const visited = new Set();
  const components = [];

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const key = y * width + x;
      if (visited.has(key)) continue;
      const alpha = data[(key) * 4 + 3];
      if (alpha < ALPHA_MIN) continue;

      // BFS
      const queue = [key];
      const comp = [];
      visited.add(key);
      while (queue.length > 0) {
        const k = queue.shift();
        const kx = k % width;
        const ky = Math.floor(k / width);
        comp.push([kx, ky, data[k * 4 + 3]]);
        for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]]) {
          const nx = kx + dx; const ny = ky + dy;
          if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
          const nk = ny * width + nx;
          if (visited.has(nk)) continue;
          if (data[nk * 4 + 3] < ALPHA_MIN) continue;
          visited.add(nk);
          queue.push(nk);
        }
      }
      components.push(comp);
    }
  }
  return components;
}

async function cleanFrame(filePath, dryRun) {
  const img = await Jimp.read(filePath);
  const { width, height } = img.bitmap;
  const data = img.bitmap.data;

  const components = await getComponents(data, width, height);
  if (components.length === 0) return false;

  // Componente principal = la más grande
  components.sort((a, b) => b.length - a.length);
  const main = components[0];
  const mainMaxY = Math.max(...main.map(([,y]) => y));

  let removed = 0;
  for (let i = 1; i < components.length; i++) {
    const comp = components[i];
    const minY  = Math.min(...comp.map(([,y]) => y));
    const avgAlpha = comp.reduce((s,[,,a]) => s + a, 0) / comp.length;

    // Eliminar si: está debajo del 60% del personaje Y tiene alpha promedio bajo (sombra semitransparente)
    const isBelowBody = minY > height * 0.55;
    const isSoft = avgAlpha < ALPHA_SOFT;

    if (isBelowBody && isSoft) {
      if (!dryRun) {
        for (const [x, y] of comp) {
          const idx = (y * width + x) * 4;
          data[idx + 3] = 0;
          removed++;
        }
      } else {
        removed += comp.length;
      }
    }
  }

  if (removed > 0) {
    if (!dryRun) await img.write(filePath);
    const tag = dryRun ? '[DRY]' : '';
    console.log(`  ${tag} ${path.basename(filePath)}: ${removed} píxeles eliminados`);
    return true;
  }
  return false;
}

async function main() {
  const folder = process.argv[2];
  const dryRun = process.argv.includes('--dry-run');
  if (!folder) { console.log('Uso: node tools/clean_shadow.js <carpeta> [--dry-run]'); process.exit(1); }

  const files = fs.readdirSync(folder).filter(f => f.endsWith('.png') && !f.endsWith('.import')).sort();
  console.log(`${dryRun ? '[DRY RUN] ' : ''}Procesando ${files.length} frames en ${folder}...`);

  let cleaned = 0;
  for (const file of files) {
    const changed = await cleanFrame(path.join(folder, file), dryRun);
    if (changed) cleaned++;
  }

  console.log(`\nListo. ${cleaned} frames ${dryRun ? 'con manchas detectadas' : 'modificados'}.`);
}

main().catch(console.error);
