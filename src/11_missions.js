// ============================================================================
//  GÖREV MOTORU — veri güdümlü adımlar, işaretçiler, başarısızlık/yeniden deneme,
//  hikaye bayrakları, 3 final, yan görevler, aktiviteler, Easter Egg'ler
// ============================================================================
class MissionCancel extends Error { }
const Missions = {
  active: null, token: 0, waiters: [], markers: [], interacts: [], target: null, bossActor: null, ctxVehicles: [], dummies: [],
  beacons: [], markT: 0, stealth: null, ring: null,
  all() { return [...MISSIONS, ...SIDES, ...ACTIVITIES]; },
  byId(id) { return this.all().find(m => m.id === id); },
  tag() { return this.active ? 'm_' + this.active.id : 'm_none'; },
  available() {
    return this.all().filter(m => {
      if (this.active && this.active.id === m.id) return false;
      if ((m.req || []).some(r => !S.completed[r])) return false;
      if (m.kind === 'activity') return S.flags['cd_' + m.id] !== S.day && (!m.needAlly || S.allyUnlocked);
      if (S.completed[m.id] && !m.repeat) return false;
      if (m.repeat && S.flags['cd_' + m.id] === S.day) return false;
      return true;
    });
  },
  tryStartAt(at) { const m = this.available().find(x => x.at === at); if (m && !this.active) { this.start(m); return true; } return false; },
  // ---------------------------------------------------------- başlat
  async start(m) {
    if (this.active) { UI.toast('Önce aktif görevi bitir: ' + this.active.title); return; }
    if (Game.mode !== 'play') return;
    if (m.needAlly && !S.allyWith) { UI.dialog([{ who: 'Bilgi', text: 'Bu aktivite için Ela yanında olmalı. Telefondan ara ' + Input.hint('callally') + '.' }]); return; }
    if (m.cost && S.money < m.cost) { UI.toast('Para yetersiz (' + m.cost + ' ₺ gerekli)'); return; }
    const hrs = m.hours || (m.night ? [20, 4.5] : null);
    if (hrs && !Sky.hourIn(hrs[0], hrs[1])) {
      let ok = false;
      await UI.dialog([{ who: 'Bilgi', text: `"${m.title}" ${m.night ? 'gece' : hrs[0] + ':00 sonrası'} başlar.` }, { choice: [{ text: '⏳ Bekle (saati ilerlet)', flag: '_wait' }, { text: 'Vazgeç' }] }]);
      if (S.flags._wait) { delete S.flags._wait; ok = true; await UI.fade(1); S.time = m.night ? 21 : hrs[0] + 0.5; await UI.fade(0); }
      if (!ok) return;
    }
    if (m.cost) changeMoney(-m.cost);
    const tok = ++this.token; this.active = m; this.stepState = {};
    UI.toast((m.kind === 'side' ? '◆ YAN GÖREV: ' : m.kind === 'activity' ? '💞 AKTİVİTE: ' : `★ PERDE ${m.act} · ${m.num} `) + m.title, true);
    if (m.weather) Sky.setWeather(m.weather, true);
    try {
      if (m.intro) await Cutscene.play(m.intro, { keepCast: false });
      this.check(tok);
      await this.runSteps(m.steps, tok);
      this.check(tok);
      await this.complete(m);
    } catch (e) {
      if (!(e instanceof MissionCancel)) { console.error('Görev hatası', e); UI.toast('Görev hatası: ' + e.message); this.cleanup(); this.active = null; }
    }
  },
  startActivity(a) { if (a && this.available().includes(a)) this.start(a); else if (a) UI.toast('Bu aktivite şu an uygun değil (bugün yapıldı veya kilitli).'); },
  check(tok) { if (tok !== this.token) throw new MissionCancel(); },
  async runSteps(steps, tok) {
    for (const st of steps) {
      this.check(tok);
      const h = this.steps[st.t]; if (!h) { console.warn('Bilinmeyen adım', st.t); continue; }
      this.curStep = st;
      await h.call(this, st, tok);
      this.check(tok);
      this.target = null; this.setBeacon(null); UI.objective('');
    }
  },
  waitUntil(cond, tok, opt = {}) {
    return new Promise((resolve, reject) => this.waiters.push({ cond, resolve, reject, tok, time: opt.time, tick: opt.tick, failMsg: opt.failMsg || 'Süre doldu' }));
  },
  fail(reason) {
    if (!this.active) return;
    const m = this.active; this.token++;
    for (const w of this.waiters) w.reject(new MissionCancel()); this.waiters = [];
    UI.closeDialog(); Cutscene.skip(); UI.closeWheel(false);
    this.cleanup(); this.active = null;
    UI.toast('✖ GÖREV BAŞARISIZ — ' + reason, true); UI.objective('');
    if (m.weather) Sky.forced = null;
  },
  cleanup() {
    const tag = this.tag();
    Enemies.killTag(tag); Pickups.clearTag(tag);
    for (const d of this.dummies) d.remove(); this.dummies = [];
    for (const v of this.ctxVehicles) if (v.temp || v.missionRival) { if (Game.player.vehicle === v) Vehicles.exit(Game.player); for (const p of v.passengers.slice()) Vehicles.exit(p, true); v.remove(); }
    this.ctxVehicles = []; Vehicles.mission = [];
    this.bossActor = null; this.target = null; this.setBeacon(null); this.interacts = [];
    if (this.stealth) { for (const c of this.stealth.cams) Game.scene.remove(c.mesh); this.stealth = null; }
    if (this.ring) this.ring.visible = false;
    if (this.rings) { for (const r of this.rings) Game.scene.remove(r); this.rings = null; }
    for (const k in Friends.list) if (Friends.list[k].follow) Friends.list[k].follow = false;
    Game.player.poseOverride = null; if (Game.ally) Game.ally.poseOverride = null;
  },
  async complete(m) {
    const r = m.reward || {};
    if (m.outro) await Cutscene.play(m.outro);
    this.cleanup(); this.active = null;
    S.completed[m.id] = true;
    if (m.kind === 'activity' || m.repeat) S.flags['cd_' + m.id] = S.day;
    if (r.money) changeMoney(r.money); if (r.rep) changeRep(r.rep); if (r.bond) changeBond(r.bond, m.title);
    this.applyStoryFlags(m.id);
    const news = RADIO.news[m.id] || (m.id === 'm42' ? RADIO.news[S.moralPath === 'vengeful' ? 'm42v' : 'm42p'] : null);
    if (news) logEvent(m.id, news);
    if (m.weather || Sky.forced) Sky.forced = null;
    UI.toast(`✔ ${m.kind === 'activity' ? 'AKTİVİTE' : 'GÖREV'} TAMAMLANDI — ${m.title}${r.money ? ' · +' + r.money + ' ₺' : ''}${r.rep ? ' · ⭐+' + r.rep : ''}`, true);
    Sound.ok(); saveGame();
    const next = MISSIONS.find(x => !S.completed[x.id] && (x.req || []).every(q => S.completed[q]));
    if (next && m.kind !== 'activity' && MISSIONS.includes(m)) setTimeout(() => addMessage(next.act >= 2 && S.allyUnlocked ? 'Ela' : 'Hikmet Usta', `Sıradaki iş: "${next.title}". Haritada sarı işaret.`), 2500);
  },
  applyStoryFlags(id) {
    const ab = S.abilities;
    if (id === 'm12') ab.tornado = true;
    if (id === 'm13') { S.flags.modShop = true; if (!S.vehicles.some(v => v.type === 'motor')) S.vehicles.push({ uid: 'v_motor1', type: 'motor', color: VEHICLES.motor.color, mods: { speed: 0, armor: 0, grip: 0 } }); }
    if (id === 'm15' && !S.safehouses.includes('harborSafe')) S.safehouses.push('harborSafe');
    if (id === 'm22') S.allyUnlocked = true;
    if (id === 'm26') { S.isRecognizedNinja = true; }
    if (id === 'm32') ab.glide = true;
    if (id === 'm33') ab.dragon = true;
    if (id === 'm35') S.flags.betrayed = true;
    if (id === 'm44' && !S.safehouses.includes('eastSafe')) S.safehouses.push('eastSafe');
    if (id === 'm21' && !S.safehouses.includes('neonSafe')) { S.safehouses.push('neonSafe'); addMessage('Hikmet Usta', 'Neon Bulvar\'da eski bir dostun boş dairesi var. Artık senin güvenli evin.'); }
  },
  // ---------------------------------------------------------- yardımcılar
  pos(at, y) { const [x, z] = locXZ(at); return [x, y !== undefined ? y : World.surfaceAt(x, z), z]; },
  setTarget(at, label) { const [x, z] = locXZ(at); this.target = [x, z]; this.setBeacon([x, z], '#ffd23b'); },
  setBeacon(xz, color, y) {
    if (!this.tBeacon) { const g = new THREE.Group(); const c = new THREE.Mesh(new THREE.CylinderGeometry(1.4, 1.4, 120, 16, 1, true), new THREE.MeshBasicMaterial({ color: 0xffd23b, transparent: true, opacity: 0.28, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending, toneMapped: false })); c.position.y = 60; g.add(c); const r = new THREE.Mesh(Geo.ring, c.material); r.rotation.x = -Math.PI / 2; r.scale.setScalar(3); r.position.y = 0.2; g.add(r); g.visible = false; Game.scene.add(g); this.tBeacon = g; }
    const b = this.tBeacon; if (!xz) { b.visible = false; return; }
    b.visible = true; b.position.set(xz[0], y !== undefined ? y : World.groundAt(xz[0], xz[1], Game.player.pos.y + 3), xz[1]); b.children[0].material.color.set(color || '#ffd23b');
  },
  spawnWave(w, at, y, tok) {
    const [cx, cz] = locXZ(w.at || at);
    const list = [];
    for (let i = 0; i < (w.n || 1); i++) {
      const ang = rand(0, Math.PI * 2), r = rand(4, 10);
      let x = cx + Math.cos(ang) * r, z = cz + Math.sin(ang) * r;
      const yy = (w.y ?? y);
      list.push(Enemies.spawn(w.type, x, z, yy !== undefined ? World.groundAt(x, z, yy + 1) : undefined, { tag: this.tag() }));
    }
    return list;
  },
  playerNear(at, r, dy = 8) { const [x, z] = locXZ(at); const p = Game.player.pos; return dist2(x, z, p.x, p.z) < r * r; },
  // ---------------------------------------------------------- adımlar
  steps: {
    async cut(st) { await Cutscene.play(st.id); },
    async talk(st) { await UI.dialog(DIALOGUES[st.d] || [{ who: '?', text: st.d }]); },
    async choice(st) { await UI.dialog(DIALOGUES[st.d] || []); },
    async goto(st, tok) {
      this.setTarget(st.at); UI.objective(st.text);
      if (st.glideHint) UI.toast('İpucu: havadayken ' + Input.hint('jump') + ' basılı tut = süzül');
      let t = st.time;
      await this.waitUntil(() => this.playerNear(st.at, st.r || 8), tok, { time: t, tick: (left) => UI.objective(st.text + (left !== undefined ? ` ⏱ ${Math.ceil(left)}` : '')) });
    },
    async drive(st, tok) {
      this.setTarget(st.to); UI.objective(st.text);
      await this.waitUntil(() => {
        const v = Game.player.vehicle; const okV = !st.needVehicle || (v && (st.needVehicle === true || v.type === st.needVehicle));
        if (!okV && this.playerNear(st.to, st.r || 10)) UI.objective(st.text + ' (araçla gelmelisin)');
        return okV && this.playerNear(st.to, st.r || 10);
      }, tok, { time: st.time, tick: (left) => left !== undefined && UI.objective(st.text + ` ⏱ ${Math.ceil(left)}`) });
    },
    async fight(st, tok) {
      const waves = st.waves || [];
      const at = waves[0]?.at || Game.player.pos && [Game.player.pos.x, Game.player.pos.z];
      this.setTarget(at);
      for (let i = 0; i < waves.length; i++) {
        this.check(tok);
        // dalgalar dövüş bölgesine yaklaşınca başlar
        if (i === 0 && !this.playerNear(waves[0].at || at, 45)) { UI.objective(st.text + ' (bölgeye git)'); await this.waitUntil(() => this.playerNear(waves[0].at || at, 45), tok); }
        this.setBeacon(null);
        const list = this.spawnWave(waves[i], at, waves[i].y, tok);
        Combat.danger(list[0].pos, 40);
        await this.waitUntil(() => list.every(a => !a.alive || a.removed), tok, { tick: () => UI.objective(`${st.text} — kalan: ${list.filter(a => a.alive && !a.removed).length}${waves.length > 1 ? ` · dalga ${i + 1}/${waves.length}` : ''}`) });
      }
    },
    async boss(st, tok) {
      const [x, , z] = this.pos(st.at);
      if (!this.playerNear(st.at, 40)) { this.setTarget(st.at); UI.objective(st.text + ' (bölgeye git)'); await this.waitUntil(() => this.playerNear(st.at, 40), tok); }
      this.setBeacon(null);
      const a = Enemies.spawn(st.type, x + 3, z - 3, st.y !== undefined ? st.y + 0.2 : undefined, { tag: this.tag(), hp: st.hp, name: st.bossName, persistent: false });
      a.boss = true; a.name = st.bossName || CAST[ENEMY_TYPES[st.type].cast].name;
      if (a.def && st.escapeAt) a.def.escapeAt = st.escapeAt;
      this.bossActor = a; UI.objective(st.text);
      let escaped = false; const off = Bus.on('bossEscape', (b) => { if (b === a) { escaped = true; UI.toast(a.name + ' kaçtı!', true); } });
      await this.waitUntil(() => !a.alive || a.removed || escaped, tok).finally(off);
      this.bossActor = null; Cam.shake = 0.5;
    },
    async race(st, tok) {
      UI.objective('Bir araca bin (' + Input.hint('vehicle') + ')');
      const sv = this.ctxVehicles[this.ctxVehicles.length - 1]; if (sv) this.setTarget([sv.pos.x, sv.pos.z]);
      await this.waitUntil(() => !!Game.player.vehicle, tok);
      const cps = st.cps.map(c => locXZ(c));
      const pv = Game.player.vehicle;
      const rivals = [];
      for (let i = 0; i < (st.rivals || 0); i++) {
        const side = i % 2 ? 1 : -1;
        const v = Vehicles.spawn(i === 0 && st.rivalCast ? 'motor' : 'sport', pv.pos.x + Math.cos(pv.yaw) * 3.5 * side * (1 + Math.floor(i / 2)), pv.pos.z - Math.sin(pv.yaw) * 3.5 * side, pv.yaw, { color: i === 0 && st.rivalCast ? CAST[st.rivalCast].color : pick(['#20f0ff', '#b6ff3b', '#ffb020']), npcDriver: true, tag: this.tag() });
        v.missionRival = true; v.ai = { mode: 'race', path: cps.slice(), idx: 0, speedK: rand(0.82, 0.9) }; rivals.push(v); this.ctxVehicles.push(v);
      }
      Vehicles.mission = rivals;
      const saved = rivals.map(v => v.ai); rivals.forEach(v => v.ai = null);
      for (const n of ['3', '2', '1', 'BAŞLA!']) { this.check(tok); UI.toast('🏁 ' + n, true); Sound.beep(n.length > 1 ? 880 : 440, 0.2, 'square', 0.08); await wait(800); }
      rivals.forEach((v, i) => v.ai = saved[i]);
      let idx = 0, lost = false;
      await this.waitUntil(() => {
        const c = cps[idx]; this.setTarget(c);
        if (this.playerNear(c, 13)) { idx++; Sound.ui(); if (idx >= cps.length) return true; }
        if (!lost && rivals.some(v => v.ai && v.ai.idx >= cps.length)) lost = true;
        if (lost) throw new Error('lost');
        for (const v of rivals) if (st.rivalCast && v === rivals[0] && Math.random() < 0.5) FX.trail(_v1.set(v.pos.x, v.pos.y + 0.5, v.pos.z), '#ff6a1f', 0.3, 0.5);
        return false;
      }, tok, { time: st.time, tick: (left) => UI.objective(`${st.text} — kontrol noktası ${idx + 1}/${cps.length}${left !== undefined ? ` ⏱ ${Math.ceil(left)}` : ''}${rivals.length ? ' · sıra: ' + (1 + rivals.filter(v => (v.ai?.idx || 0) > idx).length) : ''}`) }).catch(e => { if (e.message === 'lost') { this.fail('Rakip önce bitirdi'); throw new MissionCancel(); } throw e; });
      S.stats.races++;
    },
    async chase(st, tok) {
      const path = st.path.map(p => locXZ(p));
      const [sx, sz] = path[0];
      const v = Vehicles.spawn(st.target || 'motor', sx, sz, 0, { color: '#ff8a1f', tag: this.tag() });
      const thief = Enemies.spawn('gang', sx, sz, undefined, { tag: this.tag(), aggro: false }); thief.vehicle = v; v.driver = null; thief.hidden = false; thief.st.anim = 'ride';
      v.ai = { mode: 'path', path, idx: 1, speedK: 0.7, loop: true }; v.chaseTarget = true;
      Vehicles.mission = [v]; this.ctxVehicles.push(v);
      let close = 0;
      UI.objective(st.text);
      await this.waitUntil(() => {
        this.target = [v.pos.x, v.pos.z]; this.setBeacon([v.pos.x, v.pos.z], '#ff3b3b', v.pos.y);
        thief.pos.copy(v.pos); thief.pos.y += 0.35; thief.yaw = v.yaw;
        const d = Math.sqrt(dist2(v.pos.x, v.pos.z, Game.player.pos.x, Game.player.pos.z));
        v.ai.speedK = d < 25 ? 0.78 : 0.55;
        if (d < 8) close += Game.dt; else close = Math.max(0, close - Game.dt * 0.5);
        if (v.wreck) close = 2;
        return close > 1.2;
      }, tok, { time: st.time, tick: (left) => UI.objective(`${st.text} ⏱ ${Math.ceil(left || 0)}`) });
      v.ai = null; v.speed = 0; v.vel.set(0, 0, 0); if (v.wreck) { v.wreck = false; v.hp = v.maxHp * 0.5; v.repaint('#ff8a1f'); }
      thief.vehicle = null; thief.pos.set(v.pos.x + 2, v.pos.y, v.pos.z); thief.ai.aggro = Game.player;
      UI.toast('Hırsız motordan atladı!');
      Vehicles.mission = []; v.missionRival = false; v.temp = false; v.owned = false;
      await this.waitUntil(() => !thief.alive, tok, { tick: () => UI.objective('Hırsızı etkisiz bırak') });
    },
    async collect(st, tok) {
      const items = st.items.map(i => locXZ(i)); let got = 0;
      for (const [x, z] of items) { const y = World.surfaceAt(x, z); Pickups.spawn(x, y, z, { color: '#20f0ff', size: 0.7, r: 2.2, tag: this.tag(), onPick: () => { got++; UI.toast(`${st.label || 'Eşya'} ${got}/${items.length}`); } }); }
      if (st.guards) for (const [x, z] of items) if (Math.random() < 0.6) Enemies.spawn(st.guards, x + rand(-5, 5), z + rand(-5, 5), undefined, { tag: this.tag(), aggro: false });
      await this.waitUntil(() => {
        const left = Pickups.list.filter(p => p.tag === this.tag());
        if (left.length) { const p = Game.player.pos; left.sort((a, b) => dist2(a.x, a.z, p.x, p.z) - dist2(b.x, b.z, p.x, p.z)); this.target = [left[0].x, left[0].z]; this.setBeacon(this.target, '#20f0ff'); }
        return got >= items.length;
      }, tok, { tick: () => UI.objective(`${st.text} (${got}/${items.length})`) });
    },
    async skill(st, tok) {
      const p = Game.player.pos;
      const [cx, cz] = st.at ? locXZ(st.at) : [p.x + Math.sin(Game.player.yaw) * 5, p.z + Math.cos(Game.player.yaw) * 5];
      const baseY = st.y !== undefined ? st.y + 0.2 : World.groundAt(cx, cz, p.y + 2);
      const n = st.dummies || 1, hit = new Set(); let count = 0;
      const look = st.dummyName === 'Çekirdek Kilidi' ? { skin: '#ff2fd6', hair: { style: 'visor', color: '#ff2fd6' }, torso: '#111118', arms: '#ff2fd6', hands: '#ff2fd6', legs: '#111118', shoes: '#ff2fd6', belt: '#ff2fd6', emblem: { shape: 'core', color: '#ff2fd6' } } : { skin: '#d9a21b', hair: { style: 'bald', color: '#000' }, torso: '#c9a27a', arms: '#c9a27a', hands: '#d9a21b', legs: '#8a6a4a', shoes: '#5a4030', belt: '#ff3b3b' };
      for (let i = 0; i < n; i++) {
        const ang = i / n * Math.PI * 2, x = cx + (n > 1 ? Math.cos(ang) * 4 : 0), z = cz + (n > 1 ? Math.sin(ang) * 4 : 0);
        const d = new Actor({ kind: 'dummy', team: 'dummy', cast: 'Dummy', look, pos: _v1.set(x, baseY, z), hp: 99999, persistent: true, name: st.dummyName || 'Kukla' });
        d.home = new THREE.Vector3(x, baseY, z); this.dummies.push(d);
      }
      const off1 = Bus.on('abilityHit', (e) => {
        if (!this.dummies.includes(e.target)) return;
        if (st.ability === 'punch' && e.ability === 'punch') { count++; return; }
        if (st.ability === 'any' && !hit.has(e.target)) { hit.add(e.target); count++; FX.burst(e.target.pos, '#ffd23b', 20, 7); if (!st.static) { e.target.alive = false; e.target.koT = 0; } }
      });
      const off2 = Bus.on('ability', (a) => { if (a === st.ability) count++; });
      UI.objective(st.text);
      await this.waitUntil(() => {
        for (const d of this.dummies) if (d.alive) { d.pos.x = d.home.x; d.pos.z = d.home.z; d.kb.set(0, 0, 0); d.hp = 99999; }
        return count >= st.count;
      }, tok, { time: st.time, tick: (left) => UI.objective(`${st.text} — ${count}/${st.count}${left !== undefined ? ` ⏱ ${Math.ceil(left)}` : ''}`) }).finally(() => { off1(); off2(); });
      for (const d of this.dummies) d.remove(); this.dummies = [];
    },
    async stealth(st, tok) {
      const goal = locXZ(st.goal || st.at);
      this.setTarget(goal, 'Hedef');
      const cams = st.cams.map(([x, z, deg]) => {
        const g = new THREE.Group(); const y = World.surfaceAt(x, z);
        const body = new THREE.Mesh(Geo.box, Mat.plastic('#222')); body.scale.set(0.5, 0.4, 0.7); body.position.y = 4.2; g.add(body);
        const pole = new THREE.Mesh(Geo.cylLo, Mat.plastic('#444')); pole.scale.set(0.15, 4, 0.15); pole.position.y = 2; g.add(pole);
        const coneG = new THREE.ConeGeometry(Math.tan(0.42) * 14, 14, 16, 1, true); coneG.translate(0, -7, 0); coneG.rotateX(-Math.PI / 2);
        const cone = new THREE.Mesh(coneG, new THREE.MeshBasicMaterial({ color: 0xff3b3b, transparent: true, opacity: 0.16, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, toneMapped: false }));
        cone.position.y = 4.2; cone.rotation.x = 0.28; const piv = new THREE.Group(); piv.position.y = 0; piv.add(cone); g.add(piv);
        g.position.set(x, y, z); Game.scene.add(g);
        return { mesh: g, piv, cone, x, z, y, base: deg * Math.PI / 180, ang: 0 };
      });
      this.stealth = { cams };
      let alarm = false, meter = 0;
      UI.objective(st.text);
      await this.waitUntil(() => {
        const p = Game.player.pos; let seen = false;
        for (const c of cams) {
          c.ang = c.base + Math.sin(Game.t * 0.8 + c.x) * 0.7; c.piv.rotation.y = c.ang;
          const dx = p.x - c.x, dz = p.z - c.z, d = Math.hypot(dx, dz);
          if (d < 14 && p.y < c.y + 6) { const a = Math.atan2(dx, dz); let df = Math.abs(((a - c.ang + Math.PI) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2) - Math.PI); if (df < 0.42 && World.lineClear(c.x, c.z, p.x, p.z, c.y + 1.5)) seen = true; }
        }
        const hidden = S.mask && S.outfit === 'ninja';
        meter = clamp(meter + (seen ? Game.dt * (hidden ? 0.9 : 1.6) : -Game.dt * 0.5), 0, 1);
        for (const c of cams) c.cone.material.color.setRGB(1, 1 - meter, 0.2 * (1 - meter));
        if (meter >= 1 && !alarm) { alarm = true; UI.toast('🚨 ALARM! Muhafızlar geliyor', true); for (const w of st.alarm || []) this.spawnWave(Object.assign({ at: goal }, w), goal); Sound.siren(); }
        UI.objective(st.text + (alarm ? ' — ALARM!' : seen ? ' — 👁 görülüyorsun!' : ''));
        return dist2(goal[0], goal[1], p.x, p.z) < 3.5 * 3.5;
      }, tok);
      for (const c of cams) Game.scene.remove(c.mesh); this.stealth = null;
      if (alarm) { UI.objective('Alarm muhafızlarını temizle'); await this.waitUntil(() => Enemies.count(this.tag()) === 0, tok); }
    },
    async hold(st, tok) {
      const at = locXZ(st.at);
      if (!this.playerNear(at, 30)) { this.setTarget(at); UI.objective(st.text + ' (bölgeye git)'); await this.waitUntil(() => this.playerNear(at, 30), tok); }
      this.setBeacon(null);
      let left = st.time, spawnT = 0, wi = 0;
      await this.waitUntil(() => {
        spawnT -= Game.dt;
        if (spawnT <= 0 && Enemies.count(this.tag()) < 7) { spawnT = st.time / 4; const w = st.waves[wi++ % st.waves.length]; const ang = rand(0, 6.28); this.spawnWave(Object.assign({}, w, { at: [at[0] + Math.cos(ang) * 20, at[1] + Math.sin(ang) * 20] }), at); }
        if (!this.playerNear(at, 45)) throw new Error('left');
        return false;
      }, tok, { time: st.time, timeOk: true, tick: (l) => UI.objective(`${st.text} ⏱ ${Math.ceil(l)}`) }).catch(e => { if (e && e.message === 'left') { this.fail('Bölgeden ayrıldın'); throw new MissionCancel(); } if (e && e.timeOk) return; throw e; });
      for (const a of Game.actors.slice()) if (a.tag === this.tag() && a.alive) { FX.burst(a.pos, '#ffffff', 8, 4); a.remove(); }
      UI.toast('Bölge güvende!');
    },
    async endure(st, tok) {
      const at = locXZ(st.at); let t = 0, rockT = 0;
      UI.objective(st.text);
      await this.waitUntil(() => {
        const p = Game.player;
        if (p.metalOn && this.playerNear(at, 16)) t += Game.dt;
        rockT -= Game.dt;
        if (rockT <= 0) { rockT = 0.6; const from = _v1.set(p.pos.x + rand(-6, 6), p.pos.y + 18, p.pos.z + rand(-6, 6)); Projectiles.fire(Friends.list.taskin || null, 'rock', from, _v2.set(p.pos.x - from.x + rand(-1, 1), p.pos.y - from.y, p.pos.z - from.z + rand(-1, 1)), 26, 9, { aoe: 2.5 }); }
        UI.objective(`${st.text} — ${Math.floor(t)}/${st.time} sn ${p.metalOn ? '🛡' : '(metal kapalı!)'}`);
        return t >= st.time;
      }, tok);
      UI.toast('Taşkın: "Fena değil, tamirci. Dağ seni kabul etti."');
    },
    async focus(st, tok) {
      const at = locXZ(st.at); let t = 0;
      this.setTarget(at);
      if (!this.ring) { this.ring = new THREE.Mesh(Geo.ring, new THREE.MeshBasicMaterial({ color: 0x20f0ff, transparent: true, opacity: 0.7, side: THREE.DoubleSide, toneMapped: false })); this.ring.rotation.x = -Math.PI / 2; Game.scene.add(this.ring); }
      const [x, y, z] = this.pos(at); this.ring.position.set(x, y + 0.1, z); this.ring.scale.setScalar(4); this.ring.visible = true;
      await this.waitUntil(() => {
        const p = Game.player; const inside = this.playerNear(at, 4.5); const still = Math.hypot(Input.move.x, Input.move.y) < 0.1 && p.onGround;
        if (inside && still) { t += Game.dt; p.poseOverride = 'focus'; if (Math.random() < 0.4) FX.trail(_v1.set(p.pos.x + rand(-2, 2), p.pos.y + rand(0, 3), p.pos.z + rand(-2, 2)), '#c9d3df', 0.15, 0.8); } else { t = Math.max(0, t - Game.dt * 2); p.poseOverride = null; }
        this.ring.scale.setScalar(4 - t / st.time * 2.5);
        UI.objective(`${st.text} ${Math.floor(t / st.time * 100)}%`);
        return t >= st.time;
      }, tok);
      Game.player.poseOverride = null; this.ring.visible = false;
    },
    async fly(st, tok) {
      UI.objective('Metal Ejderhasını çağır ' + Input.hint('dragon'));
      await this.waitUntil(() => !!Game.player.dragon, tok);
      const rings = st.rings.map(([x, y, z]) => { const r = new THREE.Mesh(new THREE.TorusGeometry(7, 0.5, 8, 32), Mat.neon('#20f0ff')); r.position.set(x, Math.max(y, World.groundAt(x, z, 999) + 14), z); Game.scene.add(r); return r; });
      this.rings = rings; let idx = 0;
      await this.waitUntil(() => {
        const d = Game.player.dragon; if (!d) { UI.objective('Ejderhayı tekrar çağır ' + Input.hint('dragon')); return false; }
        const r = rings[idx]; rings.forEach((rr, i) => { rr.visible = i >= idx; rr.material = Mat.neon(i === idx ? '#ffd23b' : '#20f0ff'); rr.lookAt(d.head.position); });
        this.target = [r.position.x, r.position.z];
        if (d.head.position.distanceTo(r.position) < 9) { idx++; Sound.ok(); Player.energy = Math.min(100, Player.energy + 12); if (idx >= rings.length) return true; }
        UI.objective(`${st.text} ${idx}/${rings.length}`);
        return false;
      }, tok);
      for (const r of rings) Game.scene.remove(r); this.rings = null;
    },
    async escort(st, tok) {
      const f = Friends.spawn(st.npc, [Game.player.pos.x + 2, Game.player.pos.z + 2]); f.follow = true; f.passive = true;
      this.setTarget(st.to); UI.objective(st.text);
      await this.waitUntil(() => { if (!f.alive) throw new Error('escortDown'); return this.playerNear(st.to, st.r || 10) && f.distTo(Game.player) < 12; }, tok).catch(e => { if (e && e.message === 'escortDown') { this.fail(f.name + ' yaralandı'); throw new MissionCancel(); } throw e; });
      f.follow = false;
    },
    async tp(st) {
      await UI.fade(1);
      const p = Game.player; if (p.vehicle) Vehicles.exit(p, true); if (p.dragon) Dragon.dismount();
      let pos = st.pos;
      if (!pos) { const [x, z] = locXZ(st.near); pos = [x + (st.dx || 0), World.surfaceAt(x + (st.dx || 0), z + (st.dz || 0)) + (st.up || 0), z + (st.dz || 0)]; }
      p.pos.set(pos[0], pos[1], pos[2]); p.vel.set(0, 0, 0);
      if (S.allyWith && Game.ally && !Game.ally.removed) { Game.ally.pos.set(pos[0] + 1.5, pos[1], pos[2] + 1.5); Game.ally.vel.set(0, 0, 0); }
      for (const k in Friends.list) { const fr = Friends.list[k]; if (fr.alive && !fr.hidden && fr.distTo(p) > 30) fr.pos.set(pos[0] + rand(-3, 3), pos[1], pos[2] + rand(-3, 3)); }
      Cam.snap(); await wait(200); await UI.fade(0);
    },
    async unlock(st) { S.abilities[st.ability] = true; const n = { tornado: 'KASIRGA DÖNÜŞÜ', glide: 'HAVADA SÜZÜLME', dragon: 'METAL EJDERHASI' }[st.ability] || st.ability; UI.toast('✨ YENİ YETENEK: ' + n, true); Sound.ok(); FX.burst(_v1.copy(Game.player.pos).setY(Game.player.pos.y + 1), '#ffffff', 30, 8); },
    async set(st) { S.flags[st.flag] = true; },
    async func(st, tok) { const f = Missions.funcs[st.fn]; if (f) await f.call(Missions, st.arg, tok); else console.warn('func yok', st.fn); },
    async branch(st, tok) { await this.runSteps(S.flags[st.flag] ? st.yes : st.no, tok); },
    async wardrobe(st, tok) {
      UI.objective(st.text);
      await this.waitUntil(() => S.outfit === 'ninja' && S.mask, tok, { tick: () => UI.objective(`${st.text} ${S.outfit === 'ninja' ? '✅' : Input.hint('wardrobe')} kostüm · ${S.mask ? '✅' : Input.hint('mask')} maske`) });
      UI.toast('Kimliğin gizli. Maske + kostüm aranma seviyesinin daha hızlı düşmesini sağlar.');
    },
    async storage(st, tok) {
      let done = false; const off = Bus.on('storage', () => done = true);
      this.setTarget(LOC.harborSafe); UI.objective(st.text);
      if (S.carried.length < 2) S.carried.push('staff');
      await this.waitUntil(() => done, tok).finally(off);
    },
    async ending(st, tok) {
      const good = S.morality >= 0 && S.bondLevel >= 50, dark = S.morality <= 0 || S.moralPath === 'vengeful';
      const opts = [];
      if (good) opts.push({ text: '🌅 Çekirdeği yok et, gücü doğaya geri ver.', flag: 'end_good' });
      if (dark) opts.push({ text: '👑 Çekirdeği kendine mühürle. Şehir senin olsun.', flag: 'end_dark' });
      opts.push({ text: '🕊 Gücünü feda et, çekirdeği söndür. Herkesi kurtar.', flag: 'end_sacrifice' });
      if (!good) UI.toast(`(Koruyucu final için ahlak ≥ 0 ve bağ ≥ 50 gerekir — şu an ahlak ${S.morality}, bağ ${Math.floor(S.bondLevel)})`);
      await UI.dialog([{ who: CAST.Hero_Main.name, text: 'Çekirdek ellerimde. Karar benim.' }, { choice: opts }]);
      const which = S.flags.end_good ? 'good' : S.flags.end_dark ? 'dark' : 'sacrifice';
      delete S.flags.end_good; delete S.flags.end_dark; delete S.flags.end_sacrifice;
      S.ending = which;
      if (which === 'dark') { Ally.leave(); S.isRecognizedNinja = false; S.flags.crimeLord = true; S.money += 5000; }
      if (which === 'sacrifice') { for (const k in S.abilities) S.abilities[k] = false; Player.metalOff(); }
      FX.burst(World.coreMesh.position, '#ff2fd6', 60, 14, 0.4, 1.4); World.coreMesh.visible = which === 'dark';
      await Cutscene.play('end_' + which);
      UI.toast('🎬 SON — ' + { good: 'Koruyucu Final', dark: 'Suç Lordu Finali', sacrifice: 'Fedakârlık Finali' }[which] + ' · Serbest dolaşım açık', true);
      if (which !== 'dark') { S.allyWith = true; Ally.join(); }
    }
  },
  // ---------------------------------------------------------- özel fonksiyonlar
  funcs: {
    giveWeapon(k) { if (S.carried.includes(k)) return; if (S.carried.length - 1 < MAX_CARRY) S.carried.push(k); else S.storage.push(k); S.equipped = S.carried.indexOf(k); UI.toast(WEAPONS[k].icon + ' ' + WEAPONS[k].name + ' alındı · Silah tekerleği: ' + Input.hint('wheel')); },
    spawnVehicle(o) { const [x, z] = locXZ(o.at); const v = Vehicles.spawn(o.type, x + (o.dx || 0), z + (o.dz || 0), Math.PI, { temp: !!o.temp, tag: this.tag() }); this.ctxVehicles.push(v); return v; },
    ownVehicle(type) { const v = Game.player.vehicle || this.ctxVehicles.find(x => x.type === type); if (!v) return; v.temp = false; Vehicles.own(v); UI.toast('🔑 ' + v.def.name + ' artık senin! (Garaj)'); },
    policeRaid(n) { if (S.isRecognizedNinja) return; S.wanted = Math.max(S.wanted, n); Crime.lastSeen = Game.t; UI.toast('🚨 Polis baskını! Kapsülleri al ve kaç!', true); },
    clearWanted() { if (S.wanted > 0) { UI.toast('Liman işçileri seni sakladı — polis uzaklaştı.'); Crime.clear(); } },
    unlockSafehouse(id) { if (!S.safehouses.includes(id)) S.safehouses.push(id); UI.toast('🏠 Yeni güvenli ev: ' + districtAt(...LOC[id]).name, true); },
    repLevel(n) { S.reputation = Math.max(S.reputation, n); },
    spawnAllyAt(p) { const a = Ally.spawn(_v1.set(p[0], p[1], p[2])); a.hidden = false; a.face(Game.player.pos.x, Game.player.pos.z); },
    allyJoin() { Ally.join(); },
    spawnFriend([key, at, dx]) { Friends.spawn(key, at, dx || 0, 0); },
    setWeather(w) { Sky.setWeather(w, true); },
    recognizeNinja() {
      S.isRecognizedNinja = true; Crime.clear();
      UI.toast('🥷 DÖNÜM NOKTASI: Artık Gerçek Ninjasın! Polis sana saldırmaz, suçlularla savaşır.', true);
      addMessage('Komiser Aras', 'Teşkilat artık sizinle. Kartel görürseniz haber verin — ya da halledin.');
    },
    captureAllies() { for (const k of ['ray', 'derya', 'ayaz', 'filiz', 'kor']) Friends.despawn(k); S.flags.captured = true; addMessage('Ela', 'Ray, Derya, Ayaz ve Filiz\'i götürdüler. Kor da onlarla. Toparlan, Kaan.'); },
    setCurfew(on) { S.flags.curfew = on; Sky.curfew = on; if (on) logEvent('m41', RADIO.news.m41); },
    explode(at) { const [x, y, z] = this.pos(at); for (let i = 0; i < 6; i++) setTimeout(() => { FX.burst(_v1.set(x + rand(-12, 12), y + rand(1, 8), z + rand(-12, 12)), pick(['#ff6a1f', '#ffd23b', '#ff2fd6']), 30, 12, 0.4, 1.2); FX.ring(_v1.set(x, y, z), '#ff6a1f', 18, 0.8); Cam.shake = 0.6; Sound.slam(); }, i * 250); Combat.danger(_v1.set(x, y, z), 80); },
    freeAllies(keys) { for (const k of keys) { const f = Friends.spawn(k, [Game.player.pos.x + rand(-3, 3), Game.player.pos.z + rand(-3, 3)]); FX.burst(f.pos, '#ffd23b', 16, 5); } S.flags.freed = (S.flags.freed || 0) + keys.length; changeBond(3); },
    finalPathInfo() {
      const path = S.moralPath === 'vengeful' ? 'sert/intikamcı' : 'koruyucu/birleştirici';
      UI.toast(`Final yolu: ${path} · Ahlak ${S.morality} · Bağ ${Math.floor(S.bondLevel)}`, true);
      for (const k of ['ray', 'derya', 'taskin']) Friends.despawn(k);
    },
    korRedeemed() { S.flags.korRedeemed = true; const f = Friends.spawn('kor', [Game.player.pos.x + 3, Game.player.pos.z]); f.pos.y = Game.player.pos.y; changeMorality(1); },
    async fadeSit(at) {
      await UI.fade(1);
      const [x, y, z] = this.pos(at), p = Game.player;
      p.pos.set(x, y, z); p.yaw = 0; p.poseOverride = 'sit'; p.vel.set(0, 0, 0);
      if (Game.ally && S.allyWith) { Game.ally.pos.set(x + 1.2, y, z); Game.ally.yaw = 0; Game.ally.poseOverride = 'sit'; }
      Cam.yaw = Math.PI * 0.85; Cam.pitch = 0.15; Cam.snap(); await UI.fade(0);
    },
    heal() { Game.player.hp = Game.player.maxHp; Game.player.poseOverride = null; if (Game.ally) Game.ally.poseOverride = null; },
    gymBonus() { S.flags.gym = Math.min(5, (S.flags.gym || 0) + 1); Player.applyGymBonus(); UI.toast('💪 Maks. can +10 (toplam +' + S.flags.gym * 10 + ')'); if (S.allyWith) changeBond(4, 'birlikte antrenman'); },
    energyBoost() { Player.energy = 100; Player.maxEnergy = 100; S.flags.boostUntil = Game.t + 120; Game.player.poseOverride = null; if (Game.ally) Game.ally.poseOverride = null; UI.toast('🍍 Enerji doldu + 2 dk hızlı enerji yenilenmesi'); },
    modFree(k) { const v = S.vehicles.find(x => x.type === 'motor') || S.vehicles[0]; if (v) { v.mods[k] = Math.min(3, (v.mods[k] || 0) + 1); UI.toast('🔧 Ücretsiz turbo: ' + VEHICLES[v.type].name + ' hız +1'); for (const gv of Game.vehicles) if (gv.uid === v.uid) gv.mods = v.mods; } }
  },
  // ---------------------------------------------------------- kare güncellemesi
  update(dt) {
    for (let i = this.waiters.length - 1; i >= 0; i--) {
      const w = this.waiters[i];
      if (w.tok !== this.token) { this.waiters.splice(i, 1); w.reject(new MissionCancel()); continue; }
      if (w.time !== undefined) w.time -= dt;
      try { w.tick && w.tick(w.time); if (w.cond()) { this.waiters.splice(i, 1); w.resolve(); continue; } }
      catch (e) { this.waiters.splice(i, 1); w.reject(e); continue; }
      if (w.time !== undefined && w.time <= 0) {
        this.waiters.splice(i, 1);
        if (w.timeOkFlag) w.resolve();
        else { const err = new Error('timeout'); err.timeOk = true; w.reject(err); if (!w.tickOnly) { /* hold adımı timeOk ile çözer */ } }
      }
    }
    // zaman aşımı → hold dışında başarısızlık
    this.markT -= dt;
    if (this.markT <= 0) { this.markT = 1; this.refreshMarkers(); }
    this.animBeacons(dt);
    Eggs.update(dt);
    if (S.flags.boostUntil && Game.t < S.flags.boostUntil) Player.energy = Math.min(100, Player.energy + dt * 10);
  },
  refreshMarkers() {
    const av = this.active ? [] : this.available();
    this.markers = av.map(m => { const [x, z] = locXZ(m.at); return { m, x, z, y: World.surfaceAt(x, z), color: m.kind === 'side' ? '#20f0ff' : m.kind === 'activity' ? '#ff7ad9' : '#ffd23b' }; });
    const p = Game.player.pos;
    const near = this.markers.filter(k => dist2(k.x, k.z, p.x, p.z) < 400 * 400).slice(0, 12);
    while (this.beacons.length < near.length) {
      const g = new THREE.Group(); const mat = new THREE.MeshBasicMaterial({ color: 0xffd23b, transparent: true, opacity: 0.22, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending, toneMapped: false });
      const c = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 80, 12, 1, true), mat); c.position.y = 40; g.add(c);
      const icon = new THREE.Mesh(Geo.box, mat.clone()); icon.material.opacity = 0.9; icon.scale.set(1.2, 1.2, 1.2); icon.position.y = 3; icon.rotation.set(0.6, 0, 0.6); g.add(icon);
      Game.scene.add(g); this.beacons.push(g);
    }
    this.beacons.forEach((b, i) => { const k = near[i]; b.visible = !!k; if (k) { b.position.set(k.x, k.y, k.z); b.children[0].material.color.set(k.color); b.children[1].material.color.set(k.color); } });
  },
  animBeacons(dt) { for (const b of this.beacons) if (b.visible) { b.children[1].rotation.y += dt * 2; b.children[1].position.y = 3 + Math.sin(Game.t * 2) * 0.4; } if (this.tBeacon && this.tBeacon.visible) this.tBeacon.children[1].scale.setScalar(3 + Math.sin(Game.t * 4) * 0.5); }
};
// süre dolunca: hold adımı başarı, diğerleri başarısızlık
(function patchTimeouts() {
  const orig = Missions.waitUntil.bind(Missions);
  Missions.waitUntil = function (cond, tok, opt = {}) {
    const p = orig(cond, tok, opt);
    if (opt.timeOk) { const w = this.waiters[this.waiters.length - 1]; w.timeOkFlag = true; return p; }
    return p.catch(e => { if (e && e.timeOk && !(e instanceof MissionCancel)) { this.fail(opt.failMsg || 'Süre doldu'); throw new MissionCancel(); } throw e; });
  };
})();

