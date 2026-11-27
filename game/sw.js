// Neon Gölgeler — güncelleme servis çalışanı (AutoUpdater)
// İndirilen yeni paket dosyaları 'ng-pkg' önbelleğinde tutulur ve yerleşik dosyaların yerine sunulur.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin || url.searchParams.has('ngbypass')) return;
  let path = url.pathname; if (path.endsWith('/')) path += 'index.html';
  e.respondWith(caches.open('ng-pkg').then(c => c.match(path)).then(r => r || fetch(req)).catch(() => fetch(req)));
});
