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
  ['examples/jsm/environments/RoomEnvironment.js', 'addons/environments/RoomEnvironment.js'],
  ['examples/jsm/loaders/DRACOLoader.js', 'addons/loaders/DRACOLoader.js'],
  ['examples/jsm/utils/SkeletonUtils.js', 'addons/utils/SkeletonUtils.js'],
  ['examples/jsm/geometries/RoundedBoxGeometry.js', 'addons/geometries/RoundedBoxGeometry.js'],
  ['examples/jsm/postprocessing/EffectComposer.js', 'addons/postprocessing/EffectComposer.js'],
  ['examples/jsm/postprocessing/RenderPass.js', 'addons/postprocessing/RenderPass.js'],
  ['examples/jsm/postprocessing/UnrealBloomPass.js', 'addons/postprocessing/UnrealBloomPass.js'],
  ['examples/jsm/postprocessing/OutputPass.js', 'addons/postprocessing/OutputPass.js'],
  ['examples/jsm/postprocessing/Pass.js', 'addons/postprocessing/Pass.js'],
  ['examples/jsm/postprocessing/ShaderPass.js', 'addons/postprocessing/ShaderPass.js'],
  ['examples/jsm/postprocessing/MaskPass.js', 'addons/postprocessing/MaskPass.js'],
  ['examples/jsm/shaders/CopyShader.js', 'addons/shaders/CopyShader.js'],
  ['examples/jsm/shaders/LuminosityHighPassShader.js', 'addons/shaders/LuminosityHighPassShader.js'],
  ['examples/jsm/shaders/OutputShader.js', 'addons/shaders/OutputShader.js'],
  ['examples/jsm/libs/draco/gltf/draco_decoder.js', 'addons/libs/draco/gltf/draco_decoder.js'],
  ['examples/jsm/libs/draco/gltf/draco_decoder.wasm', 'addons/libs/draco/gltf/draco_decoder.wasm'],
  ['examples/jsm/libs/draco/gltf/draco_wasm_wrapper.js', 'addons/libs/draco/gltf/draco_wasm_wrapper.js']
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
