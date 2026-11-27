// ============================================================================
//  ARAYÜZ — HUD, mini harita, bildirimler, diyalog (seçimli), CutscenePlayer,
//  Phone_UI, Wardrobe_Menu, silah tekerleği, dükkânlar, güvenli ev, admin paneli
// ============================================================================
UI = {
  hudT: 0, toastQ: [], modal: null, wheelSel: 0,
  init() {
    $('cskip').onclick = () => Cutscene.skip();
    $('dialog').addEventListener('click', (e) => { if (e.target.tagName !== 'BUTTON') this._dlgAdvance && this._dlgAdvance(); });
    Bus.on('inputDevice', () => this.updateHint());
    document.addEventListener('keydown', (e) => {
      if (this._dlgChoices && /^Digit[1-4]$/.test(e.code)) { const i = +e.code.slice(5) - 1; const b = this._dlgChoices[i]; if (b) { e.preventDefault(); b.click(); } }
      if (e.code === 'F10' || (e.code === 'Backquote' && e.ctrlKey)) { e.preventDefault(); this.admin(); }
    });
  },
  // ---------------------------------------------------------- temel
  toast(text, big) {
    const t = document.createElement('div'); t.className = 'toast' + (big ? ' big' : ''); t.textContent = text;
    $('toasts').appendChild(t); while ($('toasts').children.length > 4) $('toasts').firstChild.remove();
    setTimeout(() => t.remove(), big ? 4200 : 3000);
  },
  fade(v) { return new Promise(r => { $('fade').style.opacity = v; setTimeout(r, 520); }); },
  objective(t) { $('objective').textContent = t || ''; },
  prompt(t) { if ($('prompt').textContent !== (t || '')) $('prompt').textContent = t || ''; },
  updateHint() {
    const h = (a) => Input.hint(a);
    $('hint').textContent = `${h('attack')} vur · ${h('heavy')} şok dalgası · ${h('metal')} metal · ${h('spin')} kasırga · ${h('dragon')} ejderha · ${h('jump')} zıpla/süzül · ${h('interact')} etkileşim · ${h('vehicle')} araç · ${h('wheel')} silah · ${h('wardrobe')} gardırop · ${h('mask')} maske · ${h('phone')} telefon`;
  },
  showPanel(id, html) { this.closeAll(); const el = $(id); el.innerHTML = html; el.classList.remove('hidden'); this.modal = id; Game.inputLock++; if (document.pointerLockElement) document.exitPointerLock(); Sound.ui(); return el; },
  closePanel(id) { const el = $(id || this.modal); if (!el || el.classList.contains('hidden')) return; el.classList.add('hidden'); if (this.modal === (id || this.modal)) this.modal = null; Game.inputLock = Math.max(0, Game.inputLock - 1); },
  closeAll() { for (const id of ['phone', 'wardrobe', 'shop', 'pause', 'settings', 'admin']) if (!$(id).classList.contains('hidden')) this.closePanel(id); },
  btn(label, fn, cls = '') { const id = 'b' + Math.random().toString(36).slice(2, 9); setTimeout(() => { const b = document.getElementById(id); if (b) b.onclick = (e) => { e.stopPropagation(); Sound.ui(); fn(); }; }, 0); return `<button id="${id}" class="${cls}">${label}</button>`; },
  // ---------------------------------------------------------- HUD
  update(dt) {
    // modal açıkken Esc/Start kapatır
    if (this.modal && (Input.pressed('pause') || (this.modal === 'phone' && Input.pressed('phone')) || (this.modal === 'wardrobe' && Input.pressed('wardrobe')))) { this.closePanel(); Input.consume('pause'); Input.consume('phone'); Input.consume('wardrobe'); }
    if (this._dlgAdvance && !this._dlgChoices && (Input.pressed('jump') || Input.pressed('interact') || Input.pressed('next') || Input.pressed('attack'))) this._dlgAdvance();
    if (this._dlgChoices) {
      const n = this._dlgChoices.length; if (Input.pressed('spin')) this._dlgSel = (this._dlgSel - 1 + n) % n; if (Input.pressed('dragon')) this._dlgSel = (this._dlgSel + 1) % n;
      if (Input.device === 'pad') { this._dlgChoices.forEach((b, i) => b.style.borderColor = i === this._dlgSel ? '#b6ff3b' : ''); if (Input.pressed('jump')) this._dlgChoices[this._dlgSel].click(); }
    }
    if (Game.mode === 'cutscene' && (Input.pressed('pause') || Input.pressed('interact'))) Cutscene.skip();
    if (this.wheelOpen) this.wheelUpdate();
    this.hudT -= dt; if (this.hudT > 0) return; this.hudT = 0.1;
    const p = Game.player; if (!p) return;
    $('hpb').style.width = (p.hp / p.maxHp * 100) + '%';
    $('enb').style.width = Player.energy + '%';
    $('bondb').style.width = S.bondLevel + '%'; $('bondb').parentElement.style.display = S.allyUnlocked ? '' : 'none';
    const d = districtAt(p.pos.x, p.pos.z);
    $('statline').innerHTML = `💰 ${S.money} ₺ · ⭐ ${Math.floor(S.reputation)}${S.isRecognizedNinja ? ' · 🥷 <b style="color:#b6ff3b">Tanınmış Ninja</b>' : ''}<br>📍 ${d.name} · ${S.outfit === 'ninja' ? '🥷 Ninja' : '👕 Sivil'}${S.mask ? ' · 😷' : ''}${S.allyUnlocked ? ` · 💞 ${Math.floor(S.bondLevel)}` : ''}`;
    const w = Math.ceil(S.wanted);
    $('wanted').innerHTML = [1, 2, 3, 4, 5].map(i => `<span class="${i <= w ? 'on' : ''}">★</span>`).join('');
    $('wanted').classList.toggle('flash', w > 0 && Game.t - Crime.lastSeen < 3);
    $('clock').textContent = `${Sky.weatherIcon()} ${Sky.label()} · Gün ${S.day}`;
    const wp = Player.weapon(); $('weaponhud').textContent = `${wp.icon} ${wp.name}  (${S.carried.length - 1}/${MAX_CARRY})`;
    $('fps').textContent = Settings.showFps ? Math.round(Main.fps) + ' FPS · ' + Game.renderer.info.render.calls + ' çizim' : '';
    if (!p.vehicle) $('speedo').textContent = '';
    this.minimap();
    const boss = Missions.bossActor;
    $('bossbar').classList.toggle('hidden', !(boss && boss.alive));
    if (boss && boss.alive) { $('bossname').textContent = boss.name; $('bossb').style.width = (boss.hp / boss.maxHp * 100) + '%'; }
  },
  minimap() {
    const c = $('minimap'), g = c.getContext('2d'), W = c.width, H = c.height, p = Game.player.pos, sc = 0.75;
    g.save(); g.clearRect(0, 0, W, H); g.beginPath(); g.arc(W / 2, H / 2, W / 2, 0, Math.PI * 2); g.clip();
    g.fillStyle = '#0b2a4a'; g.fillRect(0, 0, W, H);
    g.translate(W / 2, H / 2); g.rotate(Cam.yaw - Math.PI); g.scale(sc, sc); g.translate(-p.x, -p.z);
    g.fillStyle = '#2a2240'; for (const r of World.land) g.fillRect(r.x0, r.z0, r.x1 - r.x0, r.z1 - r.z0);
    g.fillStyle = '#2f5a3a'; g.fillRect(World.mtn.x0, World.mtn.z0, World.mtn.x1 - World.mtn.x0, World.mtn.z1 - World.mtn.z0);
    g.strokeStyle = '#6a5a9a'; g.lineWidth = 10; g.beginPath();
    for (const [a, b] of World.roadEdges) { const A = World.roadNodes[a], B = World.roadNodes[b]; g.moveTo(A.x, A.z); g.lineTo(B.x, B.z); }
    g.stroke();
    const dot = (x, z, col, r = 5) => { g.fillStyle = col; g.beginPath(); g.arc(x, z, r / sc, 0, Math.PI * 2); g.fill(); };
    for (const m of Missions.markers) dot(m.x, m.z, m.color, 6);
    for (const s of S.safehouses) dot(LOC[s][0], LOC[s][1], '#b6ff3b', 5);
    for (const a of Game.actors) if (a.alive && !a.hidden && (a.kind === 'enemy' || (a.kind === 'police' && S.wanted > 0 && !S.isRecognizedNinja))) dot(a.pos.x, a.pos.z, a.kind === 'police' ? '#3bb0ff' : '#ff3b3b', 3);
    if (Game.ally && S.allyWith && !Game.ally.hidden) dot(Game.ally.pos.x, Game.ally.pos.z, '#7fffe0', 4);
    const tgt = Missions.target; if (tgt) dot(tgt[0], tgt[1], '#ffd23b', 7);
    if (S.waypoint) dot(S.waypoint[0], S.waypoint[1], '#ff2fd6', 6);
    g.restore();
    // hedef yön oku (kenar)
    g.save(); g.translate(W / 2, H / 2);
    g.fillStyle = '#fff'; g.beginPath(); g.moveTo(0, -8); g.lineTo(6, 6); g.lineTo(0, 3); g.lineTo(-6, 6); g.closePath();
    g.rotate(-(Game.player.yaw - Cam.yaw + Math.PI) + Math.PI); g.fill(); g.restore();
  },
  // ---------------------------------------------------------- Diyalog
  dialogLines(lines) { return this.dialog(lines); },
  dialog(lines) {
    return new Promise((resolve) => {
      const prevMode = Game.mode; if (Game.mode === 'play') Game.mode = 'dialog'; Game.inputLock++;
      if (document.pointerLockElement) document.exitPointerLock();
      const box = $('dialog'); box.classList.remove('hidden');
      let i = 0; const q = lines.slice();
      const done = () => { box.classList.add('hidden'); this._dlgAdvance = null; this._dlgChoices = null; Game.inputLock = Math.max(0, Game.inputLock - 1); if (Game.mode === 'dialog') Game.mode = prevMode === 'dialog' ? 'play' : prevMode; resolve(); };
      const show = () => {
        if (i >= q.length) return done();
        const L = q[i]; $('dch').innerHTML = ''; this._dlgChoices = null;
        if (L.choice) {
          $('dwho').textContent = 'Seçim'; $('dtxt').textContent = ''; $('dnext').style.display = 'none';
          this._dlgSel = 0;
          this._dlgChoices = L.choice.map((c, k) => {
            const b = document.createElement('button'); b.textContent = (k + 1) + '. ' + c.text;
            b.onclick = (e) => { e.stopPropagation(); Sound.ui(); this.applyChoice(c); if (c.reply) q.splice(i + 1, 0, c.reply); i++; show(); };
            $('dch').appendChild(b); return b;
          });
          return;
        }
        $('dnext').style.display = '';
        $('dwho').textContent = this.speakerName(L.who); $('dtxt').textContent = L.text;
        Sound.beep(520 + (L.who || '').length * 20, 0.03, 'sine', 0.03);
      };
      this._dlgAdvance = () => { if (this._dlgChoices) return; i++; show(); };
      this._dlgDone = () => { i = q.length; done(); };
      show();
    });
  },
  closeDialog() { if (this._dlgDone && !$('dialog').classList.contains('hidden')) this._dlgDone(); },
  speakerName(w) { if (w === 'Kaan') return CAST.Hero_Main.name; if (w === 'Ela') return CAST.Ally_Partner.name; return w || ''; },
  applyChoice(c) {
    if (c.bond) changeBond(c.bond); if (c.moral) changeMorality(c.moral); if (c.rep) changeRep(c.rep); if (c.money) changeMoney(c.money);
    if (c.flag) { S.flags[c.flag] = true; if (c.flag === 'vengeful' || c.flag === 'protective') S.moralPath = c.flag; }
  },
  // ---------------------------------------------------------- Telefon
  phoneTab: 'map',
  phone(tab) {
    if (tab) this.phoneTab = tab;
    const el = this.showPanel('phone', `<div class="status"><span>${Sky.label()}</span><span>NeoTel 5G ▂▄▆█ · ${Math.floor(Player.energy)}%</span></div><div class="scr" id="phscr"></div><div class="tabs" id="phtabs"></div>`);
    const tabs = [['map', '🗺 Harita'], ['missions', '📋 Görev'], ['msgs', '💬 Mesaj'], ['home', '🏠 Ev/Araç'], ['ally', '💞 Ela'], ['set', '⚙']];
    $('phtabs').innerHTML = tabs.map(([k, l]) => this.btn(l, () => { this.phoneTab = k; this.renderPhone(); }, this.phoneTab === k ? 'on' : '')).join('');
    this.renderPhone();
  },
  renderPhone() {
    const scr = $('phscr'); if (!scr) return;
    document.querySelectorAll('#phtabs button').forEach((b, i) => b.classList.toggle('on', ['map', 'missions', 'msgs', 'home', 'ally', 'set'][i] === this.phoneTab));
    const t = this.phoneTab;
    if (t === 'map') {
      scr.innerHTML = `<canvas id="phonemap" width="600" height="600"></canvas><div class="row"><small style="color:var(--dim)">Haritaya dokun: yol noktası koy</small>${this.btn('Yol noktasını sil', () => { S.waypoint = null; this.renderPhone(); })}</div><div id="phleg" style="font-size:12px;color:var(--dim)">🟡 Ana görev · 🔵 Yan görev · 🩷 Aktivite · 🟢 Güvenli ev · 🟣 Yol noktası</div>`;
      const cv = $('phonemap'), g = cv.getContext('2d'), sc = 600 / 1300, ox = 680, oz = 650;
      const X = (x) => (x + ox) * sc, Z = (z) => (z + oz) * sc;
      g.fillStyle = '#0b2a4a'; g.fillRect(0, 0, 600, 600);
      g.fillStyle = '#2a2240'; for (const r of World.land) g.fillRect(X(r.x0), Z(r.z0), (r.x1 - r.x0) * sc, (r.z1 - r.z0) * sc);
      g.fillStyle = '#2f5a3a'; const m = World.mtn; g.fillRect(X(m.x0), Z(m.z0), (m.x1 - m.x0) * sc, (m.z1 - m.z0) * sc);
      g.strokeStyle = '#6a5a9a'; g.lineWidth = 2; g.beginPath(); for (const [a, b] of World.roadEdges) { const A = World.roadNodes[a], B = World.roadNodes[b]; g.moveTo(X(A.x), Z(A.z)); g.lineTo(X(B.x), Z(B.z)); } g.stroke();
      g.font = 'bold 13px Segoe UI'; g.fillStyle = '#c9b8ff';
      for (const [n, x, z] of [['LİMAN', -380, 380], ['ESKİ ÇARŞI', -380, 0], ['DAĞ MANASTIRI', -380, -360], ['NEON BULVAR', 0, -40], ['TEKNOLOJİ', 270, -160], ['DOĞU KONUTLARI', 270, 300], ['ADA', 540, 280]]) g.fillText(n, X(x) - 30, Z(z));
      for (const mk of Missions.markers) { g.fillStyle = mk.color; g.beginPath(); g.arc(X(mk.x), Z(mk.z), 6, 0, 7); g.fill(); }
      for (const s of S.safehouses) { g.fillStyle = '#b6ff3b'; g.fillRect(X(LOC[s][0]) - 5, Z(LOC[s][1]) - 5, 10, 10); }
      if (S.waypoint) { g.fillStyle = '#ff2fd6'; g.beginPath(); g.arc(X(S.waypoint[0]), Z(S.waypoint[1]), 7, 0, 7); g.fill(); }
      const p = Game.player.pos; g.fillStyle = '#fff'; g.beginPath(); g.arc(X(p.x), Z(p.z), 7, 0, 7); g.fill(); g.strokeStyle = '#000'; g.stroke();
      cv.onclick = (e) => { const r = cv.getBoundingClientRect(); const x = (e.clientX - r.left) / r.width * 600 / sc - ox, z = (e.clientY - r.top) / r.height * 600 / sc - oz; S.waypoint = [x, z]; this.renderPhone(); };
    } else if (t === 'missions') {
      const act = Missions.active;
      let h = act ? `<div class="card sel"><b>▶ ${act.num ? act.num + ' ' : ''}${act.title}</b>${$('objective').textContent}<div class="row">${this.btn('Görevi bırak', () => { Missions.fail('Görev bırakıldı'); this.renderPhone(); }, 'warn')}</div></div>` : '<div class="card">Aktif görev yok. Haritadaki işaretlere git.</div>';
      h += '<h2 style="font-size:15px;margin-top:12px">Mevcut</h2>' + Missions.available().map(m => `<div class="card"><b>${m.num ? m.num + ' · ' : ''}${m.title}</b><small>${m.kind === 'side' ? 'Yan görev' : m.kind === 'activity' ? 'Aktivite' : 'Perde ' + m.act}${m.night ? ' · 🌙 gece' : ''}${m.needAlly ? ' · 💞 Ela gerekli' : ''}</small><div class="row">${this.btn('📍 İşaretle', () => { S.waypoint = locXZ(m.at); this.toast('Yol noktası: ' + m.title); })}</div></div>`).join('');
      const done = MISSIONS.filter(m => S.completed[m.id]).length;
      h += `<h2 style="font-size:15px;margin-top:12px">İlerleme</h2><div class="card">Ana görevler: ${done}/${MISSIONS.length}<br>Yan görevler: ${SIDES.filter(m => S.completed[m.id]).length}/${SIDES.length}<br>Easter Egg: ${Object.keys(S.eggs).length}/${EGGS.length}<br>Ahlak: ${S.morality > 0 ? '+' : ''}${S.morality} ${S.moralPath ? '(' + (S.moralPath === 'vengeful' ? 'sert yol' : 'koruyucu yol') + ')' : ''}</div>`;
      h += '<div class="card"><b>Easter Egg ipuçları</b>' + EGGS.map(e => `${S.eggs[e.id] ? '✅' : '❔'} ${S.eggs[e.id] ? e.title : e.hint}`).join('<br>') + '</div>';
      scr.innerHTML = h;
    } else if (t === 'msgs') {
      scr.innerHTML = S.messages.map(m => `<div class="msg"><div class="f">${m.from}</div>${m.text}</div>`).join('') || '<div class="card">Mesaj yok.</div>';
    } else if (t === 'home') {
      let h = '<h2 style="font-size:15px">Güvenli Evler</h2>' + (S.safehouses.length ? S.safehouses.map(s => `<div class="card"><b>🏠 ${districtAt(...LOC[s]).name}</b><div class="row">${this.btn('📍 Yol noktası', () => { S.waypoint = LOC[s]; this.toast('Yol noktası ayarlandı'); })}</div></div>`).join('') : '<div class="card">Henüz güvenli ev yok (Görev 1.5).</div>');
      h += `<div class="card">Depo: ${S.storage.map(w => WEAPONS[w]?.icon + ' ' + WEAPONS[w]?.name).join(', ') || 'boş'}</div>`;
      h += '<h2 style="font-size:15px">Araçlarım</h2>' + (S.vehicles.length ? S.vehicles.map(v => `<div class="card"><b style="color:${v.color}">■ ${VEHICLES[v.type].name}</b><small>Hız ${v.mods.speed} · Zırh ${v.mods.armor} · Yol tutuş ${v.mods.grip}</small><div class="row">${this.btn('🚚 Yanıma getir (50₺)', () => { if (S.money < 50) return this.toast('Para yetersiz'); changeMoney(-50); this.closePanel(); setTimeout(() => { Vehicles.deliver(v); this.toast('Aracın teslim edildi'); }, 1500); })}</div></div>`).join('') : '<div class="card">Henüz aracın yok (Görev 1.3).</div>');
      scr.innerHTML = h;
    } else if (t === 'ally') {
      if (!S.allyUnlocked) { scr.innerHTML = '<div class="card">📵 Bu kişi henüz rehberinde değil. (Görev 2.2)</div>'; return; }
      scr.innerHTML = `<div class="card"><b>💞 ${CAST.Ally_Partner.name}</b>Bağ seviyesi: ${Math.floor(S.bondLevel)}/100<div class="barw" style="margin-top:6px"><div style="width:${S.bondLevel}%;background:linear-gradient(90deg,#ff7ad9,#ffb020);height:100%"></div></div><small>${S.bondLevel >= 70 ? 'Ayrılmaz ikili' : S.bondLevel >= 45 ? 'Güvenilir ortak' : S.bondLevel >= 20 ? 'Yakınlaşıyorsunuz' : 'Yeni tanışma'}</small></div>
        <div class="row">${this.btn(S.allyWith ? '📞 Ara (yanında)' : '📞 Ara / Çağır', () => { this.closePanel(); Ally.call(); })}${this.btn('👋 Ayrıl', () => { Ally.leave(); this.toast('Ela kendi işine döndü'); this.renderPhone(); }, 'alt')}</div>
        <h2 style="font-size:15px;margin-top:10px">Buluşma ayarla</h2>` + ACTIVITIES.filter(a => a.needAlly).map(a => `<div class="card"><b>${a.title}</b><small>${a.hours ? 'Saat ' + a.hours[0] + ':00 sonrası' : 'Her saat'}${S.flags['cd_' + a.id] === S.day ? ' · bugün yapıldı' : ''}</small><div class="row">${this.btn('📍 Buluşma noktası', () => { S.waypoint = locXZ(a.at); addMessage('Ela', 'Tamam, ' + a.title.toLowerCase() + ' için orada buluşalım.'); this.closePanel(); })}</div></div>`).join('');
    } else if (t === 'set') {
      scr.innerHTML = `<div class="row">${this.btn('💾 Kaydet', () => { saveGame() && this.toast('Kaydedildi'); })}${this.btn('⚙ Ayarlar', () => this.settings())}${this.btn('🛠 Admin', () => this.admin())}</div>`;
    }
  },
  // ---------------------------------------------------------- Gardırop & maske
  wardrobe() {
    if (Game.combat) { this.toast('Çatışmada kıyafet değiştirilemez'); return; }
    if (Game.player.vehicle) return;
    const card = (id, title, desc) => `<div class="card ${S.outfit === id ? 'sel' : ''}" id="wd_${id}"><b>${title}</b>${desc}</div>`;
    this.showPanel('wardrobe', `<h2>👕 Gardırop</h2>${this.btn('✕', () => this.closePanel(), 'close')}
      <div class="grid">${card('civil', 'Sivil Kıyafet', 'Gri tamirci ceketi, siyah tişört, kot. Kalabalığa karışırsın.')}${card('ninja', 'Ninja Kostümü', 'Kömür grisi zırh, çelik plakalar, turuncu dişli amblem. Maske + kostüm kimliğini gizler.')}</div>
      <div class="row" style="margin-top:12px">${this.btn(S.mask ? '😷 Maskeyi Çıkar' : '😷 Maskeyi Tak', () => { Player.toggleMask(); this.wardrobe(); })}<small style="color:var(--dim)">Hızlı tuş: ${Input.hint('mask')}</small></div>`);
    for (const id of ['civil', 'ninja']) $('wd_' + id).onclick = () => { if (S.outfit !== id) { Player.setOutfit(id); Ally.outfitSync(); FX.burst(_v1.copy(Game.player.pos).setY(Game.player.pos.y + 1), '#ffffff', 20, 5); this.toast(id === 'ninja' ? '🥷 Ninja kostümü giyildi' : '👕 Sivil kıyafet'); } this.wardrobe(); };
  },
  // ---------------------------------------------------------- Silah tekerleği
  wheelOpen: false,
  openWheel() {
    if (Game.player.vehicle) return;
    this.wheelOpen = true; this.wheelSel = S.equipped; const el = $('wheel'); el.classList.remove('hidden');
    const n = S.carried.length;
    el.innerHTML = S.carried.map((w, i) => { const a = -Math.PI / 2 + i / n * Math.PI * 2, x = 170 + Math.cos(a) * 118, y = 170 + Math.sin(a) * 118; const W = WEAPONS[w]; return `<div class="slot ${i === this.wheelSel ? 'sel' : ''}" data-i="${i}" style="left:${x}px;top:${y}px"><div class="ic">${W.icon}</div>${W.name}</div>`; }).join('') + `<div class="mid">Taşıma: ${n - 1}/${MAX_CARRY}<br>Fazlası güvenli ev deposunda</div>`;
    el.querySelectorAll('.slot').forEach(s => { s.onclick = s.ontouchstart = (e) => { e.preventDefault(); this.wheelSel = +s.dataset.i; this.closeWheel(true); }; s.onmouseenter = () => { this.wheelSel = +s.dataset.i; this.wheelMark(); }; });
    this._wheelAcc = { x: 0, y: 0 };
  },
  wheelMark() { $('wheel').querySelectorAll('.slot').forEach((s, i) => s.classList.toggle('sel', i === this.wheelSel)); },
  wheelUpdate() {
    const n = S.carried.length; const a = this._wheelAcc; a.x += Input.move.x * 0.2 + Input.look.x * 6; a.y += -Input.move.y * 0.2 + Input.look.y * 6;
    if (Math.hypot(a.x, a.y) > 0.6) { let ang = Math.atan2(a.y, a.x) + Math.PI / 2; if (ang < 0) ang += Math.PI * 2; this.wheelSel = Math.round(ang / (Math.PI * 2) * n) % n; this.wheelMark(); a.x *= 0.8; a.y *= 0.8; }
    if (Input.device === 'touch' && !Input.isDown('wheel') && this._wheelTouchT === undefined) this._wheelTouchT = Game.t;
  },
  closeWheel(apply) {
    if (!this.wheelOpen) return; this.wheelOpen = false; $('wheel').classList.add('hidden'); delete this._wheelTouchT;
    if (apply && S.equipped !== this.wheelSel) { S.equipped = this.wheelSel; const w = Player.weapon(); this.toast(w.icon + ' ' + w.name); }
  },
  // ---------------------------------------------------------- Dükkânlar
  weaponShop() {
    const rows = Object.entries(WEAPONS).filter(([k]) => k !== 'fists').map(([k, w]) => {
      const own = S.carried.includes(k) || S.storage.includes(k);
      return `<div class="card"><b>${w.icon} ${w.name}</b>${w.kind === 'ranged' ? 'Menzilli' : 'Yakın dövüş'} · Hasar ${w.dmg}<div class="row">${own ? '<small>Sahipsin</small>' : this.btn(w.price + ' ₺ Satın al', () => this.buyWeapon(k))}</div></div>`;
    }).join('');
    this.showPanel('shop', `<h2>🔧 Demirci Silah & Ekipman</h2>${this.btn('✕', () => this.closePanel(), 'close')}<p style="color:var(--dim);font-size:13px">Üzerinde en fazla ${MAX_CARRY} silah taşıyabilirsin. Fazlası güvenli eve gönderilir; dükkân da emanet tutar.</p><div class="grid">${rows}</div>
      <h2 style="font-size:15px;margin-top:12px">Emanet</h2><div class="row">${S.carried.slice(1).map((w, i) => this.btn('⬇ ' + WEAPONS[w].icon + ' ' + WEAPONS[w].name + ' bırak', () => { this.moveToStorage(i + 1); this.weaponShop(); })).join('')}${S.storage.map((w, i) => this.btn('⬆ ' + WEAPONS[w].icon + ' ' + WEAPONS[w].name + ' al', () => { this.takeFromStorage(i); this.weaponShop(); }, 'alt')).join('')}</div>`);
  },
  buyWeapon(k) {
    const w = WEAPONS[k]; if (S.money < w.price) return this.toast('Para yetersiz');
    changeMoney(-w.price); Sound.ok();
    if (S.carried.length - 1 < MAX_CARRY) { S.carried.push(k); this.toast('Satın alındı: ' + w.name); }
    else { S.storage.push(k); this.toast('Taşıma yuvası dolu → depoya gönderildi: ' + w.name); }
    Bus.emit('weaponBought', k); this.weaponShop();
  },
  moveToStorage(i) { const w = S.carried.splice(i, 1)[0]; if (w) S.storage.push(w); S.equipped = Math.min(S.equipped, S.carried.length - 1); Bus.emit('storage', w); },
  takeFromStorage(i) { if (S.carried.length - 1 >= MAX_CARRY) return this.toast('Taşıma yuvası dolu'); const w = S.storage.splice(i, 1)[0]; if (w) S.carried.push(w); },
  safehouseMenu(id) {
    this.showPanel('shop', `<h2>🏠 Güvenli Ev — ${districtAt(...LOC[id]).name}</h2>${this.btn('✕', () => this.closePanel(), 'close')}
      <div class="row">${this.btn('👕 Gardırop', () => this.wardrobe())}${this.btn('💾 Kaydet', () => { saveGame(); this.toast('Kaydedildi'); })}${this.btn('😴 Uyu (8 saat)', () => this.sleep())}${S.vehicles.length ? this.btn('🚗 Araç çağır', () => { this.closePanel(); Vehicles.deliver(S.vehicles[0], [LOC[id][0] + 8, LOC[id][1] + 4]); }) : ''}</div>
      <h2 style="font-size:15px;margin-top:12px">🗄 Silah Deposu</h2><p style="color:var(--dim);font-size:13px">Üzerinde: ${S.carried.length - 1}/${MAX_CARRY}</p>
      <div class="grid">${S.carried.slice(1).map((w, i) => `<div class="card"><b>${WEAPONS[w].icon} ${WEAPONS[w].name}</b>Üzerinde${'<div class="row">' + this.btn('Depoya koy ⬇', () => { this.moveToStorage(i + 1); this.safehouseMenu(id); }) + '</div>'}</div>`).join('')}
      ${S.storage.map((w, i) => `<div class="card"><b>${WEAPONS[w].icon} ${WEAPONS[w].name}</b>Depoda<div class="row">${this.btn('Al ⬆', () => { this.takeFromStorage(i); this.safehouseMenu(id); }, 'alt')}</div></div>`).join('')}</div>`);
  },
  async sleep() {
    this.closePanel(); await this.fade(1); S.time = (S.time + 8) % 24; if (S.time < 8) S.day++; Game.player.hp = Game.player.maxHp; Player.energy = 100; S.wanted = 0; Crime.clear(); saveGame(); await this.fade(0); this.toast('😴 Dinlendin. Saat ' + Sky.label());
  },
  modShop() {
    const p = Game.player.pos;
    const near = Game.vehicles.filter(v => !v.removed && !v.wreck && dist2(v.pos.x, v.pos.z, p.x, p.z) < 25 * 25).sort((a, b) => dist2(a.pos.x, a.pos.z, p.x, p.z) - dist2(b.pos.x, b.pos.z, p.x, p.z))[0];
    if (!near) { this.showPanel('shop', `<h2>🔧 Hurda Garaj</h2>${this.btn('✕', () => this.closePanel(), 'close')}<p>Modifiye için garajın önüne bir araç getir.</p>${S.vehicles.length ? '<div class="row">' + S.vehicles.map(v => this.btn('🚚 ' + VEHICLES[v.type].name + ' getir', () => { this.closePanel(); Vehicles.deliver(v, [LOC.garage[0], LOC.garage[1] - 6]); })).join('') + '</div>' : ''}`); return; }
    const rec = S.vehicles.find(x => x.uid === near.uid);
    const tier = (k) => near.mods[k];
    const up = (k, label) => { const t = tier(k), cost = MOD_OPTIONS[k][t + 1]; return `<div class="card"><b>${label}</b>Seviye ${t}/3${cost !== undefined ? '<div class="row">' + this.btn(cost + ' ₺ yükselt', () => { if (S.money < cost) return this.toast('Para yetersiz'); changeMoney(-cost); near.mods[k]++; if (k === 'armor') { near.maxHp = near.def.hp * (1 + near.mods.armor * 0.4); near.hp = near.maxHp; } if (rec) rec.mods = near.mods; Sound.ok(); this.modShop(); }) + '</div>' : '<div class="row"><small>MAKS</small></div>'}</div>`; };
    this.showPanel('shop', `<h2>🔧 Hurda Garaj — ${near.def.name}</h2>${this.btn('✕', () => this.closePanel(), 'close')}
      ${rec ? '' : `<div class="card">Bu araç senin değil. ${this.btn('Garaja kaydet (250 ₺)', () => { if (S.money < 250) return this.toast('Para yetersiz'); changeMoney(-250); Vehicles.own(near); this.modShop(); })}</div>`}
      <h2 style="font-size:15px">🎨 Renk (50 ₺)</h2><div class="row">${MOD_OPTIONS.colors.map(c => this.btn(`<span style="color:${c}">■■</span>`, () => { if (S.money < 50) return this.toast('Para yetersiz'); changeMoney(-50); near.repaint(c); if (rec) rec.color = c; this.modShop(); })).join('')}</div>
      <div class="grid" style="margin-top:10px">${up('speed', '⚡ Hız / Motor')}${up('armor', '🛡 Zırh')}${up('grip', '🛞 Yol tutuş')}</div>
      <div class="row" style="margin-top:8px">${this.btn('🔧 Tamir (40 ₺)', () => { if (S.money < 40) return; changeMoney(-40); near.hp = near.maxHp; this.toast('Tamir edildi'); })}</div>`);
  },
  garageMenu() { this.modShop(); },
  smoothieMenu() {
    const act = ACTIVITIES.find(a => a.id === 'a_smoothie');
    this.showPanel('shop', `<h2>🍍 Neon Smoothie</h2>${this.btn('✕', () => this.closePanel(), 'close')}<p style="color:var(--dim)">Mango-ejder meyvesi, Neon Böğürtlen, Çift Şekerli Kasırga…</p>
      <div class="row">${this.btn('🥤 Smoothie al (15 ₺) — enerji yenile', () => { if (S.money < 15) return this.toast('Para yetersiz'); changeMoney(-15); Player.energy = 100; Game.player.hp = Math.min(Game.player.maxHp, Game.player.hp + 30); this.toast('Enerji doldu!'); this.closePanel(); })}
      ${S.allyUnlocked ? this.btn('💞 Ela ile otur', () => { this.closePanel(); Missions.startActivity(act); }, 'alt') : ''}</div>`);
  },
  elevatorMenu() {
    const go = async (y, z) => { this.closePanel(); await this.fade(1); const p = Game.player; p.pos.set(280, y + 0.2, z); p.vel.set(0, 0, 0); if (S.allyWith && Game.ally) Game.ally.pos.set(282, y + 0.2, z); Cam.snap(); await this.fade(0); };
    this.showPanel('shop', `<h2>🛗 Neo Teknoloji Asansörü</h2>${this.btn('✕', () => this.closePanel(), 'close')}<div class="row">${this.btn('Zemin', () => go(0, -250))}${this.btn('Teras 90', () => go(90, -246))}${this.btn('Teras 140', () => go(140, -246))}${this.btn('Çatı 172', () => go(172, -270))}</div>`);
  },
  npcTalk(castId) {
    const at = { Mentor_Master: 'teahouse', NPC_NoodleChef: 'noodle', NPC_DojoGuy: 'dojo' }[castId];
    if (Missions.tryStartAt(at)) return;
    if (castId === 'Mentor_Master' && S.flags.teacupHeld && !S.eggs.e_teacup) { S.flags.teacupHeld = false; UI.dialog(DIALOGUES.e_teacup).then(() => { Eggs.found('e_teacup'); changeMoney(150); }); return; }
    const lines = { Mentor_Master: ['Çay demlenirken sabret, Kaan. Kavga da öyle.', 'Gücün arttıkça yükün de artar.', 'Kızıl kuleye dikkat et. Orada yapılan şey doğaya karşı.'], NPC_NoodleChef: ['Erişte uzun, hayat kısa! Ye!', 'Sıcak teslimat lazım olursa motorun hazır olsun.'], NPC_DojoGuy: ['Turbo Tarık asla yenilmez! …Bugün yenilmedi en azından.', 'İmza ister misin? Ücretsiz. Bugünlük.'] }[castId] || ['…'];
    UI.dialog([{ who: CAST[castId].name, text: pick(lines) }]);
  },
  // ---------------------------------------------------------- Duraklat / ayarlar
  pause() {
    this.showPanel('pause', `<h2>⏸ Duraklatıldı</h2><div class="row" style="flex-direction:column;align-items:stretch">${this.btn('▶ Devam', () => this.closePanel())}${this.btn('💾 Kaydet', () => { saveGame(); this.toast('Kaydedildi'); })}${this.btn('📱 Telefon', () => this.phone())}${this.btn('⚙ Ayarlar', () => this.settings())}${this.btn('🛠 Admin Paneli', () => this.admin())}${this.btn('🏠 Ana Menü', () => { saveGame(); location.reload(); }, 'warn')}</div>
      <p style="font-size:12px;color:var(--dim)">${Input.device === 'kbm' ? 'Klavye/Fare' : Input.device === 'pad' ? 'Gamepad' : 'Dokunmatik'} algılandı.</p>`);
    Game.paused = true; const el = $('pause'); const obs = new MutationObserver(() => { if (el.classList.contains('hidden')) { Game.paused = false; obs.disconnect(); } }); obs.observe(el, { attributes: true });
  },
  settings() {
    const s = Settings;
    this.showPanel('settings', `<h2>⚙ Ayarlar</h2>${this.btn('✕', () => this.closePanel(), 'close')}
      <div class="row">Kalite <select id="st_q"><option value="low">Düşük (mobil)</option><option value="medium">Orta</option><option value="high">Yüksek</option></select> <small>(yeniden başlatır)</small></div>
      <div class="row">Görüş mesafesi <input type="range" id="st_vd" min="160" max="600" step="20" value="${s.viewDist}"> <span id="st_vdv">${s.viewDist}</span></div>
      <div class="row"><label><input type="checkbox" id="st_sh" ${s.shadows ? 'checked' : ''}> Gölgeler</label> <label><input type="checkbox" id="st_inv" ${s.invertY ? 'checked' : ''}> Y eksenini ters çevir</label> <label><input type="checkbox" id="st_fps" ${s.showFps ? 'checked' : ''}> FPS</label> <label><input type="checkbox" id="st_tf" ${s.touchForce ? 'checked' : ''}> Dokunmatik kontrolleri zorla</label></div>
      <div class="row">Hassasiyet <input type="range" id="st_se" min="0.3" max="2.5" step="0.1" value="${s.sens}"></div>
      <div class="row">Zaman hızı (oyun sn / gerçek sn) <input type="range" id="st_ts" min="10" max="240" step="10" value="${s.timeScale}"> <span id="st_tsv">${s.timeScale}</span></div>
      <div class="row">Ses <input type="range" id="st_vo" min="0" max="1" step="0.05" value="${s.volume}"></div>
      <div class="row">${this.btn('Kaydet', () => { const q = $('st_q').value, reload = q !== s.quality || $('st_sh').checked !== s.shadows; s.quality = q; s.viewDist = +$('st_vd').value; s.shadows = $('st_sh').checked; s.invertY = $('st_inv').checked; s.showFps = $('st_fps').checked; s.touchForce = $('st_tf').checked; s.sens = +$('st_se').value; s.timeScale = +$('st_ts').value; s.volume = +$('st_vo').value; saveSettings(); if (reload) { saveGame(); location.reload(); } else { Game.camera.far = s.viewDist + 200; Game.camera.updateProjectionMatrix(); Render.sky.scale.setScalar(s.viewDist + 100); this.closePanel(); } })}</div>`);
    $('st_q').value = s.quality; $('st_vd').oninput = (e) => $('st_vdv').textContent = e.target.value; $('st_ts').oninput = (e) => $('st_tsv').textContent = e.target.value;
  },
  // ---------------------------------------------------------- ADMIN PANELİ
  async admin() {
    const slots = AssetManager.slots();
    const recs = await AssetCache.all().catch(() => []) || [];
    const recMap = Object.fromEntries((recs || []).map(r => [r.id, r]));
    const row = (s) => {
      const m = AssetManager.manifest[s.id], r = recMap[s.id], st = AssetManager.status[s.id];
      const status = !m ? '<span class="no">prosedürel</span>' : st === 'cache' ? '<span class="ok">IndexedDB ✓</span>' : st === 'download' ? '<span class="ok">indirildi ✓</span>' : st === 'error' ? '<span class="no">hata</span>' : '<span class="no">bekliyor</span>';
      return `<tr><td><b>${s.label}</b><br><small>${s.id}</small></td><td>${s.kind === 'model' ? '🧊 model' : '🖼 doku'}</td><td>${status}<br><small>${m ? 'v' + m.version + ' · ' + (m.updatedAt || '').slice(0, 19).replace('T', ' ') + ' · ' + m.source : ''}${r ? ' · ' + (r.size / 1024).toFixed(0) + ' KB' : ''}</small></td>
        <td>${this.btn('📂 Yükle', () => this.pickFile(s.id))} ${m ? this.btn('🔄 Tek Varlığı Yenile', async () => { await AssetManager.refreshOne(s.id); Main.rebuildFigures(); this.admin(); }, 'alt') : ''} ${m ? this.btn('🗑', () => { AssetManager.removeSlot(s.id); Main.rebuildFigures(); this.admin(); }, 'warn') : ''}</td></tr>`;
    };
    const castNames = Object.keys(CAST).filter(k => CAST[k].name).map(k => `<div class="row"><small style="width:150px">${k}</small><input data-cast="${k}" value="${CAST[k].name}" style="flex:1"></div>`).join('');
    this.showPanel('admin', `<h2>🛠 Admin Paneli — Varlıklar, Önbellek, Supabase, Veri</h2>${this.btn('✕', () => this.closePanel(), 'close')}
      <div class="card"><b>☁ Supabase</b><div class="row"><input id="sb_url" placeholder="https://xxxx.supabase.co" value="${Supa.cfg.url}" style="flex:2"><input id="sb_key" placeholder="anon key" value="${Supa.cfg.key}" style="flex:2"><input id="sb_bucket" value="${Supa.cfg.bucket}" style="width:110px"><input id="sb_table" value="${Supa.cfg.table}" style="width:110px"></div>
        <div class="row">${this.btn('Kaydet', () => { Object.assign(Supa.cfg, { url: $('sb_url').value.trim(), key: $('sb_key').value.trim(), bucket: $('sb_bucket').value.trim() || 'ng-assets', table: $('sb_table').value.trim() || 'ng_assets' }); Supa.save(); this.toast('Supabase ayarı kaydedildi'); })}${this.btn('Bağlantıyı test et', async () => { try { const r = await Supa.list(); this.toast('✓ Bağlandı: ' + r.length + ' kayıt'); } catch (e) { this.toast('✗ ' + e.message); } }, 'alt')}${this.btn('⬇ Supabase\'ten eşitle', async () => { const n = await AssetManager.syncRemote(); await AssetManager.loadAll(); Main.rebuildFigures(); this.toast(n + ' varlık güncellendi'); this.admin(); }, 'alt')}</div></div>
      <div class="row" style="margin:10px 0">${this.btn('♻ Önbelleği Temizle ve Yeniden Tara', async () => { await AssetManager.clearAndRescan(); Main.rebuildFigures(); this.toast('Önbellek temizlendi, varlıklar yeniden tarandı'); this.admin(); }, 'warn')}<small>IndexedDB: ${recs.length} kayıt · ${((recs || []).reduce((a, r) => a + (r.size || 0), 0) / 1048576).toFixed(2)} MB</small></div>
      <p style="font-size:12px;color:var(--dim)">Çok parçalı modellerde node isimleri <b>head, torso, arm_L, arm_R, leg_L, leg_R</b> olmalı — otomatik rig bu isimlerle pivot kurar ve animasyonları bağlar. Kostüm varyantı için slot adına <b>_civil</b> / <b>_ninja</b> ekli bir varlık da yükleyebilirsin (ör. Hero_Main_ninja). Araç modelleri <b>veh_*</b> slotlarına.</p>
      <div class="row"><input id="ad_extra" placeholder="Özel slot (ör. Hero_Main_ninja)" style="flex:1">${this.btn('📂 Bu slota yükle', () => { const v = $('ad_extra').value.trim(); if (v) this.pickFile(v); })}<input id="ad_url" placeholder="veya doğrudan URL (.glb/.obj/.png)" style="flex:2">${this.btn('🔗 URL ata', async () => { const slot = $('ad_extra').value.trim(), url = $('ad_url').value.trim(); if (!slot || !url) return this.toast('Slot ve URL gir'); const prev = AssetManager.manifest[slot]; AssetManager.manifest[slot] = { id: slot, slot, kind: /\.(png|jpe?g|webp)$/i.test(url) ? 'texture' : 'model', fmt: /\.obj$/i.test(url) ? 'obj' : 'glb', url, version: (prev?.version || 0) + 1, updatedAt: new Date().toISOString(), source: 'url' }; AssetManager.saveManifest(); try { await AssetManager.loadOne(slot, true); Main.rebuildFigures(); this.toast('Yüklendi'); } catch (e) { this.toast('Hata: ' + e.message); } this.admin(); }, 'alt')}</div>
      <table><tr><th>Varlık</th><th>Tür</th><th>Durum</th><th>İşlem</th></tr>${slots.map(row).join('')}${Object.keys(AssetManager.manifest).filter(k => !slots.find(s => s.id === k)).map(k => row({ id: k, label: k, kind: AssetManager.manifest[k].kind })).join('')}</table>
      <div class="card" style="margin-top:10px"><b>🏷 Görüntü isimleri (karakter kod adı → isim)</b>${castNames}<div class="row">${this.btn('İsimleri kaydet', () => { const o = JSON.parse(localStorage.getItem(DATA_OVERRIDE_KEY) || '{}'); o.CAST ||= {}; document.querySelectorAll('[data-cast]').forEach(i => { CAST[i.dataset.cast].name = i.value; o.CAST[i.dataset.cast] = Object.assign(o.CAST[i.dataset.cast] || {}, { name: i.value }); }); localStorage.setItem(DATA_OVERRIDE_KEY, JSON.stringify(o)); this.toast('İsimler kaydedildi'); })}</div></div>
      <div class="card" style="margin-top:10px"><b>📦 Veri JSON (görevler, diyaloglar, sinematikler, karakterler)</b><div class="row">${this.btn('⬇ Dışa aktar', () => this.exportData())}${this.btn('⬆ İçe aktar (.json)', () => this.pickFile('__data__'))}${this.btn('↺ Varsayılan veriye dön', () => { localStorage.removeItem(DATA_OVERRIDE_KEY); location.reload(); }, 'warn')}</div></div>
      <div class="card" style="margin-top:10px"><b>🧪 Test & hata ayıklama</b><div class="row"><select id="ad_tp">${Object.keys(LOC).map(k => `<option>${k}</option>`).join('')}</select>${this.btn('Işınlan', () => { const [x, z] = LOC[$('ad_tp').value]; const p = Game.player; p.pos.set(x, World.surfaceAt(x, z), z); Cam.snap(); this.closePanel(); })}${this.btn('+1000 ₺', () => changeMoney(1000))}${this.btn('Tüm yetenekler', () => { Object.keys(S.abilities).forEach(k => S.abilities[k] = true); this.toast('Yetenekler açıldı'); })}${this.btn('Tanınmış Ninja aç/kapa', () => { S.isRecognizedNinja = !S.isRecognizedNinja; this.toast('isRecognizedNinja = ' + S.isRecognizedNinja); })}</div>
        <div class="row"><select id="ad_m">${[...MISSIONS, ...SIDES, ...ACTIVITIES].map(m => `<option value="${m.id}">${m.num || ''} ${m.title}</option>`).join('')}</select>${this.btn('Görevi başlat', () => { const id = $('ad_m').value; const m = Missions.byId(id); (m.req || []).forEach(r => S.completed[r] = true); this.closePanel(); Missions.start(m); })}${this.btn('Önceki görevleri tamamla', () => { const id = $('ad_m').value; const i = MISSIONS.findIndex(m => m.id === id); MISSIONS.slice(0, Math.max(0, i)).forEach(m => { S.completed[m.id] = true; Missions.applyStoryFlags(m.id); }); this.toast('İlerleme ayarlandı'); })}</div>
        <div class="row">Saat <input id="ad_h" type="number" min="0" max="23" value="${Math.floor(S.time)}" style="width:70px">${this.btn('Ayarla', () => { S.time = +$('ad_h').value; })}<select id="ad_w"><option>clear</option><option>cloudy</option><option>rain</option><option>storm</option></select>${this.btn('Hava', () => Sky.setWeather($('ad_w').value, true))}${this.btn('Havayı serbest bırak', () => { Sky.forced = null; })}${this.btn('Bağ +20', () => changeBond(20))}${this.btn('Kaydı sil', () => { localStorage.removeItem(SAVE_KEY); location.reload(); }, 'warn')}</div></div>`);
  },
  pickFile(slot) {
    const fp = $('filepick'); fp.value = '';
    fp.onchange = async () => {
      const f = fp.files[0]; if (!f) return;
      if (slot === '__data__') { try { const o = JSON.parse(await f.text()); localStorage.setItem(DATA_OVERRIDE_KEY, JSON.stringify(o)); this.toast('Veri içe aktarıldı — yeniden başlatılıyor'); setTimeout(() => { saveGame(); location.reload(); }, 900); } catch (e) { this.toast('JSON hatalı: ' + e.message); } return; }
      this.toast('Yükleniyor: ' + f.name);
      try { await AssetManager.addLocalFile(slot, f); Main.rebuildFigures(); this.toast('✓ ' + slot + ' güncellendi (IndexedDB önbelleğine alındı)'); } catch (e) { console.error(e); this.toast('Model yüklenemedi: ' + e.message); }
      if (this.modal === 'admin') this.admin();
    };
    fp.click();
  },
  exportData() {
    const data = { CAST, MISSIONS, SIDES, ACTIVITIES, EGGS, DIALOGUES, CUTSCENES, WEAPONS, VEHICLES, LOC, RADIO, _schema: 'neon-golgeler-data-v1' };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = 'neon-golgeler-data.json'; a.click();
  }
};

