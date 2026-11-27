// Three.js r160 dosyalarını game/vendor/ altına indirir → oyun tamamen çevrimdışı çalışır
// (Electron .exe ve Android .apk paketlemeden önce bir kez çalıştırın: `npm run vendor`)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'game', 'vendor');
const BASE = 'https://unpkg.com/three@0.160.0/';
const FILES = [
  ['build/three.module.js', 'three.module.js'],
  ['examples/jsm/loaders/GLTFLoader.js', 'addons/loaders/GLTFLoader.js'],
  ['examples/jsm/loaders/OBJLoader.js', 'addons/loaders/OBJLoader.js'],
  ['examples/jsm/utils/BufferGeometryUtils.js', 'addons/utils/BufferGeometryUtils.js'],
  ['examples/jsm/environments/RoomEnvironment.js', 'addons/environments/RoomEnvironment.js']
];
for (const [src, dst] of FILES) {
  const out = path.join(ROOT, dst);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const r = await fetch(BASE + src);
  if (!r.ok) throw new Error(src + ' indirilemedi: ' + r.status);
  fs.writeFileSync(out, Buffer.from(await r.arrayBuffer()));
  console.log('✓', dst);
}
fs.writeFileSync(path.join(ROOT, 'vendor-flag.js'), 'window.NG_LOCAL_VENDOR = true;\n');
console.log('Tamam: game/vendor hazır, oyun artık CDN olmadan çalışır.');
