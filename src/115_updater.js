// ============================================================================
//  AutoUpdater — oyun içi güncelleme (tam kurulum dosyası indirmeden)
//  version.json → { version, mandatory, notes, baseUrl, files:[{path,url?,sha256?,size?}],
//                   shell:{ minShell, exeUrl, apkUrl } }
//  Paket dosyaları SHA-256 ile doğrulanıp servis çalışanı önbelleğine ('ng-pkg') yazılır;
//  sonraki açılışta yeni dosyalar yerleşik olanların yerine sunulur. Kabuk (Electron/APK)
//  sürümü gerekiyorsa electron-updater / APK indirme kancası devreye girer.
// ============================================================================
const PKG_VER_KEY = 'ng_pkg_ver';
const DEFAULT_UPDATE_URLS = [
  'https://raw.githubusercontent.com/hllakbnr/neon-golgeler/main/game/version.json',
  'https://cdn.jsdelivr.net/gh/hllakbnr/neon-golgeler@main/game/version.json'
];
const SHELL = (() => {
  const q = new URLSearchParams(location.search).get('shell');
  if (window.ngShell) return { kind: 'electron', version: window.ngShell.version };
  if (q && q.startsWith('apk-')) return { kind: 'apk', version: q.slice(4) };
  return { kind: 'web', version: NG_VERSION };
})();
const cmpVer = (a, b) => { const x = String(a || '0').split('.').map(Number), y = String(b || '0').split('.').map(Number); for (let i = 0; i < Math.max(x.length, y.length); i++) { const d = (x[i] || 0) - (y[i] || 0); if (d) return d > 0 ? 1 : -1; } return 0; };

