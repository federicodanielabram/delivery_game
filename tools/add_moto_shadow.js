// Agrega sombra elíptica a frames de motos que no la tienen (00-08)
// Sombra dentro del canvas original: se pinta en los píxeles transparentes
// entre las ruedas. El canvas NO cambia de tamaño.

const { Jimp } = require('jimp');
const path = require('path');

const FRAMES_DIR = 'assets/sprites/motorcycles/frames';
const SHADOW_RY    = 11;  // radio vertical — sombra fina
const SHADOW_EXTRA = 38;  // rx extra → sombra más larga

async function addShadow(frameIdx) {
  const file = path.join(FRAMES_DIR, `frame_${String(frameIdx).padStart(2,'0')}.png`);
  const src  = await Jimp.read(file);
  const W    = src.bitmap.width;
  const H    = src.bitmap.height;
  const data = src.bitmap.data;

  // Última fila opaca (borde inferior de la moto)
  let baseY = 0;
  for (let y = H - 1; y >= 0; y--) {
    for (let x = 0; x < W; x++) {
      if (data[(y * W + x) * 4 + 3] > 30) { baseY = y; y = -1; break; }
    }
  }

  // Escanear tercio inferior para medir el span real de las ruedas
  const scanFrom = Math.floor(baseY * 0.7);
  let wheelLeft = W, wheelRight = 0;
  for (let y = scanFrom; y <= baseY; y++) {
    for (let x = 0; x < W; x++) {
      if (data[(y * W + x) * 4 + 3] > 30) {
        if (x < wheelLeft)  wheelLeft  = x;
        if (x > wheelRight) wheelRight = x;
      }
    }
  }

  const wheelCX = (wheelLeft + wheelRight) / 2;
  const wheelRX = (wheelRight - wheelLeft) / 2;

  // Elipse con borde inferior en baseY, centro en baseY - SHADOW_RY
  const cx = wheelCX;
  const cy = baseY - SHADOW_RY;
  const rx = wheelRX + SHADOW_EXTRA;
  const ry = SHADOW_RY;

  const rowStart = Math.max(0, Math.ceil(cy - ry));
  const rowEnd   = Math.min(H - 1, baseY);

  // Limpiar sombra anterior dentro de la zona de la elipse (píxeles muy oscuros = sombra vieja)
  for (let y = rowStart; y <= rowEnd; y++) {
    for (let x = 0; x < W; x++) {
      const di = (y * W + x) * 4;
      if (data[di + 3] < 30) continue;
      const brightness = data[di] + data[di + 1] + data[di + 2];
      if (brightness < 80) {
        data[di] = data[di+1] = data[di+2] = data[di+3] = 0; // borrar sombra vieja
      }
    }
  }

  // Pintar nueva sombra: degradado aplanado con curva (menos fade, más contundente)
  let painted = 0;
  for (let y = rowStart; y <= rowEnd; y++) {
    for (let x = 0; x < W; x++) {
      const di = (y * W + x) * 4;
      if (data[di + 3] > 30) continue; // no pisar la moto

      const dx = (x - cx) / rx;
      const dy = (y - cy) / ry;
      const d  = Math.sqrt(dx * dx + dy * dy);
      if (d > 1.0) continue;

      // Gamma 0.35 → el centro es más plano y uniforme, solo cae en el borde
      const fade = Math.pow(1.0 - d, 0.35);
      data[di]     = Math.round(10 * fade);
      data[di + 1] = Math.round(7  * fade);
      data[di + 2] = Math.round(16 * fade);
      data[di + 3] = Math.min(255, Math.round(230 * fade + 15));
      painted++;
    }
  }

  await src.write(file);
  console.log(
    `frame_${String(frameIdx).padStart(2,'0')}: ${W}x${H} (sin cambio) ` +
    `cx=${Math.round(cx)} cy=${Math.round(cy)} rx=${Math.round(rx)} ry=${ry} ` +
    `painted=${painted}px`
  );
}

(async () => {
  for (let i = 0; i <= 8; i++) {
    await addShadow(i);
  }
  console.log('Listo.');
})().catch(console.error);