// ---------------------------------------------------------------- Etkileşim sistemi
const Interact = {
  cur: null,
  update() {
    const p = Game.player; if (!p || Game.mode !== 'play' || p.vehicle || p.dragon) { UI.prompt(p?.vehicle ? '' : ''); this.cur = null; return; }
    let best = null, bd = 1e9;
    const consider = (o, d) => { if (d < bd) { bd = d; best = o; } };
    for (const o of World.interact) { if (o.cond && !o.cond()) continue; const d = Math.sqrt(dist2(o.x, o.z, p.pos.x, p.pos.z)); if (d < o.r && Math.abs(p.pos.y - World.groundAt(o.x, o.z, p.pos.y + 1)) < 3) consider(o, d); }
    for (const m of Missions.markers) { const d = Math.sqrt(dist2(m.x, m.z, p.pos.x, p.pos.z)); if (d < 4.5 && Math.abs(p.pos.y - (m.y || 0)) < 4) consider({ label: (m.m.kind === 'activity' ? '💞 ' : m.m.kind === 'side' ? '◆ ' : '★ ') + (m.m.num ? m.m.num + ' ' : '') + m.m.title, action: () => Missions.start(m.m) }, d - 1); }
    for (const o of Missions.interacts) { const d = Math.sqrt(dist2(o.x, o.z, p.pos.x, p.pos.z)); if (d < (o.r || 3)) consider(o, d - 2); }
    for (const c of Population.civs) { if (!c.alive || c.ai.mode === 'flee') continue; const d = c.distTo(p); if (d < 2.2) consider({ label: 'Konuş', action: () => Population.civTalk(c) }, d + 1); }
    this.cur = best;
    const v = !best && Vehicles.nearest(p.pos, 4.2);
    UI.prompt(best ? `${Input.hint('interact')} ${best.label}` : v && !v.wreck ? `${Input.hint('vehicle')} ${v.def.name}'e bin` : '');
  },
  use() { if (this.cur) this.cur.action(); }
};