const AutoUpdater = {
  swOk: false, busy: false, latest: null,
  get current() { return NG_VERSION; },
  async init() {
    if (!('serviceWorker' in navigator) || !/^https?:$/.test(location.protocol)) return;
    try {
      await navigator.serviceWorker.register('./sw.js', { scope: './' });
      await navigator.serviceWorker.ready; this.swOk = true;
      // yerleşik paket önbellektekinden yeniyse (yeni .exe/.apk kuruldu) eski önbelleği temizle
      const pkg = localStorage.getItem(PKG_VER_KEY);
      if (pkg) {
        const r = await fetch('./version.json?ngbypass=1', { cache: 'no-store' }).catch(() => null);
        const built = r && r.ok ? (await r.json()).version : null;
        if (built && cmpVer(built, pkg) >= 0) { await caches.delete('ng-pkg'); localStorage.removeItem(PKG_VER_KEY); if (cmpVer(NG_VERSION, built) < 0) location.reload(); }
      }
    } catch (e) { console.warn('Servis çalışanı kaydedilemedi:', e.message); }
  },
  urls() {
    const u = [];
    if (Settings.updateUrl) u.push(Settings.updateUrl);
    if (Supa.ok()) u.push(Supa.publicUrl('version.json'));
    return u.concat(DEFAULT_UPDATE_URLS);
  },
  async fetchManifest() {
    for (const u of this.urls()) {
      try {
        const ac = new AbortController(); const to = setTimeout(() => ac.abort(), 10000);
        const r = await fetch(u + (u.includes('?') ? '&' : '?') + 't=' + Date.now(), { cache: 'no-store', signal: ac.signal }); clearTimeout(to);
        if (!r.ok) continue;
        const m = await r.json(); if (m && m.version) { m._src = u; return m; }
      } catch (e) { /* sıradaki kaynak */ }
    }
    return null;
  },
  async check(manual) {
    if (this.busy) return;
    const m = await this.fetchManifest();
    if (!m) { if (manual) UI.toast('Güncelleme sunucusuna ulaşılamadı (internet bağlantını kontrol et)'); return; }
    this.latest = m;
    if (cmpVer(m.version, this.current) <= 0) {
      if (m.shell && cmpVer(m.shell.minShell, SHELL.version) > 0 && SHELL.kind !== 'web') return this.shellPrompt(m);
      if (manual) UI.toast('✓ Oyun güncel (sürüm ' + this.current + ')');
      return;
    }
    this.prompt(m);
  },
  prompt(m) {
    const needShell = m.shell && SHELL.kind !== 'web' && cmpVer(m.shell.minShell, SHELL.version) > 0;
    const el = $('updater');
    el.innerHTML = `<h2>⬇ Yeni sürüm: ${m.version}</h2><p style="color:var(--dim);font-size:13px">Yüklü sürüm: ${this.current}${m.mandatory ? ' · <b style="color:#ff7a9a">Zorunlu güncelleme</b>' : ''}</p>
      <div class="card" style="white-space:pre-wrap;max-height:30vh;overflow:auto">${(m.notes || 'İyileştirmeler ve hata düzeltmeleri.').replace(/</g, '&lt;')}</div>
      ${needShell ? `<p style="color:#ffb020;font-size:13px">Bu sürüm yeni bir ${SHELL.kind === 'apk' ? 'uygulama (APK)' : 'masaüstü kabuğu'} gerektiriyor.</p>` : ''}
      <div class="barw" style="margin:12px 0 4px"><div id="updbar" style="width:0%;background:linear-gradient(90deg,var(--neon),var(--cyan));height:100%"></div></div><div id="updtxt" style="font-size:12px;color:var(--dim)"></div>
      <div class="row" style="margin-top:10px">${UI.btn(needShell ? '⬇ Uygulamayı güncelle' : '⬇ Şimdi güncelle ve yeniden başlat', () => needShell ? this.shellUpdate(m) : this.apply(m), 'alt')}${m.mandatory ? '' : UI.btn('Sonra', () => { el.classList.add('hidden'); Game.inputLock = Math.max(0, Game.inputLock - 1); })}</div>`;
    el.classList.remove('hidden'); Game.inputLock++;
    if (document.pointerLockElement) document.exitPointerLock();
  },
  shellPrompt(m) { this.prompt(Object.assign({}, m, { notes: (m.notes || '') + '\n\nUygulama kabuğu güncellemesi mevcut.' })); },
  async sha256(buf) { const h = await crypto.subtle.digest('SHA-256', buf); return [...new Uint8Array(h)].map(b => b.toString(16).padStart(2, '0')).join(''); },
  async apply(m) {
    if (this.busy) return; this.busy = true;
    const bar = $('updbar'), txt = $('updtxt');
    try {
      if (!this.swOk) throw new Error('Bu ortamda oyun içi güncelleme desteklenmiyor; yeni sürümü Releases sayfasından indir.');
      const base = m.baseUrl || m._src.replace(/version\.json.*$/, '');
      const files = m.files || [{ path: 'index.html' }];
      const total = files.reduce((a, f) => a + (f.size || 1), 0); let done = 0;
      await caches.delete('ng-pkg-staging');
      const stage = await caches.open('ng-pkg-staging');
      for (const f of files) {
        txt.textContent = 'İndiriliyor: ' + f.path;
        const url = f.url || (base + f.path);
        const r = await fetch(url + (url.includes('?') ? '&' : '?') + 'v=' + encodeURIComponent(m.version), { cache: 'no-store' });
        if (!r.ok) throw new Error(f.path + ' indirilemedi (' + r.status + ')');
        const buf = await r.arrayBuffer();
        if (f.sha256) { const h = await this.sha256(buf); if (h !== f.sha256) throw new Error(f.path + ' bütünlük doğrulaması başarısız'); }
        const type = /\.html$/.test(f.path) ? 'text/html; charset=utf-8' : /\.m?js$/.test(f.path) ? 'text/javascript; charset=utf-8' : /\.json$/.test(f.path) ? 'application/json' : /\.wasm$/.test(f.path) ? 'application/wasm' : 'application/octet-stream';
        const path = new URL(f.path, location.href).pathname;
        await stage.put(path, new Response(buf, { headers: { 'Content-Type': type } }));
        done += f.size || 1; bar.style.width = Math.round(done / total * 100) + '%';
      }
      // önbellekleri değiştir (atomik)
      txt.textContent = 'Uygulanıyor…';
      await caches.delete('ng-pkg'); const live = await caches.open('ng-pkg');
      for (const req of await stage.keys()) await live.put(req, await stage.match(req));
      await caches.delete('ng-pkg-staging');
      localStorage.setItem(PKG_VER_KEY, m.version);
      saveGame && Game.player && saveGame();
      txt.textContent = 'Yeniden başlatılıyor…'; await wait(600);
      this.restart();
    } catch (e) { txt.textContent = '✗ ' + e.message; UI.toast('Güncelleme başarısız: ' + e.message); }
    this.busy = false;
  },
  restart() { if (window.ngShell && window.ngShell.relaunch) window.ngShell.relaunch(); else location.reload(); },
  async rollback() { if (this.swOk) await caches.delete('ng-pkg'); localStorage.removeItem(PKG_VER_KEY); UI.toast('Yerleşik sürüme dönülüyor…'); setTimeout(() => this.restart(), 600); },
  shellUpdate(m) {
    if (SHELL.kind === 'electron' && window.ngShell.checkShellUpdate) { window.ngShell.checkShellUpdate(); UI.toast('Masaüstü güncellemesi indiriliyor; bitince oyun yeniden başlayacak.'); return; }
    const url = SHELL.kind === 'apk' ? m.shell?.apkUrl : m.shell?.exeUrl;
    if (url) location.href = url; else UI.toast('İndirme bağlantısı bulunamadı');
  }
};
