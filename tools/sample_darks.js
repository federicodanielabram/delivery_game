// Compara distribución de L en píxeles oscuros entre throw y hurt (frame 1 de cada uno)
const { Jimp } = require('jimp');
const path = require('path');

const BASE = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\waiter';
const FRAMES = [
  { anim: 'throw', file: 'throw____001.png' },
  { anim: 'hurt',  file: 'hurt____001.png'  },
  { anim: 'death', file: 'death____001.png'  },
];

const SKIN_H_MIN=5, SKIN_H_MAX=40, SKIN_S_MIN=28, SKIN_S_MAX=95, SKIN_L_MIN=10, SKIN_L_MAX=78;
const WHITE_L_MIN=54, WHITE_S_MAX=22;

function rgbToHsl(r,g,b){
  r/=255;g/=255;b/=255;
  const mx=Math.max(r,g,b),mn=Math.min(r,g,b);
  let h=0,s=0,l=(mx+mn)/2;
  if(mx!==mn){const d=mx-mn;s=l>.5?d/(2-mx-mn):d/(mx+mn);
    switch(mx){case r:h=((g-b)/d+(g<b?6:0))/6;break;case g:h=((b-r)/d+2)/6;break;case b:h=((r-g)/d+4)/6;}}
  return[h*360,s*100,l*100];
}

(async()=>{
  for(const {anim, file} of FRAMES){
    const img  = await Jimp.read(path.join(BASE, anim, file));
    const data = img.bitmap.data;

    // Acumular L de todos los píxeles que NO son piel ni blancos — los oscuros/medios
    const buckets = new Array(10).fill(0); // 0-10, 10-20, ..., 90-100
    let total = 0;
    for(let i=0;i<data.length;i+=4){
      if(data[i+3]<200) continue;
      const [h,s,l] = rgbToHsl(data[i],data[i+1],data[i+2]);
      const isSkin = h>=SKIN_H_MIN&&h<=SKIN_H_MAX&&s>=SKIN_S_MIN&&s<=SKIN_S_MAX&&l>=SKIN_L_MIN&&l<=SKIN_L_MAX;
      const isWhite = l>WHITE_L_MIN&&s<WHITE_S_MAX;
      if(!isSkin && !isWhite){
        const bucket = Math.min(9, Math.floor(l/10));
        buckets[bucket]++;
        total++;
      }
    }
    console.log(`\n=== ${anim} (no-piel, no-blanco) ===`);
    for(let b=0;b<10;b++){
      const from=b*10, to=from+10;
      const pct = total>0 ? (buckets[b]/total*100).toFixed(1) : '0.0';
      const bar = '█'.repeat(Math.round(buckets[b]/total*40));
      console.log(`  L ${String(from).padStart(2)}-${String(to).padStart(2)}%: ${String(buckets[b]).padStart(5)}px (${pct.padStart(5)}%) ${bar}`);
    }
  }
})().catch(console.error);