// ---------------------------------------------------------------- CutscenePlayer
const Cutscene = {
  playing: null, skipFlag: false,
  async play(id, opt = {}) {
    const C = CUTSCENES[id]; if (!C) return;
    this.skipFlag = false; this.playing = id;
    const prevMode = Game.mode; Game.mode = 'cutscene'; Game.inputLock++;
    $('cine').classList.add('on'); $('cskip').classList.remove('hidden'); $('touch').classList.add('hidden');
    if (document.pointerLockElement) document.exitPointerLock();
    const [ax, az] = locXZ(C.at); const ay = C.y !== undefined ? C.y : World.surfaceAt(ax, az);
    if (C.time !== undefined && !opt.keepTime) S.time = C.time;
    if (C.weather) Sky.setWeather(C.weather, true);
    // oyuncu kadrosu
    const cast = {}, temp = [];
    const savedPos = Game.player.pos.clone();
    for (const k in C.cast || {}) {
      const [dx, dz, face, anim] = C.cast[k];
      let a;
      if (k === 'kaan') a = Game.player;
      else if (k === 'ela') { a = Ally.spawn(_v1.set(ax + dx, ay, az + dz)); a.hidden = false; }
      else { const had = Friends.list[k]; a = Friends.spawn(k, [ax, az], dx, dz); if (!had) temp.push(k); }
      if (a.vehicle) Vehicles.exit(a, true);
      if (a.dragon) Dragon.dismount();
      a.pos.set(ax + dx, ay + 0.02, az + dz); a.yaw = (face || 0) * Math.PI / 180; a.vel.set(0, 0, 0); a.want.set(0, 0, 0);
      a.poseOverride = anim === 'ko' ? null : anim === 'idle' ? null : anim; if (anim === 'ko') { a.st.anim = 'ko'; a.alive = false; a.koT = 1; a._cineKO = true; }
      cast[k] = a;
    }
    if (C.title) { $('ctitle').textContent = C.title; $('ctitle').style.opacity = 1; setTimeout(() => $('ctitle').style.opacity = 0, 2500); }
    Cam.override = true;
    const cam = Game.camera, anchor = new THREE.Vector3(ax, ay, az);
    for (const step of C.steps) {
      if (this.skipFlag) break;
      const tgtA = step.on && cast[step.on];
      const T = tgtA ? new THREE.Vector3(tgtA.pos.x, tgtA.pos.y + 1.5, tgtA.pos.z) : anchor.clone().add(_v1.set(0, 2, 0));
      const yaw = tgtA ? tgtA.yaw : 0, f = new THREE.Vector3(Math.sin(yaw), 0, Math.cos(yaw)), rt = new THREE.Vector3(f.z, 0, -f.x);
      let p0, p1, l0 = T.clone(), l1 = T.clone();
      switch (step.shot) {
        case 'close': p0 = T.clone().addScaledVector(f, 2.4).addScaledVector(rt, 0.7).add(_v1.set(0, 0.2, 0)); p1 = p0.clone().addScaledVector(rt, -0.4); break;
        case 'over': p0 = T.clone().addScaledVector(f, -2.6).addScaledVector(rt, 1).add(_v1.set(0, 0.5, 0)); p1 = p0.clone().addScaledVector(f, 0.6); l0 = l1 = T.clone().addScaledVector(f, 6); break;
        case 'low': p0 = T.clone().addScaledVector(f, 4.5).add(_v1.set(0, -1.2, 0)).addScaledVector(rt, -1.5); p1 = p0.clone().addScaledVector(rt, 3); break;
        case 'top': p0 = T.clone().add(_v1.set(2, 13, 2)); p1 = T.clone().add(_v1.set(-1, 9, -1)); break;
        case 'sky': p0 = anchor.clone().add(_v1.set(38, 26, 38)); p1 = anchor.clone().add(_v1.set(-26, 34, 32)); l0 = anchor.clone().add(_v1.set(0, 6, 0)); l1 = l0.clone(); break;
        case 'orbit': p0 = null; break;
        default: p0 = T.clone().addScaledVector(f, 7).add(_v1.set(0, 2.2, 0)).addScaledVector(rt, 2); p1 = p0.clone().addScaledVector(rt, -4);
      }
      if (step.sub) $('csub').innerHTML = step.sub.text ? (step.sub.who ? `<b>${UI.speakerName(step.sub.who)}:</b> ` : '') + step.sub.text : '';
      const dur = (step.dur || 3) * 1000, t0 = performance.now();
      for (const k in step.anim || {}) if (cast[k]) cast[k].poseOverride = step.anim[k];
      await new Promise(res => {
        const tick = () => {
          if (this.skipFlag) return res();
          const k = clamp((performance.now() - t0) / dur, 0, 1), e = smooth(k);
          if (step.shot === 'orbit') { const a = yaw + 0.6 + e * 1.6; cam.position.set(T.x + Math.sin(a) * 5.5, T.y + 1.2, T.z + Math.cos(a) * 5.5); cam.lookAt(T); }
          else { cam.position.lerpVectors(p0, p1, e); cam.lookAt(_v2.lerpVectors(l0, l1, e)); }
          if (k >= 1) return res(); requestAnimationFrame(tick);
        };
        tick();
      });
    }
    $('csub').innerHTML = ''; $('cine').classList.remove('on'); $('cskip').classList.add('hidden'); $('ctitle').style.opacity = 0;
    for (const k in cast) { const a = cast[k]; a.poseOverride = null; if (a._cineKO) { a.alive = true; a._cineKO = false; } }
    for (const k of temp) if (!opt.keepCast) Friends.despawn(k);
    if (opt.restorePos) Game.player.pos.copy(savedPos);
    Cam.override = null; Cam.snap();
    Game.inputLock = Math.max(0, Game.inputLock - 1); Game.mode = prevMode === 'cutscene' ? 'play' : prevMode;
    if (Input.device === 'touch') $('touch').classList.remove('hidden');
    this.playing = null;
  },
  skip() { if (this.playing) this.skipFlag = true; }
};
