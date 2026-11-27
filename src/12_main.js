// ============================================================================
//  ANA DÖNGÜ — yükleme, başlık menüsü, yeni oyun/devam, sistem güncelleme sırası
// ============================================================================
const Main = {
  fps: 60, last: 0, acc: 0, frames: 0, fpsT: 0, saveT: 0,
  async init() {
    const fill = $('loadfill'), txt = $('loadtxt');
    const prog = (k, t) => { fill.style.width = Math.round(k * 100) + '%'; if (t) txt.textContent = t; };
    try {
      prog(0.02, 'Renderer hazırlanıyor…');
      Render.init(); Input.init(); UI.init(); Projectiles.init();
      prog(0.08, 'Önbellek (IndexedDB) açılıyor…');
      await AssetCache.open();
      if (Supa.ok()) { prog(0.1, 'Supabase sürüm kontrolü…'); await AssetManager.syncRemote(); }
      prog(0.12, 'Varlıklar önbellekten yükleniyor…');
      await AssetManager.loadAll((k) => prog(0.12 + k * 0.18));
      prog(0.3, 'Hazır 3D modeller (önbellek / internet)…');
      await AssetManager.loadLibrary((k) => prog(0.3 + k * 0.1, 'Hazır 3D modeller… ' + Math.round(k * 100) + '%'));
      prog(0.4, 'Şehir inşa ediliyor…'); await wait(16);
      World.build((k) => prog(0.4 + k * 0.52, 'Şehir inşa ediliyor… ' + Math.round(k * 100) + '%'));
      prog(0.96, 'Gölgeler ısınıyor…');
      Game.camera.position.set(-300, 60, 560); Game.camera.lookAt(-320, 0, 480);
      Sky.update(0.016); Game.renderer.render(Game.scene, Game.camera);
      prog(1, 'Hazır');
    } catch (e) { console.error(e); txt.textContent = 'Başlatma hatası: ' + e.message; return; }
    $('loading').classList.add('hidden');
    this.title();
    AutoUpdater.init().then(() => setTimeout(() => AutoUpdater.check(false), 1500));
    this.last = performance.now(); requestAnimationFrame((t) => this.loop(t));
    document.addEventListener('visibilitychange', () => { if (document.hidden && Game.mode === 'play' && !Game.paused) { saveGame(); UI.pause(); } });
    addEventListener('beforeunload', () => { if (Game.player) saveGame(); });
  },
  title() {
    $('title').classList.remove('hidden');
    const has = !!localStorage.getItem(SAVE_KEY);
    $('btnContinue').style.display = has ? '' : 'none';
    $('btnContinue').onclick = () => this.start(false);
    $('btnNew').onclick = () => { if (has) { if (!$('btnNew').dataset.confirm) { $('btnNew').dataset.confirm = 1; $('btnNew').textContent = '⚠ Kayıt silinecek — tekrar bas'; return; } } this.start(true); };
    $('btnSettings').onclick = () => UI.settings();
    $('btnAdmin').onclick = () => UI.admin();
  },
  start(isNew) {
    Sound.init();
    if (isNew) { S = freshState(); localStorage.removeItem(SAVE_KEY); } else loadGame();
    $('title').classList.add('hidden'); $('hud').classList.remove('hidden');
    const sp = S.pos || [LOC.harborGate[0], 0, LOC.harborGate[1]];
    const pl = Player.create(_v1.set(sp[0], World.groundAt(sp[0], sp[2], (sp[1] || 0) + 1), sp[2]));
    pl.yaw = Math.PI;
    if (S.allyWith) { Ally.spawn(_v1.set(sp[0] + 2, pl.pos.y, sp[2] + 2)); }
    if (S.vehicles.length && !isNew) Vehicles.deliver(S.vehicles[0], [sp[0] + 6, sp[2] + 4]);
    if (S.flags.curfew) Sky.curfew = true;
    Eggs.setup();
    Bus.on('modelLoaded', () => { clearTimeout(this._rb); this._rb = setTimeout(() => this.rebuildFigures(), 50); });
    Cam.yaw = Math.PI * 1.2; Cam.snap();
    Game.mode = 'play'; UI.updateHint();
    $('touch').classList.toggle('hidden', Input.device !== 'touch');
    Missions.refreshMarkers();
    if (isNew) setTimeout(() => Missions.start(MISSIONS[0]), 400);
    else UI.toast('Hoş geldin, ' + CAST.Hero_Main.name + '. Kaldığın yerden devam.');
  },
  rebuildFigures() {
    for (const a of Game.actors) { a.fig.rebuild(); if (a.kind === 'player') a.fig.setMask(S.mask); }
    for (const v of Game.vehicles) { if (AssetManager.templates['veh_' + v.type]) { Game.scene.remove(v.mesh); v.mesh = v.build(); Game.scene.add(v.mesh); } }
  },
  loop(t) {
    requestAnimationFrame((tt) => this.loop(tt));
    let dt = (t - this.last) / 1000; this.last = t; if (dt > 0.05) dt = 0.05; if (dt <= 0) dt = 0.001;
    this.frames++; this.fpsT += dt; if (this.fpsT > 0.5) { this.fps = this.frames / this.fpsT; this.frames = 0; this.fpsT = 0; }
    Game.dt = dt;
    Input.poll();
    UI.update(dt);
    if (Game.mode === 'title' || !Game.player) { Game.t += dt; SHARED_UNI.uTime.value = Game.t; Sky.update(dt * 0.2); this.titleCam(dt); Render.draw(); return; }
    if (!Game.paused) {
      Game.t += dt; SHARED_UNI.uTime.value = Game.t;
      Sky.update(dt);
      Player.update(dt);
      Ally.update(dt);
      Friends.update(dt);
      Enemies.update(dt);
      for (const a of Game.actors.slice()) if (!a.removed) a.update(dt);
      Vehicles.updateTraffic(dt);
      Vehicles.updateAll(dt);
      Crime.update(dt);
      Population.update(dt);
      Projectiles.update(dt);
      FX.update(dt);
      Pickups.update(dt);
      Missions.update(dt);
      Interact.update();
      LightPool.update(dt);
      this.saveT += dt; if (this.saveT > 60 && Game.mode === 'play') { this.saveT = 0; saveGame(); }
    }
    World.updateCulling();
    Cam.update(dt);
    Render.draw();
  },
  titleCam(dt) {
    const a = Game.t * 0.05, c = Game.camera;
    c.position.set(Math.cos(a) * 260, 70 + Math.sin(a * 0.7) * 20, Math.sin(a) * 260); c.lookAt(0, 20, 0);
    Render.sky.position.copy(c.position);
    World.updateCulling();
  }
};
// Hata ayıklama kancası (konsoldan: __NG.S, __NG.Missions …)
window.__NG = { get S() { return S; }, Bus, Game, Missions, Player, Ally, World, Vehicles, Enemies, Crime, Cutscene, UI, Input, Sky, Friends, Pickups, Eggs, Population, Main, AssetManager, AssetCache, Supa, Dragon, Combat, Cam, AutoUpdater, MISSIONS, SIDES, ACTIVITIES, EGGS, LOC, CAST, saveGame };
Main.init();