// ---------------------------------------------------------------- Easter Egg'ler
const Eggs = {
  chicken: null, symbols: [], init: false, t: 0,
  setup() {
    if (!S.eggs.e_tape) EGGS.find(e => e.id === 'e_tape').symbols.forEach(([x, z], i) => {
      x = +x; z = +z;
      if (S.flags['sym' + i]) return;
      // en yakın binanın çatısına yerleştir
      let best = null, bd = 30 * 30;
      for (const b of World.boxes) { if (b.tag !== 'bld') continue; const cx = (b.x0 + b.x1) / 2, cz = (b.z0 + b.z1) / 2, d = dist2(cx, cz, x, z); if (d < bd) { bd = d; best = b; } }
      if (best) { x = (best.x0 + best.x1) / 2; z = (best.z0 + best.z1) / 2; }
      const y = World.groundAt(x, z, 999);
      const o = Pickups.spawn(x, y, z, { color: '#b6ff3b', size: 0.9, r: 2.5, geo: Geo.torus, tag: 'egg', onPick: () => { S.flags['sym' + i] = true; const n = [0, 1, 2].filter(k => S.flags['sym' + k]).length; UI.toast(`🔣 Çatı sembolü ${n}/3`); if (n >= 3) UI.dialog(DIALOGUES.e_tape).then(() => this.found('e_tape')); } });
      this.symbols.push(o);
    });
    if (!S.eggs.e_teacup && !S.flags.teacupHeld) { const [x, z] = EGGS.find(e => e.id === 'e_teacup').at; Pickups.spawn(x, World.terrainH(x, z), z, { color: '#e8d8b0', size: 0.4, r: 2, geo: Geo.cyl, tag: 'egg', onPick: () => { S.flags.teacupHeld = true; UI.toast('🍵 Antika çay fincanı bulundu — Hikmet Usta\'ya götür'); } }); }
    this.buildBackroom();
    this.init = true;
  },
  found(id) { if (S.eggs[id]) return; S.eggs[id] = true; const e = EGGS.find(x => x.id === id); UI.toast('🥚 EASTER EGG: ' + (e ? e.title : id) + ' (+100 ₺)', true); changeMoney(100); Sound.ok(); saveGame(); },
  buildBackroom() {
    const x = -40, z = 97, y = -40, g = new THREE.Group(); Game.scene.add(g);
    World.block(x, y - 1, z - 6, 16, 1, 14, '#1a0a33', true, g); World.block(x, y + 5, z - 6, 16, 0.5, 14, '#1a0a33', false, g);
    for (const [wx, wz, w, d] of [[x - 8, z - 6, 0.5, 14], [x + 8, z - 6, 0.5, 14], [x, z - 13, 16, 0.5], [x, z + 1, 16, 0.5]]) World.block(wx, y, wz, w, 5, d, '#2a1050', true, g);
    for (let k = 0; k < 4; k++) { World.block(x - 6 + k * 4, y, z - 11.5, 2, 2.6, 1.2, pick(['#ff2fd6', '#20f0ff', '#b6ff3b', '#ffb020']), true, g); World.mesh(Geo.box, Mat.neon(pick(['#ff2fd6', '#20f0ff', '#ffd23b'])), x - 6 + k * 4, y + 1.6, z - 10.85, 1.6, 0.9, 0.05, g); }
    World.mesh(Geo.box, Mat.neon('#ff2fd6'), x, y + 4.5, z - 12.7, 14, 0.3, 0.1, g); World.mesh(Geo.box, Mat.neon('#20f0ff'), x - 7.7, y + 4.5, z - 6, 0.1, 0.3, 12, g);
    const l = new THREE.PointLight(0xff2fd6, 40, 20, 1.5); l.position.set(x, y + 3.5, z - 6); g.add(l);
    World.addInteract({ id: 'backroomExit', x, z: z - 1, r: 2.5, label: 'Dışarı çık', cond: () => Game.player.pos.y < -20, action: async () => { await UI.fade(1); Game.player.pos.set(-40, 0, 94); Cam.snap(); await UI.fade(0); } });
    this.backroomPos = [x, y, z - 4];
  },
  async backroom() {
    await UI.fade(1); const [x, y, z] = this.backroomPos; const p = Game.player; p.pos.set(x, y, z); p.vel.set(0, 0, 0); p.allowDeep = true;
    if (S.allyWith && Game.ally) { Game.ally.pos.set(x + 1, y, z); Game.ally.allowDeep = true; }
    Cam.snap(); await UI.fade(0);
    if (!S.eggs.e_backroom) { await UI.dialog(DIALOGUES.e_backroom); this.found('e_backroom'); for (let k = 0; k < 4; k++) Pickups.spawnMoney(_v1.set(x - 6 + k * 4, y, z - 8), 40); }
  },
  update(dt) {
    if (!this.init) return;
    const p = Game.player; if (!p) return;
    this.t -= dt; if (this.t > 0) return; this.t = 0.1;
    // Kaçak Beyaz Tavuk
    if (!S.eggs.e_chicken) {
      const [bx, bz] = LOC.bazaar; const dd = dist2(p.pos.x, p.pos.z, bx, bz);
      if (!this.chicken && dd < 90 * 90) {
        const g = new THREE.Group(); const w = Mat.plastic('#ffffff');
        World.mesh(Geo.box, w, 0, 0.35, 0, 0.5, 0.4, 0.6, g); World.mesh(Geo.box, w, 0, 0.75, 0.22, 0.28, 0.3, 0.28, g); World.mesh(Geo.box, Mat.plastic('#ff3b3b'), 0, 0.95, 0.24, 0.08, 0.14, 0.2, g); World.mesh(Geo.box, Mat.plastic('#ffb020'), 0, 0.72, 0.4, 0.1, 0.08, 0.14, g);
        g.position.set(bx + 6, 0, bz + 6); Game.scene.add(g); this.chicken = { g, vx: 0, vz: 0, t: 0 }; UI.toast('🐔 Bir yerlerden tavuk sesi geliyor…');
      }
      if (this.chicken) {
        const c = this.chicken, cp = c.g.position; const d = Math.sqrt(dist2(cp.x, cp.z, p.pos.x, p.pos.z));
        c.t -= 0.1; if (c.t <= 0) { c.t = rand(0.6, 1.4); const flee = d < 7; const ang = flee ? Math.atan2(cp.x - p.pos.x, cp.z - p.pos.z) + rand(-0.7, 0.7) : rand(0, 6.28); const sp = flee ? 7 : 1.5; c.vx = Math.sin(ang) * sp; c.vz = Math.cos(ang) * sp; }
        const nx = clamp(cp.x + c.vx * 0.1, bx - 45, bx + 45), nz = clamp(cp.z + c.vz * 0.1, bz - 45, bz + 45);
        const tp = new THREE.Vector3(nx, 0, nz); World.collide(tp, 0.4, 1); cp.set(tp.x, World.groundAt(tp.x, tp.z, 2) + Math.abs(Math.sin(Game.t * 12)) * 0.1, tp.z); c.g.rotation.y = Math.atan2(c.vx, c.vz);
        if (d < 1.4) { Game.scene.remove(c.g); this.chicken = null; UI.dialog([...DIALOGUES.e_chicken, ...DIALOGUES.e_chicken_end]).then(() => this.found('e_chicken')); }
        if (d > 140) { Game.scene.remove(c.g); this.chicken = null; }
      }
    }
    // Zirve gizli bakış noktası
    if (!S.eggs.e_peak) { const [x, z] = LOC.peakSecret; if (dist2(p.pos.x, p.pos.z, x, z) < 5 * 5 && !Missions.active && Game.mode === 'play') { this.found('e_peak'); Cutscene.play('c_peak', { keepTime: false }); } }
    if (p.pos.y > -20) { p.allowDeep = false; if (Game.ally) Game.ally.allowDeep = false; }
  }
};
