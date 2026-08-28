// Analiza el perfil superior de cada auto PNG y exporta zonas de altura para GDScript.
// Uso: node tools/analyze_car_heights.js <sprite_dir>
// Divide cada auto en 3 zonas horizontales (izq / centro / der) y encuentra el pixel
// más alto con alpha > 32 en cada zona. Salida: constante GDScript lista para copiar.

const { Jimp } = require('jimp');
const path = require('path');
const fs   = require('fs');

const N_ZONES = 3;   // izquierda / techo / derecha
const ALPHA_MIN = 32;

async function analyzeFile(filePath) {
  const img  = await Jimp.read(filePath);
  const { data, width: W, height: H } = img.bitmap;

  const zoneW = W / N_ZONES;
  const zones = [];

  for (let z = 0; z < N_ZONES; z++) {
    const x0 = Math.floor(z * zoneW);
    const x1 = Math.min(Math.floor((z + 1) * zoneW) - 1, W - 1);

    let topY = H; // pixel más alto con alpha en esta zona
    outer:
    for (let y = 0; y < H; y++) {
      for (let x = x0; x <= x1; x++) {
        if (data[(y * W + x) * 4 + 3] >= ALPHA_MIN) { topY = y; break outer; }
      }
    }

    // altura desde el fondo del canvas (canvas bottom = FLOOR_Y en el juego)
    const heightFromBottom = H - topY;
    zones.push([
      parseFloat((x0 / W).toFixed(4)),
      parseFloat((x1 / W).toFixed(4)),
      heightFromBottom
    ]);
  }
  return { W, H, zones };
}

async function main() {
  const spriteDir = process.argv[2] || 'assets/sprites/cars/side_test';
  const files = fs.readdirSync(spriteDir)
    .filter(f => f.match(/^car_side_\d+\.png$/))
    .sort();

  console.log(`Analizando ${files.length} autos en ${spriteDir}\n`);

  const results = {};
  for (const f of files) {
    const idx = parseInt(f.match(/\d+/)[0]);
    const { W, H, zones } = await analyzeFile(path.join(spriteDir, f));
    results[idx] = zones;
    console.log(`${f} (${W}×${H}):`);
    const labels = ['izq ', 'techo', 'der '];
    zones.forEach((z, i) => {
      console.log(`  ${labels[i]}: x=[${(z[0]*100).toFixed(1)}%,${(z[1]*100).toFixed(1)}%]  alto=${z[2]}px desde base`);
    });
  }

  // --- Generar constante GDScript ---
  console.log('\n# ── Copiar esto en car_mid_layer.gd ─────────────────────────────────────────');
  console.log('# CAR_ZONES[frame_idx] = [[x0_frac, x1_frac, height_from_bottom_px], ...]');
  let out = 'const CAR_ZONES: Dictionary = {\n';
  for (const [idx, zones] of Object.entries(results)) {
    out += `\t${idx}: [\n`;
    zones.forEach(z => {
      out += `\t\t[${z[0].toFixed(4)}, ${z[1].toFixed(4)}, ${z[2]}],\n`;
    });
    out += `\t],\n`;
  }
  out += '}';
  console.log(out);
}

main().catch(e => { console.error(e); process.exit(1); });
