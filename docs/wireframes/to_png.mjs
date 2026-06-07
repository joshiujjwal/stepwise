import { Resvg } from '@resvg/resvg-js';
import { readFileSync, writeFileSync, readdirSync } from 'fs';
for (const f of readdirSync('.').filter(x => x.endsWith('.svg'))) {
  const svg = readFileSync(f, 'utf8');
  const value = f.includes('flow') ? 2600 : 1200;
  const r = new Resvg(svg, { background: 'white', fitTo: { mode: 'width', value } });
  const png = r.render().asPng();
  const out = f.replace('.svg', '.png');
  writeFileSync(out, png);
  console.log('wrote', out, png.length, 'bytes');
}
