const { createCanvas } = require('canvas');
const fs = require('fs');
global.Path2D = global.Path2D || require('canvas').Path2D;
const { buildScene } = require('./plate.js');
const t0=Date.now();
const s = buildScene((w,h)=>createCanvas(w,h));
console.log('build ms', Date.now()-t0);
fs.writeFileSync('plate.png', s.plate.toBuffer('image/png'));
const comp = createCanvas(2400,1350), c = comp.getContext('2d');
c.drawImage(s.plate,0,0); c.drawImage(s.mask,0,0);
fs.writeFileSync('composite.png', comp.toBuffer('image/png'));
// downscaled preview
const sm = createCanvas(1200,675); sm.getContext('2d').drawImage(comp,0,0,1200,675);
fs.writeFileSync('preview.png', sm.toBuffer('image/png'));
console.log(JSON.stringify({h:s.horizon,win:s.win}));
fs.writeFileSync('mask.png', s.mask.toBuffer('image/png'));
