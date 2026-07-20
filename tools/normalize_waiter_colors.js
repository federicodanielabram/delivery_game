// Normaliza piel, delantal y pantalones de todas las animaciones del mozo.
// Usa targets FIJOS — no sampleo automático.

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const BASE  = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies';
// idle/idle2 excluidos — tienen estilo cel-shaded incompatible con el pipeline
const ANIMS = ['walk','walk_to_idle','idle_to_walk','throw','hurt','death'];

// ── Targets fijos ─────────────────────────────────────────────────────────────
// Pantalones/zapatos: negro azulado oscuro
const PANTS_TARGET = { h: 228, s: 18 };
// Delantal/camisa: blanco cálido grisáceo (como el walk)
const APRON_TARGET = { h: 28,  s: 10 };

// ── Piel por variante ─────────────────────────────────────────────────────────
const VARIANTS = [
  { name: 'waiter',       skin: { h: 18, s: 52, lScale: 1.00 } },
  { name: 'waiter_dark',  skin: { h: 22, s: 50, lScale: 0.70 } },
  { name: 'waiter_light', skin: { h: 14, s: 28, lScale: 1.30 } },
];

// ── Rangos de detección ───────────────────────────────────────────────────────
const SKIN_H_MIN = 5,  SKIN_H_MAX = 40;
const SKIN_S_MIN = 28, SKIN_S_MAX = 95;
const SKIN_L_MIN = 10, SKIN_L_MAX = 78;

const PANTS_L_MAX = 22;   // muy oscuro → pantalones/zapatos
const PANTS_S_MAX = 55;

const APRON_L_MIN = 54;   // claro + baja saturación → delantal/camisa
const APRON_S_MAX = 30;

// ── Helpers ───────────────────────────────────────────────────────────────────
function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r,g,b), min = Math.min(r,g,b);
  let h=0, s=0, l=(max+min)/2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d/(2-max-min) : d/(max+min);
    switch(max) {
      case r: h=((g-b)/d+(g<b?6:0))/6; break;
      case g: h=((b-r)/d+2)/6; break;
      case b: h=((r-g)/d+4)/6; break;
    }
  }
  return [h*360, s*100, l*100];
}

function hue2rgb(p,q,t){
  if(t<0)t+=1; if(t>1)t-=1;
  if(t<1/6)return p+(q-p)*6*t;
  if(t<1/2)return q;
  if(t<2/3)return p+(q-p)*(2/3-t)*6;
  return p;
}
function hslToRgb(h,s,l){
  h/=360; s/=100; l/=100;
  if(s===0){const v=Math.round(l*255);return[v,v,v];}
  const q=l<0.5?l*(1+s):l+s-l*s, p=2*l-q;
  return[
    Math.round(hue2rgb(p,q,h+1/3)*255),
    Math.round(hue2rgb(p,q,h)*255),
    Math.round(hue2rgb(p,q,h-1/3)*255),
  ];
}

// ── Procesa un frame ──────────────────────────────────────────────────────────
function processPixels(data, skinPreset) {
  for (let i = 0; i < data.length; i += 4) {
    if (data[i+3] < 200) continue;
    const [h, s, l] = rgbToHsl(data[i], data[i+1], data[i+2]);

    const isSkin = h>=SKIN_H_MIN && h<=SKIN_H_MAX
                && s>=SKIN_S_MIN && s<=SKIN_S_MAX
                && l>=SKIN_L_MIN && l<=SKIN_L_MAX;

    if (isSkin) {
      const newL = Math.min(92, Math.max(8, l * skinPreset.lScale));
      const [nr,ng,nb] = hslToRgb(skinPreset.h, skinPreset.s, newL);
      data[i]=nr; data[i+1]=ng; data[i+2]=nb;

    } else if (l < PANTS_L_MAX && s < PANTS_S_MAX) {
      // Pantalones / zapatos → mismo tono oscuro en todas las anims
      const [nr,ng,nb] = hslToRgb(PANTS_TARGET.h, PANTS_TARGET.s, l);
      data[i]=nr; data[i+1]=ng; data[i+2]=nb;

    } else if (l > APRON_L_MIN && s < APRON_S_MAX) {
      // Delantal / camisa → mismo blanco grisáceo cálido
      // Escala L para que el máximo quede en ~84 (tono del walk)
      const newL = APRON_L_MIN + (l - APRON_L_MIN) * (84 - APRON_L_MIN) / (96 - APRON_L_MIN);
      const [nr,ng,nb] = hslToRgb(APRON_TARGET.h, APRON_TARGET.s, Math.min(84, newL));
      data[i]=nr; data[i+1]=ng; data[i+2]=nb;
    }
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────
(async () => {
  for (const variant of VARIANTS) {
    const dir = path.join(BASE, variant.name);
    console.log(`\n▶ ${variant.name}`);
    for (const anim of ANIMS) {
      const animDir = path.join(dir, anim);
      if (!fs.existsSync(animDir)) continue;
      const files = fs.readdirSync(animDir)
        .filter(f => f.endsWith('.png') && !f.includes('.import') && !f.includes('bk'));
      if (!files.length) continue;
      for (const file of files) {
        const imgPath = path.join(animDir, file);
        const img = await Jimp.read(imgPath);
        processPixels(img.bitmap.data, variant.skin);
        await img.write(imgPath);
      }
      process.stdout.write(`  ✓ ${anim} (${files.length})\n`);
    }
  }
  console.log('\nListo.');
})().catch(console.error);
