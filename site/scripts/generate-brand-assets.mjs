import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '../..');
const publicDir = path.join(repoRoot, 'site/public');
const appIconDir = path.join(repoRoot, 'App/Assets.xcassets/AppIcon.appiconset');

const markSvg = fs.readFileSync(path.join(publicDir, 'nook-mark.svg'));

const ogSvg = `
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630" fill="none">
  <rect width="1200" height="630" fill="#f5f1e8"/>
  <g transform="translate(540 195) scale(6)" fill="none">
    <path d="M5 10.5c0-3 3.1-6 7-6s7 3 7 6" stroke="#141414" stroke-width="1.75" stroke-linecap="round"/>
    <circle cx="12" cy="16" r="2" fill="#141414"/>
  </g>
  <text x="600" y="420" text-anchor="middle" font-family="system-ui, -apple-system, sans-serif" font-size="56" font-weight="600" fill="#141414" letter-spacing="-1.5">OpenNook</text>
  <text x="600" y="470" text-anchor="middle" font-family="system-ui, -apple-system, sans-serif" font-size="28" font-weight="400" fill="#5a5a5a">Notch apps for macOS</text>
</svg>
`;

const appIconSvg = (size) => `
<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" fill="none">
  <rect width="${size}" height="${size}" rx="${size * 0.22}" fill="#141414"/>
  <g transform="translate(${size * 0.125} ${size * 0.125}) scale(${size / 32})" fill="none">
    <path d="M5 10.5c0-3 3.1-6 7-6s7 3 7 6" stroke="#f0eee6" stroke-width="1.75" stroke-linecap="round"/>
    <circle cx="12" cy="16" r="2" fill="#f0eee6"/>
  </g>
</svg>
`;

async function writePng(svg, destination, width, height = width) {
  await sharp(Buffer.from(svg))
    .resize(width, height)
    .png()
    .toFile(destination);
}

fs.mkdirSync(appIconDir, { recursive: true });

const iconSizes = [
  ['icon_16.png', 16],
  ['icon_32.png', 32],
  ['icon_32@1x.png', 32],
  ['icon_64.png', 64],
  ['icon_128.png', 128],
  ['icon_256.png', 256],
  ['icon_512.png', 512],
  ['icon_1024.png', 1024],
];

for (const [filename, size] of iconSizes) {
  await writePng(appIconSvg(size), path.join(appIconDir, filename), size);
}

await writePng(ogSvg, path.join(publicDir, 'og-image.png'), 1200, 630);
await writePng(appIconSvg(180), path.join(publicDir, 'apple-touch-icon.png'), 180, 180);

fs.writeFileSync(
  path.join(appIconDir, 'Contents.json'),
  JSON.stringify(
    {
      images: [
        { size: '16x16', idiom: 'mac', filename: 'icon_16.png', scale: '1x' },
        { size: '16x16', idiom: 'mac', filename: 'icon_32.png', scale: '2x' },
        { size: '32x32', idiom: 'mac', filename: 'icon_32@1x.png', scale: '1x' },
        { size: '32x32', idiom: 'mac', filename: 'icon_64.png', scale: '2x' },
        { size: '128x128', idiom: 'mac', filename: 'icon_128.png', scale: '1x' },
        { size: '128x128', idiom: 'mac', filename: 'icon_256.png', scale: '2x' },
        { size: '256x256', idiom: 'mac', filename: 'icon_512.png', scale: '1x' },
        { size: '256x256', idiom: 'mac', filename: 'icon_1024.png', scale: '2x' },
      ],
      info: { version: 1, author: 'xcode' },
    },
    null,
    2
  )
);

console.log('Generated brand PNGs (og-image, app icon set, apple-touch-icon).');
