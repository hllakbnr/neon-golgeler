// Neon Gölgeler — Electron masaüstü kabuğu (Windows .exe)
// Oyunu 127.0.0.1 üzerinde küçük bir yerel sunucudan açar: ES modülleri, IndexedDB
// önbelleği ve Supabase istekleri file:// kısıtlarına takılmadan çalışır.
const { app, BrowserWindow, Menu, shell, ipcMain, dialog } = require('electron');
let autoUpdater = null; try { ({ autoUpdater } = require('electron-updater')); } catch (e) { /* geliştirme ortamı */ }

// ---- kabuk köprüsü (preload.js) + otomatik yeniden başlatma
ipcMain.on('ng:version', (e) => { e.returnValue = app.getVersion(); });
ipcMain.on('ng:relaunch', () => { app.relaunch(); app.exit(0); });
ipcMain.on('ng:shell-update', () => { if (autoUpdater) autoUpdater.checkForUpdates().catch(() => {}); });
function setupShellUpdater(win) {
  // Kurulumlu (Setup) sürümde kabuk güncellemeleri GitHub Releases'tan gelir (taşınabilir sürümde devre dışı)
  if (!autoUpdater || !app.isPackaged || process.env.PORTABLE_EXECUTABLE_DIR) return;
  autoUpdater.autoDownload = true;
  autoUpdater.on('update-downloaded', async () => {
    const r = await dialog.showMessageBox(win, { type: 'info', buttons: ['Şimdi yeniden başlat', 'Sonra'], title: 'Neon Gölgeler', message: 'Uygulama güncellemesi indirildi. Yeniden başlatılsın mı?' });
    if (r.response === 0) autoUpdater.quitAndInstall();
  });
  autoUpdater.checkForUpdates().catch(() => {});
}
const http = require('http');
const fs = require('fs');
const path = require('path');

const GAME_DIR = app.isPackaged ? path.join(process.resourcesPath, 'game') : path.join(__dirname, '..', 'game');
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.glb': 'model/gltf-binary', '.gltf': 'model/gltf+json', '.obj': 'text/plain', '.css': 'text/css', '.svg': 'image/svg+xml', '.ico': 'image/x-icon' };

function startServer() {
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split('?')[0]);
      if (p === '/') p = '/index.html';
      const file = path.normalize(path.join(GAME_DIR, p));
      if (!file.startsWith(GAME_DIR)) { res.writeHead(403); return res.end(); }
      fs.readFile(file, (err, data) => {
        if (err) { res.writeHead(404); return res.end('404'); }
        res.writeHead(200, { 'Content-Type': TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
        res.end(data);
      });
    });
    // Sabit port: IndexedDB önbelleği ve kayıtlar köken (origin) başına tutulur
    srv.listen(48219, '127.0.0.1', () => resolve(srv.address().port));
    srv.on('error', () => srv.listen(0, '127.0.0.1', () => resolve(srv.address().port)));
  });
}

async function createWindow() {
  const port = await startServer();
  const win = new BrowserWindow({
    width: 1600, height: 900, minWidth: 960, minHeight: 540, backgroundColor: '#05030f', title: 'Neon Gölgeler',
    autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, nodeIntegration: false, backgroundThrottling: false, preload: path.join(__dirname, 'preload.js') }
  });
  Menu.setApplicationMenu(null);
  win.webContents.on('before-input-event', (e, input) => {
    if (input.type === 'keyDown' && input.key === 'F11') win.setFullScreen(!win.isFullScreen());
    if (input.type === 'keyDown' && input.key === 'F12') win.webContents.toggleDevTools();
  });
  win.webContents.setWindowOpenHandler(({ url }) => { shell.openExternal(url); return { action: 'deny' }; });
  win.loadURL(`http://127.0.0.1:${port}/index.html`);
  setupShellUpdater(win);
}

app.commandLine.appendSwitch('enable-gpu-rasterization');
app.commandLine.appendSwitch('ignore-gpu-blocklist');
app.whenReady().then(createWindow);
app.on('window-all-closed', () => app.quit());
