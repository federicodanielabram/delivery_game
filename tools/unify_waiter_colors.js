// Unifica colores de walk, throw, hurt, death para los 3 mozos.
// Blancos (camisa/delantal): H=30, S=8 — neutro cálido limpio, L escalado al rango del throw.
// Negros (pantalones/zapatos): H=249, S=23, L preservado.
// Piel: preset por variante.

const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const BASE  = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies';
const ANIMS = ['walk','throw','hurt','death'];

// waiter al final — dark y light leen los originales sin tocar
const VARIANTS = [
  { name: 'waiter_dark',  skin: { h: 22, s: 50, lScale: 0.70 } },
  { name: 'waiter_light', skin: { h: 14, s: 30, lScale: 1.24 } },
  { name: 'waiter',       skin: { h: 18, s: 52, lScale: 1.00 } },
];

const WHITE_H = 0,   WHITE_S = 3;   // delantal/camisa: blanco neutro puro
const DARK_H  = 249, DARK_S  = 23;  // pantalones/zapatos: negro azulado oscuro

// Rangos de detección
const SKIN_H_MIN=5,  SKIN_H_MAX=40, SKIN_S_MIN=28, SKIN_S_MAX=95, SKIN_L_MIN=10, SKIN_L_MAX=78;
// Blancos bien iluminados: L > 54, S < 22
// Blancos en sombra/pose agachada (ej. death____009): L 40-54, S < 15 (más estricto en sat)
const WHITE_L_MIN=54, WHITE_S_MAX=22;
const WHITE_SHADOW_L_MIN=40, WHITE_SHADOW_S_MAX=15;
const DARK_L_MAX=38,  DARK_S_MAX=55;

// ── Color helpers ─────────────────────────────────────────────────────────────
function rgbToHsl(r,g,b){
  r/=255;g/=255;b/=255;
  const mx=Math.max(r,g,b),mn=Math.min(r,g,b);
  let h=0,s=0,l=(mx+mn)/2;
  if(mx!==mn){
    const d=mx-mn;s=l>.5?d/(2-mx-mn):d/(mx+mn);
    switch(mx){case r:h=((g-b)/d+(g<b?6:0))/6;break;case g:h=((b-r)/d+2)/6;break;case b:h=((r-g)/d+4)/6;}
  }
  return[h*360,s*100,l*100];
}
function h2r(p,q,t){if(t<0)t+=1;if(t>1)t-=1;if(t<1/6)return p+(q-p)*6*t;if(t<.5)return q;if(t<2/3)return p+(q-p)*(2/3-t)*6;return p;}
function hslToRgb(h,s,l){
  h/=360;s/=100;l/=100;
  if(s===0){const v=Math.round(l*255);return[v,v,v];}
  const q=l<.5?l*(1+s):l+s-l*s,p=2*l-q;
  return[Math.round(h2r(p,q,h+1/3)*255),Math.round(h2r(p,q,h)*255),Math.round(h2r(p,q,h-1/3)*255)];
}


async function processFolder(srcDir, dstDir, skinPreset) {
  if (!fs.existsSync(srcDir)) return;
  fs.mkdirSync(dstDir, { recursive: true });

  const files = fs.readdirSync(srcDir)
    .filter(f => f.endsWith('.png') && !f.includes('.import') && !f.includes('bk'))
    .sort();

  for (const file of files) {
    const img  = await Jimp.read(path.join(srcDir, file));
    const data = img.bitmap.data;

    const isWhitePx = (s, l) =>
      (l > WHITE_L_MIN && s < WHITE_S_MAX) ||
      (l >= WHITE_SHADOW_L_MIN && l <= WHITE_L_MIN && s < WHITE_SHADOW_S_MAX);

    for (let i = 0; i < data.length; i += 4) {
      if (data[i+3] < 200) continue;
      const [h,s,l] = rgbToHsl(data[i],data[i+1],data[i+2]);
      const isSkin = h>=SKIN_H_MIN&&h<=SKIN_H_MAX&&s>=SKIN_S_MIN&&s<=SKIN_S_MAX&&l>=SKIN_L_MIN&&l<=SKIN_L_MAX;

      if (isSkin) {
        const nl = Math.min(92, Math.max(8, l * skinPreset.lScale));
        const [nr,ng,nb] = hslToRgb(skinPreset.h, skinPreset.s, nl);
        data[i]=nr; data[i+1]=ng; data[i+2]=nb;

      } else if (isWhitePx(s, l)) {
        // L intacto — preserva profundidad natural del tejido
        const [nr,ng,nb] = hslToRgb(WHITE_H, WHITE_S, l);
        data[i]=nr; data[i+1]=ng; data[i+2]=nb;

      } else if (l < DARK_L_MAX && s < DARK_S_MAX) {
        const [nr,ng,nb] = hslToRgb(DARK_H, DARK_S, l);
        data[i]=nr; data[i+1]=ng; data[i+2]=nb;
      }
    }

    await img.write(path.join(dstDir, file));
  }
  process.stdout.write(`  ✓ ${path.basename(srcDir)} (${files.length})\n`);
}

(async () => {
  const origBase = path.join(BASE, 'waiter');

  for (const variant of VARIANTS) {
    console.log(`\n▶ ${variant.name}`);
    const dstBase = path.join(BASE, variant.name);

    for (const anim of ANIMS) {
      // Siempre partimos del original para garantizar base limpia
      const srcDir = path.join(origBase, anim);
      const dstDir = path.join(dstBase, anim);
      await processFolder(srcDir, dstDir, variant.skin);
    }
  }
  console.log('\nListo.');
})().catch(console.error);
