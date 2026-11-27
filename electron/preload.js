// Oyun sayfasına güvenli kabuk köprüsü: sürüm, yeniden başlatma, kabuk güncellemesi
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('ngShell', {
  version: ipcRenderer.sendSync('ng:version'),
  relaunch: () => ipcRenderer.send('ng:relaunch'),
  checkShellUpdate: () => ipcRenderer.send('ng:shell-update')
});
