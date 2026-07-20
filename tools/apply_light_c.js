const { Jimp } = require('jimp');
const fs   = require('fs');
const path = require('path');

const SRC_BASE = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\waiter';
const DST_BASE = 'C:\\Users\\Titin\\proyectos\\delivery_game\\assets\\sprites\\enemies\\waiter_light';
const ANIMS    = ['walk','walk_to_idle','idle_to_walk','throw','hurt','death'];

const PRESET = { h: 14, s: 30, lScale: 1.24 };

const SKIN_H_MIN=5,SKIN_H_MAX=40,SKIN_S_MIN=28,SKIN_S_MAX=95,SKIN_L_MIN=10,SKIN_L_MAX=78;

function rgbToHsl(r,g,b){r/=255;g/=255;b/=255;const mx=Math.max(r,g,b),mn=Math.min(r,g,b);let h=0,s=0,l=(mx+mn)/2;if(mx!==mn){const d=mx-mn;s=l>.5?d/(2-mx-mn):d/(mx+mn);switch(mx){case r:h=((g-b)/d+(g<b?6:0))/6;break;case g:h=((b-r)/d+2)/6;break;case b:h=((r-g)/d+4)/6;}}return[h*360,s*100,l*100];}
function h2r(p,q,t){if(t<0)t+=1;if(t>1)t-=1;if(t<1/6)return p+(q-p)*6*t;if(t<.5)return q;if(t<2/3)return p+(q-p)*(2/3-t)*6;return p;}
function hslToRgb(h,s,l){h/=360;s/=100;l/=100;if(s===0){const v=Math.round(l*255);return[v,v,v];}const q=l<.5?l*(1+s):l+s-l*s,p=2*l-q;return[Math.round(h2r(p,q,h+1/3)*255),Math.round(h2r(p,q,h)*255),Math.round(h2r(p,q,h-1/3)*255)];}

(async () => {
  for (const anim of ANIMS) {
    const srcDir = path.join(SRC_BASE, anim);
    const dstDir = path.join(DST_BASE, anim);
    if (!fs.existsSync(srcDir)) continue;
    fs.mkdirSync(dstDir, { recursive: true });

    const files = fs.readdirSync(srcDir).filter(f => f.endsWith('.png') && !f.includes('.import'));
    for (const file of files) {
      const img  = await Jimp.read(path.join(srcDir, file));
      const data = img.bitmap.data;
      for (let i = 0; i < data.length; i += 4) {
        if (data[i+3] < 200) continue;
        const [h,s,l] = rgbToHsl(data[i],data[i+1],data[i+2]);
        if (h>=SKIN_H_MIN&&h<=SKIN_H_MAX&&s>=SKIN_S_MIN&&s<=SKIN_S_MAX&&l>=SKIN_L_MIN&&l<=SKIN_L_MAX) {
          const nl = Math.min(92, Math.max(8, l * PRESET.lScale));
          const [nr,ng,nb] = hslToRgb(PRESET.h, PRESET.s, nl);
          data[i]=nr; data[i+1]=ng; data[i+2]=nb;
        }
      }
      await img.write(path.join(dstDir, file));
    }
    console.log(`✓ ${anim} (${files.length} frames)`);
  }
  console.log('Listo.');
})().catch(console.error);
