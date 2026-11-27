// game/version.json üretir (AutoUpdater manifesti): sürüm, notlar, dosya SHA-256 değerleri.
// Kullanım: node tools/make-version.mjs "Güncelleme notları" [--mandatory] [--minShell 1.1.0]
import fs from 'node:fs'; import path from 'node:path'; import crypto from 'node:crypto'; import { fileURLToPath } from 'node:url';
const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const version = fs.readFileSync(path.join(ROOT, 'VERSION'), 'utf8').trim();
const args = process.argv.slice(2);
const notes = args.find(a => !a.startsWith('--')) || 'İyileştirmeler ve hata düzeltmeleri.';
const mi = args.indexOf('--minShell'); const minShell = mi >= 0 ? args[mi + 1] : '1.1.0';
const files = ['index.html', 'sw.js'].map(p => { const b = fs.readFileSync(path.join(ROOT, 'game', p)); return { path: p, size: b.length, sha256: crypto.createHash('sha256').update(b).digest('hex') }; });
const out = {
  version, mandatory: args.includes('--mandatory'), notes, date: new Date().toISOString(),
  baseUrl: 'https://raw.githubusercontent.com/hllakbnr/neon-golgeler/main/game/', files,
  shell: { minShell, exeUrl: 'https://github.com/hllakbnr/neon-golgeler/releases/latest', apkUrl: 'https://github.com/hllakbnr/neon-golgeler/releases/latest/download/NeonGolgeler.apk' }
};
fs.writeFileSync(path.join(ROOT, 'game', 'version.json'), JSON.stringify(out, null, 2));
console.log('version.json →', version, files.map(f => f.path + ' ' + f.sha256.slice(0, 12)).join(', '));
