// Muestra distribución de H y S para píxeles oscuros (L < 38, no piel) en death____009.png
const { Jimp } = require('jimp');
const path = require('path');

const SRC = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\waiter\\death\\death____009.png';

const SKIN_H_MIN=5,SKIN_H_MAX=40,SKIN_S_MIN=28,SKIN_S_MAX=95,SKIN_L_MIN=10,SKIN_L_MAX=78;

function rgbToHsl(r,g,b){r/=255;g/=255;b/=255;const mx=Math.max(r,g,b),mn=Math.min(r,g,b);let h=0,s=0,l=(mx+mn)/2;if(mx!==mn){const d=mx-mn;s=l>.5?d/(2-mx-mn):d/(mx+mn);switch(mx){case r:h=((g-b)/d+(g<b?6:0))/6;break;case g:h=((b-r)/d+2)/6;break;case b:h=((r-g)/d+4)/6;}}return[h*360,s*100,l*100];}

(async()=>{
  const img  = await Jimp.read(SRC);
  const data = img.bitmap.data;

  // Separo por S baja (posible sombra de blanco) vs S media/alta (posible pantalón)
  const lowS  = [];  // S < 10 — casi gris puro
  const midS  = [];  // 10 <= S < 30
  const highS = [];  // S >= 30

  for(let i=0;i<data.length;i+=4){
    if(data[i+3]<200) continue;
    const [h,s,l]=rgbToHsl(data[i],data[i+1],data[i+2]);
    const isSkin=h>=SKIN_H_MIN&&h<=SKIN_H_MAX&&s>=SKIN_S_MIN&&s<=SKIN_S_MAX&&l>=SKIN_L_MIN&&l<=SKIN_L_MAX;
    if(isSkin) continue;
    if(l>=38) continue;   // solo oscuros
    if(s<10)       lowS.push({h,s,l});
    else if(s<30)  midS.push({h,s,l});
    else           highS.push({h,s,l});
  }

  const summary = (arr, label) => {
    if(!arr.length){console.log(`  ${label}: 0 px`);return;}
    const hAvg = arr.reduce((a,p)=>a+p.h,0)/arr.length;
    const sAvg = arr.reduce((a,p)=>a+p.s,0)/arr.length;
    const lAvg = arr.reduce((a,p)=>a+p.l,0)/arr.length;
    const lMin = Math.min(...arr.map(p=>p.l));
    const lMax = Math.max(...arr.map(p=>p.l));
    console.log(`  ${label}: ${arr.length}px  H avg ${hAvg.toFixed(0)}°  S avg ${sAvg.toFixed(1)}%  L avg ${lAvg.toFixed(1)}% [${lMin.toFixed(0)}-${lMax.toFixed(0)}]`);
  };

  console.log('=== death____009  píxeles oscuros (L < 38, no piel) ===');
  summary(lowS,  'S <  10  (sombra blanco?)');
  summary(midS,  'S 10-30  (pliegue pantalón?)');
  summary(highS, 'S >= 30  (color saturado)');
})().catch(console.error);
