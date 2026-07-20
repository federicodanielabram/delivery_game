// Samplea throw___001.png del original para extraer valores de referencia
// de blancos (delantal/camisa) y negros (pantalones/zapatos).

const { Jimp } = require('jimp');

const SRC = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\waiter\\throw\\throw____001.png';

const SKIN_H_MIN=5, SKIN_H_MAX=40, SKIN_S_MIN=28, SKIN_S_MAX=95, SKIN_L_MIN=10, SKIN_L_MAX=78;
const LIGHT_L_MIN=55, LIGHT_S_MAX=30;
const DARK_L_MAX=24,  DARK_S_MAX=55;

function rgbToHsl(r,g,b){r/=255;g/=255;b/=255;const mx=Math.max(r,g,b),mn=Math.min(r,g,b);let h=0,s=0,l=(mx+mn)/2;if(mx!==mn){const d=mx-mn;s=l>.5?d/(2-mx-mn):d/(mx+mn);switch(mx){case r:h=((g-b)/d+(g<b?6:0))/6;break;case g:h=((b-r)/d+2)/6;break;case b:h=((r-g)/d+4)/6;}}return[h*360,s*100,l*100];}

(async()=>{
  const img  = await Jimp.read(SRC);
  const data = img.bitmap.data;

  let lH=0,lS=0,lLsum=0,lLmin=100,lLmax=0,lN=0;
  let dH=0,dS=0,dLsum=0,dN=0;

  for(let i=0;i<data.length;i+=4){
    if(data[i+3]<200) continue;
    const [h,s,l]=rgbToHsl(data[i],data[i+1],data[i+2]);
    const skin=h>=SKIN_H_MIN&&h<=SKIN_H_MAX&&s>=SKIN_S_MIN&&s<=SKIN_S_MAX&&l>=SKIN_L_MIN&&l<=SKIN_L_MAX;
    if(skin) continue;
    if(l>LIGHT_L_MIN&&s<LIGHT_S_MAX){lH+=h;lS+=s;lLsum+=l;lLmin=Math.min(lLmin,l);lLmax=Math.max(lLmax,l);lN++;}
    else if(l<DARK_L_MAX&&s<DARK_S_MAX){dH+=h;dS+=s;dLsum+=l;dN++;}
  }

  console.log('=== BLANCOS (delantal/camisa) ===');
  console.log(`  H avg: ${(lH/lN).toFixed(1)}°`);
  console.log(`  S avg: ${(lS/lN).toFixed(1)}%`);
  console.log(`  L avg: ${(lLsum/lN).toFixed(1)}%  min:${lLmin.toFixed(1)}  max:${lLmax.toFixed(1)}`);
  console.log(`  pixels: ${lN}`);
  console.log('=== NEGROS (pantalones/zapatos) ===');
  console.log(`  H avg: ${(dH/dN).toFixed(1)}°`);
  console.log(`  S avg: ${(dS/dN).toFixed(1)}%`);
  console.log(`  L avg: ${(dLsum/dN).toFixed(1)}%`);
  console.log(`  pixels: ${dN}`);
})().catch(console.error);
