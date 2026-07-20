// Recorta y renombra frames de una carpeta.
// Uso: node tools/trim_frames.js <carpeta> <frameDesde> <frameHasta>

const fs   = require('fs');
const path = require('path');

const [,, folder, fromStr, toStr] = process.argv;
if (!folder) { console.log('Uso: node tools/trim_frames.js <carpeta> <frameDesde> <frameHasta>'); process.exit(1); }

const from = parseInt(fromStr);
const to   = parseInt(toStr);

const files = fs.readdirSync(folder).filter(f => f.endsWith('.png')).sort();

// Primero renombrar los que queremos a nombres temporales
const keep = [];
for (let i = from; i <= to; i++) {
  if (files[i - 1]) keep.push(files[i - 1]);
}

// Copiar a temporales
keep.forEach((f, idx) => {
  fs.renameSync(path.join(folder, f), path.join(folder, `_tmp_${String(idx).padStart(4,'0')}.png`));
});

// Borrar el resto
fs.readdirSync(folder).filter(f => f.endsWith('.png') && !f.startsWith('_tmp_')).forEach(f => {
  fs.unlinkSync(path.join(folder, f));
});

// Renombrar temporales al prefijo original
const prefix = keep[0].replace(/\d{3}\.png$/, '');
fs.readdirSync(folder).filter(f => f.startsWith('_tmp_')).sort().forEach((f, idx) => {
  const newName = `${prefix}${String(idx + 1).padStart(3, '0')}.png`;
  fs.renameSync(path.join(folder, f), path.join(folder, newName));
});

console.log(`Listo! ${keep.length} frames (${from}-${to}) renombrados como ${prefix}001 … ${prefix}${String(keep.length).padStart(3,'0')}`);
