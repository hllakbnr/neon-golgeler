// ============================================================================
//  AKTÖRLER — fizik, oyuncu kontrolü, kamera, dövüş, mermiler, müttefik AI,
//  siviller (yağmur/panik), çeteler, polis + aranma, patronlar, Metal Ejderhası
// ============================================================================
const SIDE = { player: 'hero', ally: 'hero', friend: 'hero', civ: 'civ', gang: 'gang', police: 'police', dummy: 'dummy' };
function isHostile(a, b) {
  if (!a || !b || a === b || !a.alive || !b.alive) return false;
  const sa = SIDE[a.team], sb = SIDE[b.team];
  if (sa === sb) return false;
  if (sa === 'civ' || sb === 'civ') return false;
  if (sa === 'dummy' || sb === 'dummy') return sa === 'hero' || sb === 'hero';
  if ((sa === 'gang' && sb === 'police') || (sa === 'police' && sb === 'gang')) return true;
  if ((sa === 'hero' && sb === 'gang') || (sa === 'gang' && sb === 'hero')) return true;
  if ((sa === 'police' && sb === 'hero') || (sa === 'hero' && sb === 'police')) return S.wanted > 0 && !S.isRecognizedNinja;
  return false;
}
const ELEMENT_FX = { Master_Lightning: ['bolt', '#ffd23b'], Master_Fire: ['fire', '#ff6a1f'], Master_Water: ['water', '#38d6ff'], Master_Earth: ['rock', '#a8916a'], Master_Ice: ['ice', '#bff4ff'], Master_Green: ['leaf', '#6fbf3a'], Ally_Partner: ['wind', '#7fffe0'], Boss_Architect: ['shard', '#ff2fd6'] };

class Actor {
  constructor(o) {
    this.kind = o.kind || 'civ'; this.team = o.team || 'civ'; this.cast = o.cast || 'Gang';
    this.fig = makeFigure(this.cast, o.outfit || 'civil', o.look || null);
    this.pos = new THREE.Vector3().copy(o.pos || _v1.set(0, 0, 0));
    this.vel = new THREE.Vector3(); this.want = new THREE.Vector3(); this.kb = new THREE.Vector3();
    this.yaw = o.yaw || 0; this.maxHp = this.hp = o.hp || 50; this.alive = true;
    this.radius = 0.45 * (this.fig.lookData?.scale || 1); this.height = 1.9 * (this.fig.lookData?.scale || 1);
    this.onGround = true; this.swim = false; this.fly = !!o.fly;
    this.st = { anim: 'idle', speed: 0, punch: 0, punchSide: 0, kick: 0, slam: 0, cast: 0, hit: 0 };
    this.cd = 0; this.combo = 0; this.koT = 0; this.stun = 0; this.poseOverride = null; this.umbrella = false;
    this.ai = Object.assign({ mode: 'idle', t: 0 }, o.ai || {});
    this.etype = o.etype || null; this.def = o.def || null; this.name = o.name || CAST[this.cast]?.name || '';
    this.dmg = o.dmg || 8; this.moveSpeed = o.speed || 4.5; this.ranged = !!o.ranged; this.boss = !!o.boss;
    this.tag = o.tag || null; this.persistent = !!o.persistent; this.vehicle = null; this.hidden = false;
    this.fig.root.position.copy(this.pos); this.fig.root.rotation.y = this.yaw;
    Game.scene.add(this.fig.root);
    Game.actors.push(this);
  }
  get dead() { return !this.alive; }
  remove() { Game.scene.remove(this.fig.root); const i = Game.actors.indexOf(this); if (i >= 0) Game.actors.splice(i, 1); this.removed = true; if (this.tornado) this.tornado.visible = false; }
  face(x, z, k = 1) { const t = Math.atan2(x - this.pos.x, z - this.pos.z); this.yaw = angLerp(this.yaw, t, k); }
  distTo(o) { return Math.sqrt(dist2(this.pos.x, this.pos.z, o.pos.x, o.pos.z)); }
  damage(amount, from, opt = {}) {
    if (!this.alive || this.invuln) return;
    if (this.kind === 'player') {
      if (this.metalOn) amount *= 0.25;
      if (this.spinT > 0) amount *= 0.5;
      if (this.dragon) amount *= 0.4;
    }
    this.hp -= amount; this.st.hit = 1; this.stun = Math.max(this.stun, opt.stun || 0.18);
    if (opt.knock && from) { const dx = this.pos.x - from.pos.x, dz = this.pos.z - from.pos.z, l = Math.hypot(dx, dz) || 1; this.kb.set(dx / l * opt.knock, 0, dz / l * opt.knock); if (opt.lift) this.vel.y = opt.lift; }
    FX.burst(_v1.set(this.pos.x, this.pos.y + 1.2, this.pos.z), this.kind === 'player' && this.metalOn ? '#e8f0ff' : opt.color || '#ffd23b', 6, 5, 0.12, 0.4);
    if (this.kind === 'player') Cam.shake = Math.max(Cam.shake, 0.14); else if (from && from.kind === 'player') Cam.shake = Math.max(Cam.shake, 0.06);
    if (from && from.kind === 'player') { if (this.hp - amount <= 0 && this.hp > 0) this._koHit = true; }
    if (this.boss && this.def && this.def.onHit) this.def.onHit(this);
    if (from && from.kind === 'player' && !opt.noCrime) Crime.onPlayerHit(this, opt);
    if (this.hp <= 0) this.die(from);
    else if (this.ai && from && this.kind !== 'player') { this.ai.aggro = from; if (this.kind === 'civ') Population.panic(this, from.pos); }
  }
  die(from) {
    this.alive = false; this.hp = 0; this.koT = 0; this.st.anim = 'ko';
    if (this.tornado) this.tornado.visible = false;
    Bus.emit('actorDown', { actor: this, from });
    if (from && (from.kind === 'player' || from.kind === 'ally' || from.kind === 'friend') && this.team === 'gang') {
      S.stats.kos++; const et = ENEMY_TYPES[this.etype]; if (et) { changeRep(et.rep * 0.5); if (et.money) Pickups.spawnMoney(this.pos, et.money); }
    }
    if (this.kind === 'player') Player.onDeath();
    if (this.kind === 'ally') { this.reviveT = 6; }
  }
  update(dt) {
    const st = this.st;
    st.punch = Math.max(0, st.punch - dt * 4); st.kick = Math.max(0, st.kick - dt * 3.5); st.hit = Math.max(0, st.hit - dt * 4); st.cast = Math.max(0, st.cast - dt * 3);
    this.cd -= dt; this.stun -= dt;
    if (this.dragon) return;
    if (this.vehicle) { this.syncVisual(dt); return; }
    if (!this.alive) {
      this.koT += dt;
      this.vel.y -= 24 * dt; this.pos.addScaledVector(this.kb, dt); this.kb.multiplyScalar(Math.max(0, 1 - dt * 3));
      this.pos.y += this.vel.y * dt; const g = World.groundAt(this.pos.x, this.pos.z, this.pos.y); if (this.pos.y < g) { this.pos.y = g; this.vel.y = 0; }
      if (this.kind === 'ally' && this.reviveT !== undefined) { this.reviveT -= dt; if (this.reviveT <= 0) { this.alive = true; this.hp = this.maxHp * 0.5; delete this.reviveT; } }
      this.syncVisual(dt);
      if (!this.persistent && this.koT > 9) this.remove();
      return;
    }
    // Yatay hız
    const acc = this.onGround || this.fly ? (this.accel || 12) : (this.kind === 'player' ? 9 : 3.5);
    const wx = this.stun > 0 ? 0 : this.want.x, wz = this.stun > 0 ? 0 : this.want.z;
    this.vel.x = lerp(this.vel.x, wx, Math.min(1, dt * acc)); this.vel.z = lerp(this.vel.z, wz, Math.min(1, dt * acc));
    this.pos.x += (this.vel.x + this.kb.x) * dt; this.pos.z += (this.vel.z + this.kb.z) * dt;
    this.kb.multiplyScalar(Math.max(0, 1 - dt * 5));
    // Dikey
    if (this.fly) {
      const g = World.groundAt(this.pos.x, this.pos.z, this.pos.y);
      const ty = (this.flyY ?? g + 3.2); this.pos.y = lerp(this.pos.y, Math.max(ty, g + 1.5) + Math.sin(Game.t * 2 + this.yaw) * 0.3, dt * 3); this.onGround = false;
    } else {
      if (this.gliding) this.vel.y = Math.max(this.vel.y - 6 * dt, -2.0); else this.vel.y -= (this.kind === 'player' ? 30 : 24) * dt;
      this.pos.y += this.vel.y * dt;
    }
    World.collide(this.pos, this.radius, this.height);
    if (!this.fly) {
      const g = World.groundAt(this.pos.x, this.pos.z, this.pos.y);
      const was = this.onGround;
      if (this.pos.y <= g || (was && this.vel.y <= 0 && this.pos.y - g < 0.45)) { this.pos.y = g; if (this.vel.y < 0) this.vel.y = 0; this.onGround = true; }
      else this.onGround = false;
      this.swim = false;
      if (g < WATER_Y - 0.5 && this.pos.y < WATER_Y - 1.1) { this.pos.y = WATER_Y - 1.1; this.vel.y = Math.max(0, this.vel.y); this.swim = true; this.onGround = true; }
    }
    this.pos.x = clamp(this.pos.x, -900, 900); this.pos.z = clamp(this.pos.z, -900, 900);
    if (this.pos.y < -30 && !this.allowDeep) { const g = World.groundAt(this.pos.x, this.pos.z, 500); this.pos.y = Math.max(g, WATER_Y); }
    // Animasyon durumu
    const sp = Math.hypot(this.vel.x, this.vel.z); st.speed = sp;
    if (this.poseOverride) st.anim = this.poseOverride;
    else if (this.swim) st.anim = 'swim';
    else if (this.spinT > 0) st.anim = 'spin';
    else if (!this.onGround && !this.fly) st.anim = this.gliding ? 'glide' : 'jump';
    else if (sp > 6.2) st.anim = 'run';
    else if (sp > 0.4) st.anim = this.umbrella ? 'umbrella' : 'walk';
    else st.anim = this.umbrella ? 'umbrella' : 'idle';
    if (this.umbrella && st.anim === 'idle') st.speed = 0;
    this.syncVisual(dt);
  }
  syncVisual(dt) {
    const r = this.fig.root;
    r.visible = !this.hidden;
    if (this.hidden) return;
    r.position.copy(this.pos);
    if (!this.alive) { if (this.fig.skinned && this.fig.actions.death) r.rotation.set(0, this.yaw, 0); else { r.rotation.set(-Math.PI / 2 * Math.min(1, this.koT * 4), this.yaw, 0); r.position.y += 0.25; } }
    else { r.rotation.x = 0; r.rotation.z = 0; if (this.spinT > 0) { this.spinAng = (this.spinAng || 0) + dt * 22; r.rotation.y = this.spinAng; } else r.rotation.y = this.yaw; }
    this.fig.setUmbrella(this.umbrella && this.alive);
    // Mesafe tabanlı animasyon LOD
    const cd = dist2(this.pos.x, this.pos.z, Game.camera.position.x, Game.camera.position.z);
    if (cd > 110 * 110 && this.kind !== 'player') { r.visible = cd < Settings.viewDist * Settings.viewDist * 0.5; return; }
    this.fig.animate(dt, this.st);
    if (this.tornado) { this.tornado.visible = this.spinT > 0; if (this.tornado.visible) { this.tornado.position.copy(this.pos); this.tornado.rotation.y += dt * 9; } }
  }
}

// ---------------------------------------------------------------- Dövüş
const Combat = {
  melee(att, range, dmg, opt = {}) {
    let hits = 0;
    const fx = Math.sin(att.yaw), fz = Math.cos(att.yaw);
    for (const t of Game.actors) {
      if (t === att || !t.alive || t.hidden) continue;
      if (att.kind === 'player' || att.kind === 'ally' || att.kind === 'friend') { if (SIDE[t.team] === 'hero') continue; if (att.kind !== 'player' && !isHostile(att, t)) continue; }
      else if (!isHostile(att, t)) continue;
      const dx = t.pos.x - att.pos.x, dz = t.pos.z - att.pos.z, dy = t.pos.y - att.pos.y;
      const d = Math.hypot(dx, dz); if (d > range + t.radius || Math.abs(dy) > 2.2) continue;
      if (!opt.aoe && d > 0.3 && (dx * fx + dz * fz) / d < (opt.arc ?? 0.35)) continue;
      t.damage(dmg, att, { knock: opt.knock ?? 6, lift: opt.lift, stun: opt.stun, color: opt.color });
      if (opt.ability) Bus.emit('abilityHit', { ability: opt.ability, target: t, from: att });
      hits++;
    }
    if (opt.vehicles) Vehicles.impulse(att.pos, range, opt.vehicles);
    if (hits && att.kind === 'player') Sound.hit();
    return hits;
  },
  danger(pos, r = 25) { Population.alarm(pos, r); }
};

// ---------------------------------------------------------------- Mermiler (havuz)
const Projectiles = {
  pool: [], live: [],
  mats: {},
  init() {
    const defs = { shuriken: '#e8f0ff', bullet: '#ffd23b', wind: '#7fffe0', fire: '#ff6a1f', shard: '#d6dde6', bolt: '#ffe85a', water: '#38d6ff', ice: '#bff4ff', leaf: '#6fbf3a', rock: '#a8916a', core: '#ff2fd6' };
    for (const k in defs) this.mats[k] = Mat.neon(defs[k]);
    for (let i = 0; i < 60; i++) { const m = new THREE.Mesh(Geo.box, this.mats.bullet); m.visible = false; m.castShadow = false; Game.scene.add(m); this.pool.push(m); }
  },
  fire(owner, kind, from, dir, speed, dmg, opt = {}) {
    const m = this.pool.find(x => !x.visible); if (!m) return;
    m.visible = true; m.material = this.mats[kind] || this.mats.bullet;
    m.geometry = kind === 'wind' ? Geo.torus : (kind === 'fire' || kind === 'water' || kind === 'core') ? Geo.sphere : kind === 'shard' || kind === 'ice' ? Geo.cone : Geo.box;
    const s = { shuriken: [0.35, 0.06, 0.35], bullet: [0.12, 0.12, 0.5], wind: [0.7, 0.7, 0.7], fire: [0.6, 0.6, 0.6], shard: [0.3, 0.8, 0.3], bolt: [0.15, 0.15, 1.4], water: [0.55, 0.55, 0.55], ice: [0.3, 0.7, 0.3], leaf: [0.4, 0.1, 0.3], rock: [0.6, 0.6, 0.6], core: [0.9, 0.9, 0.9] }[kind] || [0.2, 0.2, 0.5];
    m.scale.set(...s); m.position.copy(from);
    this.live.push({ m, owner, kind, vel: dir.clone().normalize().multiplyScalar(speed), dmg, life: opt.life || 2.2, knock: opt.knock ?? (kind === 'wind' ? 14 : 5), aoe: opt.aoe || 0, ability: opt.ability });
  },
  update(dt) {
    for (let i = this.live.length - 1; i >= 0; i--) {
      const p = this.live[i]; p.life -= dt; p.m.position.addScaledVector(p.vel, dt);
      if (p.kind === 'shuriken') p.m.rotation.y += dt * 25; else p.m.lookAt(_v1.copy(p.m.position).add(p.vel));
      if (p.kind === 'shard' || p.kind === 'ice') p.m.rotateX(Math.PI / 2);
      if (Math.random() < 0.5) FX.trail(p.m.position, '#' + p.m.material.color.getHexString(), 0.1, 0.25);
      let hit = false; const pp = p.m.position;
      for (const t of Game.actors) {
        if (!t.alive || t === p.owner || t.hidden) continue;
        const own = p.owner;
        if (own && (own.kind === 'player') ? SIDE[t.team] === 'hero' : !isHostile(own, t)) continue;
        if (Math.abs(pp.x - t.pos.x) < t.radius + 0.5 && Math.abs(pp.z - t.pos.z) < t.radius + 0.5 && pp.y > t.pos.y - 0.2 && pp.y < t.pos.y + t.height + 0.3) {
          t.damage(p.dmg, own, { knock: p.knock, color: '#' + p.m.material.color.getHexString() });
          if (p.ability) Bus.emit('abilityHit', { ability: p.ability, target: t, from: own });
          hit = true; break;
        }
      }
      const g = World.groundAt(pp.x, pp.z, pp.y);
      if (!hit && pp.y < g) hit = true;
      if (!hit) for (const b of World.nearBoxes(pp.x, pp.z)) if (!b.dead && pp.x > b.x0 && pp.x < b.x1 && pp.z > b.z0 && pp.z < b.z1 && pp.y > b.y0 && pp.y < b.y1) { hit = true; break; }
      if (hit || p.life <= 0) {
        if (hit) { FX.burst(pp, '#' + p.m.material.color.getHexString(), 8, 5, 0.14, 0.4); if (p.aoe) { FX.ring(pp, '#' + p.m.material.color.getHexString(), p.aoe, 0.4); const fake = { pos: pp.clone(), yaw: 0, kind: p.owner?.kind, team: p.owner?.team, alive: true }; Combat.melee(Object.assign(Object.create(Actor.prototype), fake, { pos: pp.clone() }), p.aoe, p.dmg * 0.6, { aoe: true, knock: 8 }); } }
        p.m.visible = false; this.live.splice(i, 1);
      }
    }
  }
};

// ---------------------------------------------------------------- Ses (WebAudio — basit sentez)
const Sound = {
  ctx: null,
  init() { try { this.ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { } },
  beep(f = 440, d = 0.08, type = 'square', v = 0.08) {
    if (!this.ctx || Settings.volume <= 0) return; if (this.ctx.state === 'suspended') this.ctx.resume();
    const o = this.ctx.createOscillator(), g = this.ctx.createGain(); o.type = type; o.frequency.value = f;
    g.gain.value = v * Settings.volume; g.gain.exponentialRampToValueAtTime(0.0001, this.ctx.currentTime + d);
    o.connect(g).connect(this.ctx.destination); o.start(); o.stop(this.ctx.currentTime + d);
  },
  hit() { this.beep(rand(140, 200), 0.09, 'square', 0.1); }, slam() { this.beep(70, 0.35, 'sawtooth', 0.18); }, shoot() { this.beep(900, 0.05, 'triangle', 0.06); },
  ui() { this.beep(660, 0.05, 'sine', 0.05); }, ok() { this.beep(523, 0.1, 'sine', 0.08); setTimeout(() => this.beep(784, 0.15, 'sine', 0.08), 90); },
  horn() { this.beep(330, 0.3, 'sawtooth', 0.08); }, siren() { this.beep(Math.sin(Game.t * 6) > 0 ? 960 : 720, 0.12, 'sine', 0.025); }
};

// ---------------------------------------------------------------- Kamera
function smoothDampV(cur, target, vel, t, dt) {
  const o = 2 / Math.max(0.0001, t), x = o * dt, e = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);
  for (const k of ['x', 'y', 'z']) { const ch = cur[k] - target[k], tmp = (vel[k] + o * ch) * dt; vel[k] = (vel[k] - o * tmp) * e; cur[k] = target[k] + (ch + tmp) * e; }
}
const Cam = {
  cv: new THREE.Vector3(), lv: new THREE.Vector3(),
  yaw: Math.PI, pitch: 0.28, dist: 6.5, cur: new THREE.Vector3(), look: new THREE.Vector3(), shake: 0, override: null,
  update(dt) {
    if (this.override) return; // sinematik oynatıcı kontrol ediyor
    const p = Game.player; if (!p) return;
    this.yaw -= Input.look.x; this.pitch = clamp(this.pitch + Input.look.y, -0.45, 1.25);
    let target, dist;
    if (p.dragon) { target = _v1.copy(p.dragon.head.position).add(_v3.set(0, 2, 0)); dist = 15; }
    else if (p.vehicle) {
      const v = p.vehicle; target = _v1.set(v.pos.x, v.pos.y + 1.6, v.pos.z); dist = v.def.kind === 'truck' ? 12 : 8.5;
      if (Math.abs(Input.look.x) < 0.001 && v.speed > 4) this.yaw = angLerp(this.yaw, v.yaw + Math.PI, dt * 2.2);
    } else { target = _v1.set(p.pos.x, p.pos.y + 1.6, p.pos.z); dist = this.dist * (p.metalOn ? 1.1 : 1); }
    const cp = Math.cos(this.pitch);
    const desired = _v2.set(target.x + Math.sin(this.yaw) * cp * dist, target.y + Math.sin(this.pitch) * dist, target.z + Math.cos(this.yaw) * cp * dist);
    // çarpışma (kameranın bina içine girmemesi)
    let tMax = 1;
    for (let i = 1; i <= 10; i++) {
      const t = i / 10, x = lerp(target.x, desired.x, t), y = lerp(target.y, desired.y, t), z = lerp(target.z, desired.z, t);
      let blocked = y < World.baseHeight(x, z) + 0.3;
      if (!blocked) for (const b of World.nearBoxes(x, z)) if (!b.dead && x > b.x0 - 0.2 && x < b.x1 + 0.2 && z > b.z0 - 0.2 && z < b.z1 + 0.2 && y > b.y0 && y < b.y1 + 0.2) { blocked = true; break; }
      if (blocked) { tMax = Math.max(0.12, (i - 1) / 10); break; }
    }
    desired.lerpVectors(target, desired, tMax);
    // yaylı (smooth damp) takip — gecikmesiz ve sarsıntısız; engelde anında yaklaş
    const st = p.vehicle ? 0.14 : p.dragon ? 0.2 : 0.07;
    if (tMax < 1 && this.cur.distanceTo(target) > desired.distanceTo(target)) this.cur.copy(desired);
    else smoothDampV(this.cur, desired, this.cv, st, dt);
    smoothDampV(this.look, target, this.lv, 0.04, dt);
    const cam = Game.camera; cam.position.copy(this.cur);
    if (this.shake > 0) { this.shake -= dt; cam.position.x += rand(-1, 1) * this.shake * 0.5; cam.position.y += rand(-1, 1) * this.shake * 0.5; }
    cam.lookAt(this.look);
    const fov = p.vehicle ? 62 + clamp(p.vehicle.speed, 0, 50) * 0.28 : p.dragon ? 74 : (p.dashT > 0 ? 74 : 62 + clamp(Math.hypot(p.vel.x, p.vel.z) - 6, 0, 6) * 1.1);
    if (Math.abs(cam.fov - fov) > 0.1) { cam.fov = lerp(cam.fov, fov, dt * 3); cam.updateProjectionMatrix(); }
  },
  snap() { const p = Game.player; if (!p) return; this.cur.set(p.pos.x + Math.sin(this.yaw) * 6, p.pos.y + 3, p.pos.z + Math.cos(this.yaw) * 6); this.look.set(p.pos.x, p.pos.y + 1.6, p.pos.z); },
  forward() { return _v3.set(-Math.sin(this.yaw), 0, -Math.cos(this.yaw)); }
};

// ---------------------------------------------------------------- Oyuncu
const Player = {
  a: null, energy: 100, maxEnergy: 100, wheelOpen: false, lastSafe: null,
  create(pos) {
    const a = new Actor({ kind: 'player', team: 'player', cast: 'Hero_Main', outfit: S.outfit, pos, hp: 120, persistent: true });
    a.fig.setMask(S.mask); a.persistent = true; a.spinT = 0; a.accel = 34;
    a.tornado = this.makeTornado('#c9d3df'); Game.scene.add(a.tornado);
    Game.player = this.a = a; this.applyGymBonus();
    return a;
  },
  applyGymBonus() { const b = S.flags.gym || 0; this.a.maxHp = 120 + b * 10; this.a.hp = Math.min(this.a.hp, this.a.maxHp); },
  makeTornado(color) {
    const g = new THREE.Group(); g.visible = false;
    const mat = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.28, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending, toneMapped: false });
    for (let i = 0; i < 3; i++) { const c = new THREE.Mesh(new THREE.CylinderGeometry(1.6 + i * 0.5, 0.4 + i * 0.25, 2.6 + i * 0.3, 16, 1, true), mat); c.position.y = 1.3 + i * 0.1; c.rotation.y = i; g.add(c); }
    return g;
  },
  weapon() { return WEAPONS[S.carried[S.equipped]] || WEAPONS.fists; },
  update(dt) {
    const a = this.a; if (!a) return;
    if (!a.alive) return;
    const ctl = Game.mode === 'play' && !Game.inputLock;
    this.energy = Math.min(this.maxEnergy, this.energy + dt * (a.metalOn || a.spinT > 0 || a.dragon ? 0 : 7));
    if (a.dragon) { Dragon.control(dt, ctl); return; }
    if (a.vehicle) { Vehicles.drive(a.vehicle, dt, ctl); if (ctl && Input.pressed('vehicle')) Vehicles.exit(a); return; }
    // Hareket
    let mx = ctl ? Input.move.x : 0, my = ctl ? Input.move.y : 0;
    const fw = Cam.forward(), rt = _v2.set(-fw.z, 0, fw.x);
    const dir = _v3.set(fw.x * my + rt.x * mx, 0, fw.z * my + rt.z * mx);
    const mag = Math.min(1, dir.length());
    let speed = Input.isDown('sprint') ? 11.5 : 6.2;
    if (a.metalOn) speed *= 0.72; if (a.spinT > 0) speed = 10; if (a.swim) speed = 3.2;
    if (mag > 0.05) { dir.normalize(); a.want.set(dir.x * speed * mag, 0, dir.z * speed * mag); a.yaw = angLerp(a.yaw, Math.atan2(dir.x, dir.z), Math.min(1, dt * 22)); }
    else a.want.set(0, 0, 0);
    if (a.poseOverride && mag > 0.1) a.poseOverride = null;
    // Zıplama / süzülme
    a.gliding = false;
    // atılma (dash): kısa, hızlı, kısa dokunulmazlık
    a.dashT = Math.max(0, (a.dashT || 0) - dt); a.dashCd = Math.max(0, (a.dashCd || 0) - dt);
    const dashPressed = ctl && (Input.pressed('dash') || (Input.device === 'pad' && Input.pressed('interact') && !Interact.cur));
    if (dashPressed && a.dashCd <= 0 && this.energy >= 8 && !a.swim) {
      this.energy -= 8; a.dashT = 0.2; a.dashCd = 0.55; a.invuln = true; setTimeout(() => { a.invuln = false; }, 220);
      const dd = mag > 0.05 ? _v2.set(dir.x, 0, dir.z) : _v2.set(Math.sin(a.yaw), 0, Math.cos(a.yaw)); a.yaw = Math.atan2(dd.x, dd.z);
      a.vel.x = dd.x * 22; a.vel.z = dd.z * 22; FX.ring(a.pos, '#c9d3df', 2.5, 0.25); Sound.beep(420, 0.08, 'triangle', 0.05);
    }
    if (a.dashT > 0) { a.want.set(Math.sin(a.yaw) * 22, 0, Math.cos(a.yaw) * 22); if (Math.random() < 0.8) FX.trail(_v1.set(a.pos.x, a.pos.y + 1, a.pos.z), a.metalOn ? '#e8f0ff' : '#7a5cff', 0.25, 0.3); }
    if (ctl && Input.pressed('jump') && (a.onGround || a.swim)) { a.vel.y = a.swim ? 6 : 10.2; a.onGround = false; Sound.beep(300, 0.06, 'sine', 0.04); }
    if (ctl && S.abilities.glide && !a.onGround && Input.isDown('jump') && a.vel.y < 0) {
      a.gliding = true; const f = _v2.set(Math.sin(a.yaw), 0, Math.cos(a.yaw)); a.want.addScaledVector(f, 7);
      if (Math.random() < 0.4) FX.trail(_v1.set(a.pos.x, a.pos.y + 1.2, a.pos.z), '#7fffe0', 0.15, 0.5);
    }
    if (!ctl) return;
    // Silah tekerleği
    if (Input.pressed('wheel')) UI.openWheel(); if (Input.released('wheel')) UI.closeWheel(true);
    if (Input.pressed('next')) this.cycleWeapon(1); if (Input.pressed('prev')) this.cycleWeapon(-1);
    // Metal sertleşmesi
    if (Input.pressed('metal') && !S.abilities.metal) UI.toast('Güçlerin artık yok…');
    if (Input.pressed('metal') && S.abilities.metal) { if (!a.metalOn && this.energy > 10) { a.metalOn = true; a.fig.setMetal(true); FX.burst(_v1.set(a.pos.x, a.pos.y + 1, a.pos.z), '#e8f0ff', 18, 6); Sound.beep(180, 0.2, 'sawtooth', 0.08); Bus.emit('ability', 'metal'); } else this.metalOff(); }
    if (a.metalOn) { this.energy -= dt * 4.5; if (this.energy <= 0) this.metalOff(); }
    // Saldırılar
    const w = this.weapon();
    if (Input.isDown('attack') && a.cd <= 0 && a.spinT <= 0) this.attack(w);
    if (Input.pressed('heavy') && a.cd <= 0) this.shockwave();
    if (Input.pressed('spin')) this.tornadoSpin();
    if (Input.pressed('dragon')) Dragon.toggle();
    if (a.spinT > 0) {
      a.spinT -= dt;
      if ((a.spinTick = (a.spinTick || 0) - dt) <= 0) { a.spinTick = 0.22; Combat.melee(a, 3.6, 9 * (a.metalOn ? 1.5 : 1), { aoe: true, knock: 9, lift: 3, ability: 'tornado', vehicles: 4 }); }
      if (Math.random() < 0.6) FX.trail(_v1.set(a.pos.x + rand(-1.5, 1.5), a.pos.y + rand(0, 2.5), a.pos.z + rand(-1.5, 1.5)), '#c9d3df', 0.18, 0.4);
    }
    // Etkileşim & araç
    if (Input.pressed('vehicle')) { const v = Vehicles.nearest(a.pos, 4.2); if (v) Vehicles.enter(a, v); }
    if (Input.pressed('interact')) Interact.use();
    if (Input.pressed('wardrobe')) UI.wardrobe();
    if (Input.pressed('mask')) this.toggleMask();
    if (Input.pressed('phone')) UI.phone();
    if (Input.pressed('callally')) Ally.call();
    if (Input.pressed('pause')) UI.pause();
  },
  metalOff() { const a = this.a; if (!a.metalOn) return; a.metalOn = false; a.fig.setMetal(false); },
  toggleMask() { S.mask = !S.mask; this.a.fig.setMask(S.mask); UI.toast(S.mask ? '😷 Maske takıldı' : 'Maske çıkarıldı'); Bus.emit('mask', S.mask); },
  setOutfit(o) { S.outfit = o; this.a.fig.setOutfit(o); if (this.a.metalOn) { this.a.fig.metal = false; this.a.fig.setMetal(true); } Bus.emit('outfit', o); },
  cycleWeapon(d) { S.equipped = (S.equipped + d + S.carried.length) % S.carried.length; UI.toast(this.weapon().icon + ' ' + this.weapon().name); },
  attack(w) {
    const a = this.a;
    if (w.kind === 'ranged') {
      a.cd = w.rate; a.st.cast = 1;
      const tgt = this.autoTarget(28);
      const from = _v1.set(a.pos.x, a.pos.y + 1.35, a.pos.z);
      let dir;
      if (tgt) { dir = _v2.set(tgt.pos.x - from.x, tgt.pos.y + 1.1 - from.y, tgt.pos.z - from.z); a.face(tgt.pos.x, tgt.pos.z); }
      else { const f = Cam.forward(); dir = _v2.set(f.x, -0.02, f.z); a.yaw = Math.atan2(f.x, f.z); }
      Projectiles.fire(a, S.carried[S.equipped] === 'shuriken' ? 'shuriken' : 'bullet', from, dir, w.speed, w.dmg * (a.metalOn ? 1.3 : 1), { ability: 'ranged' });
      Sound.shoot(); Combat.danger(a.pos, 30);
      if (!S.isRecognizedNinja) Crime.weaponSeen();
      return;
    }
    const tgt = this.autoTarget(4.5); if (tgt) a.face(tgt.pos.x, tgt.pos.z, 0.7);
    a.combo = (a.combo + 1) % 3; a.cd = w.rate * (a.metalOn ? 1.25 : 1);
    if (a.combo === 2) a.st.kick = 1; else { a.st.punch = 1; a.st.punchSide = a.combo; }
    const dmg = w.dmg * (a.metalOn ? 1.6 : 1) * (a.combo === 2 ? 1.4 : 1);
    setTimeout(() => { if (a.alive) { const h = Combat.melee(a, w.range, dmg, { knock: a.combo === 2 ? 10 : 5, ability: 'punch', color: a.metalOn ? '#e8f0ff' : '#ffd23b' }); if (h) { Cam.shake = 0.08; Combat.danger(a.pos, 22); } } }, 90);
  },
  shockwave() {
    const a = this.a; const cost = 20; if (!S.abilities.shockwave) return; if (this.energy < cost) { UI.toast('Enerji yetersiz'); return; }
    this.energy -= cost; a.cd = 0.6; a.st.slam = 1;
    const r = a.metalOn ? 7.5 : 5.2;
    setTimeout(() => {
      a.st.slam = 0; if (!a.alive) return;
      FX.ring(a.pos, '#c9d3df', r, 0.45); FX.ring(a.pos, '#ffffff', r * 0.6, 0.3); FX.burst(_v1.set(a.pos.x, a.pos.y + 0.3, a.pos.z), '#9aa3ad', 26, 9, 0.22, 0.7);
      Combat.melee(a, r, 22 * (a.metalOn ? 1.5 : 1), { aoe: true, knock: 16, lift: 6, ability: 'shockwave', vehicles: 10 });
      // çevredeki metal parçalar (hurda) savrulur
      for (let i = 0; i < 10; i++) FX.burst(_v1.set(a.pos.x + rand(-r, r), a.pos.y + 0.2, a.pos.z + rand(-r, r)), '#b9c3cf', 1, 8, 0.3, 1.0);
      Cam.shake = 0.35; Sound.slam(); Combat.danger(a.pos, 35); Bus.emit('ability', 'shockwave');
    }, 260);
  },
  tornadoSpin() {
    const a = this.a; if (!S.abilities.tornado) { UI.toast('Kasırga Dönüşü henüz açılmadı (Görev 1.2)'); return; }
    if (this.energy < 30 || a.spinT > 0) { if (this.energy < 30) UI.toast('Enerji yetersiz'); return; }
    this.energy -= 30; a.spinT = 2.4; a.spinTick = 0; Sound.beep(220, 0.5, 'sawtooth', 0.05); Bus.emit('ability', 'tornado');
  },
  autoTarget(range) {
    const a = this.a; let best = null, bd = range * range;
    const f = Cam.forward();
    for (const t of Game.actors) {
      if (t === a || !t.alive || t.hidden) continue;
      if (!(isHostile(a, t) || t.team === 'dummy')) continue;
      const d = dist2(t.pos.x, t.pos.z, a.pos.x, a.pos.z); if (d > bd) continue;
      const dx = t.pos.x - a.pos.x, dz = t.pos.z - a.pos.z, l = Math.sqrt(d) || 1;
      if (range > 6 && (dx * f.x + dz * f.z) / l < 0.4) continue;
      bd = d; best = t;
    }
    return best;
  },
  onDeath() {
    UI.toast('💥 Bayıldın…', true);
    Missions.fail('Bayıldın');
    setTimeout(async () => {
      await UI.fade(1);
      const a = this.a; a.alive = true; a.hp = a.maxHp; this.energy = 100; this.metalOff();
      Crime.clear(); changeMoney(-Math.floor(S.money * 0.1));
      const sp = this.respawnPoint(); a.pos.set(sp[0], World.surfaceAt(sp[0], sp[1]), sp[1]); a.vel.set(0, 0, 0);
      Cam.snap(); Population.clearHostiles(); saveGame();
      await UI.fade(0);
      UI.toast(S.safehouses.length ? 'Güvenli evde uyandın.' : 'Hastanede uyandın. (-%10 para)');
    }, 2200);
  },
  respawnPoint() {
    if (!S.safehouses.length) return LOC.hospital;
    let best = LOC[S.safehouses[0]], bd = 1e12; const p = this.a.pos;
    for (const s of S.safehouses) { const l = LOC[s]; const d = dist2(l[0], l[1], p.x, p.z); if (d < bd) { bd = d; best = l; } }
    return best;
  }
};

// ---------------------------------------------------------------- Müttefik: Ela Poyraz
const Ally = {
  a: null,
  spawn(pos) {
    if (this.a && !this.a.removed) { this.a.pos.copy(pos); this.a.hidden = false; return this.a; }
    const a = new Actor({ kind: 'ally', team: 'ally', cast: 'Ally_Partner', outfit: S.outfit === 'ninja' ? 'ninja' : 'civil', pos, hp: 140, persistent: true });
    a.tornado = Player.makeTornado('#7fffe0'); Game.scene.add(a.tornado); a.spinT = 0;
    Game.ally = this.a = a; return a;
  },
  join() { S.allyWith = true; S.allyUnlocked = true; const p = Game.player.pos; if (!this.a || this.a.removed) this.spawn(_v1.set(p.x + 2, p.y, p.z + 2)); this.a.hidden = false; },
  leave() { S.allyWith = false; if (this.a) { this.a.hidden = true; if (this.a.vehicle) Vehicles.exit(this.a, true); } },
  call() {
    if (!S.allyUnlocked) { UI.toast('Henüz kimseyi arayamazsın.'); return; }
    if (S.allyWith) { UI.dialogLines([{ who: 'Ela', text: pick(['Buradayım Kaan, gözüm üstünde.', 'Yine ne oldu? Dur tahmin edeyim: kartel.', 'Rüzgârı dinliyorum. Devam et.']) }]); return; }
    UI.dialogLines([{ who: 'Kaan', text: 'Ela, neredesin? Gelebilir misin?' }, { who: 'Ela', text: pick(['Üç dakikaya oradayım. Rüzgârla gelirim.', 'Geliyorum — bu sefer smoothie senden.', 'Tamam, ama tuhaf bir şey yapma.']) }]).then(() => {
      setTimeout(() => { const p = Game.player.pos; this.join(); this.a.pos.set(p.x + 8, World.groundAt(p.x + 8, p.z + 8, p.y + 2), p.z + 8); FX.burst(_v1.copy(this.a.pos).setY(this.a.pos.y + 1), '#7fffe0', 20, 6); UI.toast('🌀 Ela geldi'); }, 2500);
    });
  },
  outfitSync() { if (this.a && !this.a.removed) this.a.fig.setOutfit(S.outfit === 'ninja' ? 'ninja' : 'civil'); },
  update(dt) {
    const a = this.a; if (!a || a.removed || !S.allyWith) return;
    const p = Game.player;
    if (!a.alive) return;
    // Araçta / ejderhada
    if (p.vehicle) { if (!a.vehicle) Vehicles.board(a, p.vehicle); return; }
    if (a.vehicle && !p.vehicle) Vehicles.exit(a, false);
    a.hidden = !!p.dragon; if (p.dragon) { a.pos.copy(p.pos); return; }
    const d = a.distTo(p);
    if (d > 45 || Math.abs(a.pos.y - p.pos.y) > 12 || (a._stuck > 1 && d > 15)) { a.pos.set(p.pos.x - Math.sin(p.yaw) * 3, p.pos.y, p.pos.z - Math.cos(p.yaw) * 3); a.vel.set(0, 0, 0); FX.burst(_v1.copy(a.pos).setY(a.pos.y + 1), '#7fffe0', 14, 5); }
    a.umbrella = Sky.rainAmt > 0.3 && !Game.combat && S.outfit === 'civil';
    // Hedef
    let tgt = null, td = 22 * 22;
    for (const t of Game.actors) if (t.alive && !t.hidden && (isHostile(a, t)) && t.team !== 'dummy') { const dd = dist2(t.pos.x, t.pos.z, p.pos.x, p.pos.z); if (dd < td) { td = dd; tgt = t; } }
    a.spinT = Math.max(0, (a.spinT || 0) - dt);
    if (tgt) {
      const dt2 = a.distTo(tgt); a.face(tgt.pos.x, tgt.pos.z, Math.min(1, dt * 10));
      if (dt2 > 7) this.moveTo(a, tgt.pos, 7.5); else if (dt2 < 3.5) this.moveTo(a, _v1.set(a.pos.x * 2 - tgt.pos.x, 0, a.pos.z * 2 - tgt.pos.z), 5); else a.want.set(0, 0, 0);
      if (a.cd <= 0) {
        if (Math.random() < 0.22 && dt2 < 6) { a.spinT = 1.6; a.cd = 2.6; Combat.melee(a, 4, 12, { aoe: true, knock: 14, lift: 5 }); FX.ring(a.pos, '#7fffe0', 5, 0.5); }
        else { a.cd = 1.3; a.st.cast = 1; const from = _v1.set(a.pos.x, a.pos.y + 1.3, a.pos.z); Projectiles.fire(a, 'wind', from, _v2.set(tgt.pos.x - from.x, tgt.pos.y + 1 - from.y, tgt.pos.z - from.z), 30, 13, { knock: 14 }); }
      }
      if (a.spinT > 0 && Math.random() < 0.15) Combat.melee(a, 3.5, 4, { aoe: true, knock: 8 });
    } else {
      const side = _v1.set(p.pos.x + Math.cos(p.yaw) * 2.2 - Math.sin(p.yaw) * 1.6, 0, p.pos.z - Math.sin(p.yaw) * 2.2 - Math.cos(p.yaw) * 1.6);
      const dd = Math.sqrt(dist2(side.x, side.z, a.pos.x, a.pos.z));
      const psp = Math.hypot(p.vel.x, p.vel.z);
      if (dd > 1.0) this.moveTo(a, side, dd > 7 ? 12.5 : dd > 3 ? Math.max(6.5, psp * 1.1) : Math.max(3.5, psp)); else { a.want.set(0, 0, 0); a.yaw = angLerp(a.yaw, p.yaw, dt * 3); }
      if (p.vel.y > 4 && a.onGround && d < 6) a.vel.y = 8.6;
    }
    a.gliding = !a.onGround && a.vel.y < 0 && S.abilities.glide;
  },
  // Yönlendirme (steering): önü tara, engel/su varsa sağa-sola sap; takılırsa yan adım at
  blocked(x, z, y) {
    if (World.baseHeight(x, z) < WATER_Y && World.groundAt(x, z, y + 0.7) < WATER_Y) return true;
    for (const b of World.nearBoxes(x, z)) if (!b.dead && x > b.x0 - 0.35 && x < b.x1 + 0.35 && z > b.z0 - 0.35 && z < b.z1 + 0.35 && y < b.y1 - 0.65 && y + 1.8 > b.y0) return true;
    return false;
  },
  moveTo(a, t, sp) {
    let dx = t.x - a.pos.x, dz = t.z - a.pos.z; const l = Math.hypot(dx, dz) || 1; dx /= l; dz /= l;
    if (a.fly) { a.want.set(dx * sp, 0, dz * sp); a.yaw = angLerp(a.yaw, Math.atan2(dx, dz), 0.2); return; }
    const look = Math.min(l, 1.8);
    if (this.blocked(a.pos.x + dx * look, a.pos.z + dz * look, a.pos.y)) {
      const side = a._steerSide || (a._steerSide = Math.random() < 0.5 ? 1 : -1);
      let ok = false;
      outer: for (const ang of [0.6, 1.1, 1.6, 2.2]) for (const sd of [side, -side]) {
        const c = Math.cos(ang * sd), s2 = Math.sin(ang * sd), nx = dx * c - dz * s2, nz = dx * s2 + dz * c;
        if (!this.blocked(a.pos.x + nx * 1.6, a.pos.z + nz * 1.6, a.pos.y)) { dx = nx; dz = nz; ok = true; a._steerSide = sd; break outer; }
      }
    }
    // takılma algılama
    const moving = Math.hypot(a.vel.x, a.vel.z);
    if (sp > 1 && moving < 0.35 && a.onGround) a._stuck = (a._stuck || 0) + Game.dt; else a._stuck = Math.max(0, (a._stuck || 0) - Game.dt);
    if (a._stuck > 1.2) { a._stuck = 0; a._steerSide = -(a._steerSide || 1); if (a.kind === 'civ' && a.ai && a.ai.mode === 'walk') { const n = World.roadNodes[a.ai.to]; if (n && n.n.length) { a.ai.from = a.ai.to; a.ai.to = pick(n.n); } } a.vel.x += -dz * 3 * a._steerSide; a.vel.z += dx * 3 * a._steerSide; }
    a.want.set(dx * sp, 0, dz * sp); a.yaw = angLerp(a.yaw, Math.atan2(dx, dz), 0.25);
  }
};

// ---------------------------------------------------------------- Dost NPC'ler (ustalar vb.)
const Friends = {
  list: {},
  spawn(key, at, dx = 0, dz = 0) {
    const [x, z] = locXZ(at);
    const cast = FRIEND_CAST[key] || key;
    let f = this.list[key];
    const y = World.groundAt(x + dx, z + dz, (Game.player?.pos.y || 0) + 3);
    if (f && !f.removed) { f.pos.set(x + dx, y, z + dz); f.hidden = false; f.alive = true; f.hp = f.maxHp; return f; }
    f = new Actor({ kind: 'friend', team: 'friend', cast, pos: _v1.set(x + dx, y, z + dz), hp: 200, persistent: true, speed: 5 });
    f.key = key; this.list[key] = f; return f;
  },
  despawn(key) { const f = this.list[key]; if (f) { f.remove(); delete this.list[key]; } },
  clear() { for (const k in this.list) this.despawn(k); },
  update(dt) {
    for (const k in this.list) {
      const f = this.list[k]; if (!f.alive || f.hidden) continue;
      if (f.follow) { const p = Game.player; const d = f.distTo(p); if (d > 3) Ally.moveTo(f, p.pos, d > 10 ? 8 : 4.5); else f.want.set(0, 0, 0); if (d > 60) f.pos.copy(p.pos); continue; }
      const fx = ELEMENT_FX[f.cast]; if (!fx || f.passive) { f.want.set(0, 0, 0); continue; }
      let tgt = null, td = 20 * 20;
      for (const t of Game.actors) if (isHostile(f, t) && t.team !== 'dummy') { const d = dist2(t.pos.x, t.pos.z, f.pos.x, f.pos.z); if (d < td) { td = d; tgt = t; } }
      if (tgt) {
        f.face(tgt.pos.x, tgt.pos.z, 0.2); const d = Math.sqrt(td);
        if (d > 10) Ally.moveTo(f, tgt.pos, 5); else f.want.set(0, 0, 0);
        if (f.cd <= 0) { f.cd = rand(1.4, 2.2); f.st.cast = 1; const from = _v1.set(f.pos.x, f.pos.y + 1.3, f.pos.z); Projectiles.fire(f, fx[0], from, _v2.set(tgt.pos.x - from.x, tgt.pos.y + 1 - from.y, tgt.pos.z - from.z), 28, 14, { aoe: fx[0] === 'rock' ? 3 : 0 }); }
      } else f.want.set(0, 0, 0);
    }
  }
};

// ---------------------------------------------------------------- Düşman spawn + AI
const Enemies = {
  spawn(type, x, z, y, opt = {}) {
    const d = ENEMY_TYPES[type] || ENEMY_TYPES.gang;
    const gy = y !== undefined ? y : World.surfaceAt(x, z);
    const a = new Actor({ kind: d.team === 'police' ? 'police' : 'enemy', team: d.team, cast: d.cast, pos: _v1.set(x, gy, z), hp: opt.hp || d.hp, dmg: d.dmg, speed: d.speed, ranged: d.ranged, fly: d.fly, boss: d.boss, etype: type, persistent: !!opt.persistent, tag: opt.tag, name: opt.name });
    if (d.fly) a.flyY = gy + 3.5;
    if (opt.aggro !== false) a.ai.aggro = Game.player;
    a.ai.home = new THREE.Vector3(x, gy, z);
    if (d.boss) a.def = Bosses[type] ? Object.assign({}, Bosses[type]) : null;
    return a;
  },
  update(dt) {
    Game.combat = false;
    const p = Game.player;
    for (const a of Game.actors) {
      if (!a.alive || (a.kind !== 'enemy' && a.kind !== 'police') || a.vehicle) continue;
      // hedef seçimi
      let tgt = a.ai.target;
      if (!tgt || !tgt.alive || tgt.hidden || !isHostile(a, tgt) || (a.ai.retarget -= dt) < 0) {
        a.ai.retarget = 1; tgt = null; let td = (a.ai.aggro ? 45 : 16) ** 2;
        for (const t of Game.actors) { if (t === a || !isHostile(a, t) || t.hidden) continue; const d = dist2(t.pos.x, t.pos.z, a.pos.x, a.pos.z) * (t.kind === 'player' ? 0.7 : 1); if (d < td) { td = d; tgt = t; } }
        a.ai.target = tgt;
      }
      if (!tgt) { // devriye / bekleme
        if (a.kind === 'police') Population.patrol(a, dt); else a.want.set(0, 0, 0);
        continue;
      }
      if (tgt.kind === 'player' || tgt.kind === 'ally') Game.combat = true;
      if (a.kind === 'police' && tgt.kind === 'player' && !Crime.seen && Crime.lastPos && a.distTo(tgt) > 12) { Ally.moveTo(a, Crime.lastPos, a.moveSpeed * 0.9); continue; }
      const d = a.distTo(tgt);
      a.face(tgt.pos.x, tgt.pos.z, Math.min(1, dt * 8));
      if (a.boss && a.def && a.def.think) { a.def.think(a, tgt, dt, d); continue; }
      if (a.ranged) {
        const pref = a.fly ? 9 : 11;
        if (d > pref + 4) Ally.moveTo(a, tgt.pos, a.moveSpeed); else if (d < pref - 4) Ally.moveTo(a, _v1.set(a.pos.x * 2 - tgt.pos.x, 0, a.pos.z * 2 - tgt.pos.z), a.moveSpeed * 0.8); else { const s = Math.sin(Game.t + a.yaw * 3); a.want.set(Math.cos(a.yaw) * s * 2, 0, -Math.sin(a.yaw) * s * 2); }
        if (a.fly) a.flyY = tgt.pos.y + 3.2;
        if (a.cd <= 0 && d < 28) { a.cd = rand(1.4, 2.2); a.st.cast = 1; const from = _v1.set(a.pos.x, a.pos.y + 1.3, a.pos.z); const k = a.etype === 'drone' || a.etype === 'elite' ? 'core' : 'bullet'; Projectiles.fire(a, k, from, _v2.set(tgt.pos.x - from.x + rand(-0.8, 0.8), tgt.pos.y + 1 - from.y, tgt.pos.z - from.z + rand(-0.8, 0.8)), k === 'core' ? 24 : 36, a.dmg, { knock: 3 }); if (k === 'bullet') Sound.shoot(); Combat.danger(a.pos, 25); }
      } else {
        if (d > 1.6) Ally.moveTo(a, tgt.pos, a.moveSpeed * (d > 8 ? 1.2 : 1)); else a.want.set(0, 0, 0);
        if (d < 2.2 && a.cd <= 0 && a.stun <= 0) { a.cd = rand(0.9, 1.4); a.st.punch = 1; a.st.punchSide = Math.random() < 0.5 ? 1 : 0; setTimeout(() => { if (a.alive && a.distTo(tgt) < 2.6) tgt.damage(a.dmg, a, { knock: 4 }); }, 140); }
      }
    }
  },
  count(tag) { return Game.actors.filter(a => a.alive && a.tag === tag).length; },
  killTag(tag) { for (const a of Game.actors.slice()) if (a.tag === tag) a.remove(); }
};

// ---------------------------------------------------------------- Patronlar
const Bosses = {
  hook: { think(a, t, dt, d) {
    a.ai.t = (a.ai.t || 0) - dt;
    if (a.ai.charge > 0) { a.ai.charge -= dt; const f = _v1.set(Math.sin(a.yaw), 0, Math.cos(a.yaw)); a.want.set(f.x * 16, 0, f.z * 16); if (d < 2.2 && !a.ai.hitDone) { a.ai.hitDone = true; t.damage(18, a, { knock: 16, lift: 5 }); } return; }
    if (a.ai.t <= 0) { a.ai.t = rand(3, 5); if (d > 5) { a.ai.charge = 0.9; a.ai.hitDone = false; UI.toast('⚠ Kanca hücum ediyor!'); } else { a.st.slam = 1; setTimeout(() => { a.st.slam = 0; if (!a.alive) return; FX.ring(a.pos, '#b6ff3b', 6, 0.5); Combat.melee(a, 6, 16, { aoe: true, knock: 14, lift: 5 }); Cam.shake = 0.3; }, 400); } }
    if (d > 1.8) Ally.moveTo(a, t.pos, a.moveSpeed); else a.want.set(0, 0, 0);
    if (d < 2.3 && a.cd <= 0) { a.cd = 1.0; a.st.punch = 1; setTimeout(() => { if (a.alive && a.distTo(t) < 2.8) t.damage(a.dmg, a, { knock: 7 }); }, 150); }
  } },
  kor: { think(a, t, dt, d) {
    a.ai.t = (a.ai.t || 0) - dt;
    if (d > 9) Ally.moveTo(a, t.pos, a.moveSpeed); else if (d < 4) Ally.moveTo(a, _v1.set(a.pos.x * 2 - t.pos.x, 0, a.pos.z * 2 - t.pos.z), a.moveSpeed); else a.want.set(0, 0, 0);
    if (a.cd <= 0) { a.cd = 1.1; a.st.cast = 1; for (let k = -1; k <= 1; k++) { const from = _v1.set(a.pos.x, a.pos.y + 1.3, a.pos.z); const ang = Math.atan2(t.pos.x - a.pos.x, t.pos.z - a.pos.z) + k * 0.18; Projectiles.fire(a, 'fire', from, _v2.set(Math.sin(ang), (t.pos.y + 1 - from.y) / Math.max(1, d), Math.cos(ang)), 26, 12, { aoe: 2 }); } }
    if (a.ai.t <= 0) { a.ai.t = 5; FX.ring(a.pos, '#ff6a1f', 8, 0.7); setTimeout(() => { if (a.alive) Combat.melee(a, 8, 14, { aoe: true, knock: 12, lift: 4, color: '#ff6a1f' }); }, 300); for (let i = 0; i < 16; i++) FX.burst(_v1.set(a.pos.x, a.pos.y + 0.5, a.pos.z), '#ff6a1f', 2, 10, 0.25, 0.6, 0.2); }
    if (a.def.escapeAt && a.hp < a.maxHp * a.def.escapeAt) { a.invuln = true; a.hp = 1; a.alive = false; a.koT = 99; Bus.emit('bossEscape', a); }
  } },
  elite: null,
  mimar: { think(a, t, dt, d) {
    a.ai.t = (a.ai.t || 0) - dt; const ph = a.hp > a.maxHp * 0.66 ? 1 : a.hp > a.maxHp * 0.33 ? 2 : 3;
    if (ph !== a.ai.ph) { a.ai.ph = ph; if (ph > 1) { UI.toast(`⚠ Mimar evre ${ph}: çekirdek muhafızları!`, true); for (let i = 0; i < ph + 1; i++) Enemies.spawn(i % 2 ? 'drone' : 'elite', a.pos.x + rand(-8, 8), a.pos.z + rand(-8, 8), a.pos.y, { tag: Missions.tag() }); a.shield = 6; } }
    if (a.shield > 0) { a.shield -= dt; a.invuln = true; if (Math.random() < 0.3) FX.trail(_v1.set(a.pos.x + rand(-1.5, 1.5), a.pos.y + rand(0, 3), a.pos.z + rand(-1.5, 1.5)), '#ff2fd6', 0.25, 0.4); if (t.kind === 'player' && t.spinT > 0 && d < 4.5) { a.shield = 0; UI.toast('Kalkan kırıldı!'); } } else a.invuln = false;
    if (d > 8) Ally.moveTo(a, t.pos, a.moveSpeed); else if (d < 3) Ally.moveTo(a, _v1.set(a.pos.x * 2 - t.pos.x, 0, a.pos.z * 2 - t.pos.z), a.moveSpeed); else a.want.set(Math.cos(Game.t) * 3, 0, Math.sin(Game.t) * 3);
    if (a.cd <= 0) { a.cd = ph === 3 ? 0.7 : 1.1; a.st.cast = 1; const n = ph + 2; for (let k = 0; k < n; k++) { const from = _v1.set(a.pos.x, a.pos.y + 2.2, a.pos.z); const ang = Math.atan2(t.pos.x - a.pos.x, t.pos.z - a.pos.z) + (k - (n - 1) / 2) * 0.22; Projectiles.fire(a, 'shard', from, _v2.set(Math.sin(ang), (t.pos.y + 1 - from.y) / Math.max(2, d), Math.cos(ang)), 30, 13); } }
    if (a.ai.t <= 0) { a.ai.t = 6 - ph; a.st.slam = 1; setTimeout(() => { a.st.slam = 0; if (!a.alive) return; FX.ring(a.pos, '#ff2fd6', 10, 0.6); FX.ring(a.pos, '#c9a227', 6, 0.4); Combat.melee(a, 9, 18, { aoe: true, knock: 18, lift: 6, color: '#ff2fd6' }); Cam.shake = 0.4; }, 500); }
  } }
};

// ---------------------------------------------------------------- WantedSystem (ısı tabanlı aranma)
// Suçlar "ısı" (0..100) üretir; yıldızlar eşiklerden türetilir. Isı yalnızca tanık (polis görüş
// hattı ya da ihbar eden sivil) varsa eklenir. Polis görmüyorsa arama yarıçapı dışında hızlı,
// içinde yavaş soğur. isRecognizedNinja=true iken ısı oluşmaz, polis yalnızca suçlulara odaklanır.
const HEAT_STARS = [12, 30, 50, 70, 88];
const CRIME_W = { civAssault: 6, civKO: 10, copAssault: 12, copKO: 20, weapon: 4, carjack: 10, bump: 1.5, runover: 9, zone: 28 };
const Crime = {
  lastSeen: -999, decayT: 0, lastPos: null, pending: [], seen: false,
  starsOf(h) { let n = 0; for (const t of HEAT_STARS) if (h >= t) n++; return n; },
  get stars() { return S.wanted; },
  searchRadius() { return 40 + S.wanted * 25; },
  policeWitness(pos, r = 45) {
    for (const a of Game.actors) if (a.kind === 'police' && a.alive && dist2(a.pos.x, a.pos.z, pos.x, pos.z) < r * r && World.lineClear(a.pos.x, a.pos.z, pos.x, pos.z, a.pos.y + 1.5)) return a;
    return null;
  },
  civWitness(pos, r = 26) {
    for (const c of Population.civs) if (c.alive && c.ai.mode !== 'cower' && dist2(c.pos.x, c.pos.z, pos.x, pos.z) < r * r && World.lineClear(c.pos.x, c.pos.z, pos.x, pos.z, c.pos.y + 1.5)) return c;
    return null;
  },
  onPlayerHit(t, opt = {}) {
    if (S.isRecognizedNinja) { if (t.team === 'civ') changeRep(-0.5); return; }
    if (t.team !== 'civ' && t.team !== 'police') return;
    let w;
    if (opt.vehicle) w = opt.speed > 10 ? CRIME_W.runover : CRIME_W.bump;
    else w = t.team === 'police' ? CRIME_W.copAssault : CRIME_W.civAssault;
    if (t.hp <= 0) w += t.team === 'police' ? CRIME_W.copKO : CRIME_W.civKO;
    // aynı hedefe art arda vuruşlar daha az ısı ekler
    const now = Game.t; if (t._lastCrime && now - t._lastCrime < 1.5 && t.hp > 0) w *= 0.35; t._lastCrime = now;
    this.commit(w, t.team === 'police' ? 'polise saldırı' : opt.vehicle ? 'yayaya çarpma' : 'sivile saldırı');
  },
  weaponSeen() { this.commit(CRIME_W.weapon, 'silah kullanımı', true); },
  zone(name) { if (S.isRecognizedNinja) return; if (S.heat < HEAT_STARS[1]) this.commit(HEAT_STARS[1] + 2 - S.heat, name, true, true); },
  commit(amount, why, copOnly = false, force = false) {
    if (S.isRecognizedNinja) return;
    const p = Game.player.pos;
    const cop = force || this.policeWitness(p);
    if (cop) return this.addHeat(amount, why);
    if (copOnly) return;
    const civ = this.civWitness(p);
    if (!civ) return; // tanık yok → suç fark edilmedi
    const k = S.mask && S.outfit === 'ninja' ? 0.35 : S.mask ? 0.6 : 1;
    // sivil ihbarı birkaç saniye sonra gelir (tanık KO olursa ihbar düşer)
    this.pending.push({ t: Game.t + 3, amount: amount * 0.7 * k, why: why + ' (ihbar)', civ, pos: p.clone() });
  },
  addHeat(amount, why) {
    const before = S.wanted;
    S.heat = clamp((S.heat || 0) + amount, 0, 100); S.stats.crimes++;
    S.wanted = this.starsOf(S.heat);
    this.lastSeen = Game.t; this.lastPos = Game.player.pos.clone();
    if (S.wanted > before) { UI.toast('🚨 Aranma: ' + '★'.repeat(S.wanted) + ' (' + why + ')'); logEvent('wanted', RADIO.news.wanted); }
  },
  setStars(n) { if (S.isRecognizedNinja) return; S.heat = Math.max(S.heat || 0, HEAT_STARS[n - 1] + 3); S.wanted = this.starsOf(S.heat); this.lastSeen = Game.t; this.lastPos = Game.player.pos.clone(); },
  clear() { S.heat = 0; S.wanted = 0; this.pending = []; this.lastPos = null; for (const a of Game.actors.slice()) if (a.kind === 'police' && a.tag === 'wanted') a.remove(); Vehicles.clearPolice(); },
  update(dt) {
    if (S.isRecognizedNinja) { if (S.heat > 0 || S.wanted > 0) this.clear(); return; }
    // bekleyen ihbarlar
    for (let i = this.pending.length - 1; i >= 0; i--) { const r = this.pending[i]; if (Game.t >= r.t) { this.pending.splice(i, 1); if (r.civ.alive) this.addHeat(r.amount, r.why); } }
    if ((S.heat || 0) <= 0) { S.wanted = 0; return; }
    const p = Game.player.pos;
    this.seen = !!this.policeWitness(p, 38);
    if (this.seen) { this.lastSeen = Game.t; this.lastPos = p.clone(); }
    // soğuma: görüşten çıkınca kademeli; arama yarıçapı dışında daha hızlı
    const since = Game.t - this.lastSeen, R = this.searchRadius();
    const outside = !this.lastPos || dist2(p.x, p.z, this.lastPos.x, this.lastPos.z) > R * R;
    const hideK = (S.mask ? 1.35 : 1) * (S.outfit === 'ninja' && S.mask ? 1.15 : 1);
    if (!this.seen && since > (outside ? 3 : 7)) S.heat = Math.max(0, S.heat - dt * (outside ? 7 : 2.2) * hideK);
    const before = S.wanted; S.wanted = this.starsOf(S.heat);
    if (S.wanted < before) UI.toast(S.wanted ? 'Aranma düştü: ' + '★'.repeat(S.wanted) : '✅ Polis izini kaybetti');
    if (S.heat <= 0) { this.clear(); return; }
    if (S.wanted <= 0) return;
    // polis takviyesi arama bölgesine
    const want = Math.min(10, S.wanted * 2);
    const have = Game.actors.filter(a => a.kind === 'police' && a.alive && a.tag === 'wanted').length;
    if (have < want && Math.random() < dt * 0.7) {
      const c = this.lastPos || p, ang = rand(0, Math.PI * 2), r = rand(30, 50);
      const x = c.x + Math.cos(ang) * r, z = c.z + Math.sin(ang) * r;
      if (World.landAt(x, z) && !World.isMountain(x, z) && dist2(x, z, p.x, p.z) > 25 * 25) { const cop = Enemies.spawn('police', x, z, undefined, { tag: 'wanted' }); cop.ai.search = true; }
    }
    if (S.wanted >= 2) Vehicles.policeChase(dt);
    if (Math.random() < dt * 2) Sound.siren();
  }
};

// ---------------------------------------------------------------- Nüfus: siviller, devriye, çete
const Population = {
  civs: [], seed: 1, alarmT: 0,
  max() { return { low: 12, medium: 22, high: 32 }[Settings.quality] || 22; },
  update(dt) {
    const p = Game.player; if (!p) return;
    // despawn uzak siviller
    for (const c of this.civs.slice()) if (c.removed || dist2(c.pos.x, c.pos.z, p.pos.x, p.pos.z) > 130 * 130) { if (!c.removed) c.remove(); this.civs.splice(this.civs.indexOf(c), 1); }
    // spawn
    const curfew = Sky.curfew || S.flags.curfew;
    const dense = districtAt(p.pos.x, p.pos.z).id;
    const target = curfew ? 2 : Math.floor(this.max() * (dense === 'Neon_Boulevard' ? 1 : dense === 'Mountain' || dense === 'Secure_Island' ? 0.15 : 0.7) * (Sky.isNight() ? 0.8 : 1));
    if (this.civs.length < target && World.roadNodes.length) {
      for (let k = 0; k < 2; k++) {
        const ang = rand(0, Math.PI * 2), r = rand(28, 85);
        const x = p.pos.x + Math.cos(ang) * r, z = p.pos.z + Math.sin(ang) * r;
        const ni = World.nearestNode(x, z), n = World.roadNodes[ni]; if (!n || !n.n.length) continue;
        if (dist2(n.x, n.z, p.pos.x, p.pos.z) < 22 * 22 || dist2(n.x, n.z, p.pos.x, p.pos.z) > 110 * 110) continue;
        const side = Math.random() < 0.5 ? -1 : 1;
        const nx = World.roadNodes[pick(n.n)];
        const c = new Actor({ kind: 'civ', team: 'civ', cast: 'Civ', look: civilianLook(this.seed++), pos: _v1.set(n.x + side * 8.6, 0, n.z + side * 8.6), hp: 30, speed: 1.6 });
        c.ai = { mode: 'walk', from: ni, to: World.roadNodes.indexOf(nx), side, t: 0, sp: rand(1.3, 2.0) };
        c.pos.y = World.groundAt(c.pos.x, c.pos.z, 5);
        this.civs.push(c);
      }
    }
    // davranış
    const raining = Sky.rainAmt > 0.3;
    this.alarmT -= dt;
    for (const c of this.civs) {
      if (!c.alive) continue;
      const ai = c.ai; ai.t -= dt;
      if (ai.mode === 'flee') {
        if (ai.t <= 0) { ai.mode = 'walk'; c.poseOverride = null; }
        else { const dx = c.pos.x - ai.from2.x, dz = c.pos.z - ai.from2.z, l = Math.hypot(dx, dz) || 1; c.want.set(dx / l * 7.5, 0, dz / l * 7.5); c.yaw = Math.atan2(dx, dz); }
        continue;
      }
      if (ai.mode === 'cower') { c.want.set(0, 0, 0); c.poseOverride = 'cower'; if (ai.t <= 0) { ai.mode = 'walk'; c.poseOverride = null; } continue; }
      // yağmur kararı
      if (raining && ai.rainDecided === undefined) { ai.rainDecided = Math.random() < 0.55 ? 'umbrella' : 'shelter'; if (ai.rainDecided === 'shelter') { ai.shelter = World.nearestShelter(c.pos.x, c.pos.z); if (!ai.shelter) ai.rainDecided = 'umbrella'; } }
      if (!raining && ai.rainDecided !== undefined) { ai.rainDecided = undefined; c.umbrella = false; if (ai.mode === 'shelter') ai.mode = 'walk'; }
      c.umbrella = raining && ai.rainDecided === 'umbrella';
      if (raining && ai.rainDecided === 'shelter') {
        const [sx, sz] = ai.shelter; const d = Math.sqrt(dist2(sx, sz, c.pos.x, c.pos.z));
        if (d > 1.2) Ally.moveTo(c, _v1.set(sx + (c.ai.side * 0.8), 0, sz), 4.5); else { c.want.set(0, 0, 0); ai.mode = 'shelter'; c.yaw = angLerp(c.yaw, 0, 0.1); }
        continue;
      }
      // kaldırım boyunca yürüyüş
      const A = World.roadNodes[ai.from], B = World.roadNodes[ai.to]; if (!A || !B) continue;
      const off = ai.side * 8.6;
      const tx = B.x + (A.z === B.z ? 0 : off), tz = B.z + (A.x === B.x ? 0 : off);
      const d = Math.sqrt(dist2(tx, tz, c.pos.x, c.pos.z));
      if (d < 1.5) { const nn = B.n.filter(i => i !== ai.from); ai.from = ai.to; ai.to = nn.length ? pick(nn) : ai.from; }
      else Ally.moveTo(c, _v1.set(tx, 0, tz), ai.sp * (raining ? 1.4 : 1));
    }
    this.ambient(dt);
  },
  alarm(pos, r) {
    if (this.alarmT > 0) return; this.alarmT = 0.5;
    for (const c of this.civs) if (c.alive && dist2(c.pos.x, c.pos.z, pos.x, pos.z) < r * r) this.panic(c, pos);
  },
  panic(c, from) {
    if (c.ai.mode === 'flee' || c.ai.mode === 'cower') return;
    if (Math.random() < 0.2) { c.ai.mode = 'cower'; c.ai.t = rand(3, 6); }
    else { c.ai.mode = 'flee'; c.ai.t = rand(5, 9); c.ai.from2 = from.clone ? from.clone() : new THREE.Vector3(from.x, 0, from.z); c.umbrella = false; }
  },
  patrol(a, dt) {
    a.ai.pt = (a.ai.pt || 0) - dt;
    if (a.ai.pt <= 0 || !a.ai.pp) { a.ai.pt = rand(5, 10); a.ai.pp = new THREE.Vector3(a.pos.x + rand(-20, 20), 0, a.pos.z + rand(-20, 20)); }
    if (dist2(a.ai.pp.x, a.ai.pp.z, a.pos.x, a.pos.z) > 4) Ally.moveTo(a, a.ai.pp, 1.8); else a.want.set(0, 0, 0);
    a.umbrella = false;
  },
  ambT: 0,
  ambient(dt) {
    this.ambT -= dt; if (this.ambT > 0) return; this.ambT = 6;
    const p = Game.player.pos, dist = districtAt(p.x, p.z).id;
    // devriye polisi (tanınmış ninja sonrası çetelerle savaşır)
    const cops = Game.actors.filter(a => a.kind === 'police' && a.tag === 'patrol');
    for (const c of cops) if (dist2(c.pos.x, c.pos.z, p.x, p.z) > 140 * 140) c.remove();
    if (cops.length < 2 && !Missions.active && S.wanted <= 0 && dist !== 'Mountain' && dist !== 'Secure_Island') {
      const ang = rand(0, 6.28), r = rand(40, 70), x = p.x + Math.cos(ang) * r, z = p.z + Math.sin(ang) * r;
      if (World.landAt(x, z) && !World.isMountain(x, z)) Enemies.spawn('police', x, z, undefined, { tag: 'patrol', aggro: false });
    }
    // ortam çete grupları (liman/çarşı geceleri, kartel devriyeleri)
    const gangs = Game.actors.filter(a => a.tag === 'ambientGang');
    for (const g of gangs) if (dist2(g.pos.x, g.pos.z, p.x, p.z) > 150 * 150) g.remove();
    if (!Missions.active && gangs.filter(g => g.alive).length === 0 && (dist === 'Harbor_District' || dist === 'Old_Bazaar' || (dist === 'Neon_Boulevard' && Sky.isNight())) && Math.random() < 0.35 && !S.flags.curfew) {
      const ang = rand(0, 6.28), r = rand(45, 70), x = p.x + Math.cos(ang) * r, z = p.z + Math.sin(ang) * r;
      if (World.landAt(x, z) && !World.isMountain(x, z)) for (let i = 0; i < randi(2, 3); i++) Enemies.spawn(i ? 'gang' : 'gangGun', x + rand(-3, 3), z + rand(-3, 3), undefined, { tag: 'ambientGang', aggro: false });
    }
    // ada yasak bölge
    if (p.x > 462 && !S.isRecognizedNinja && !(Missions.active && Missions.active.id === 'm34')) Crime.zone('yasak bölge ihlali');
  },
  clearHostiles() { for (const a of Game.actors.slice()) if ((a.kind === 'enemy' && !a.persistent) || (a.kind === 'police' && a.tag === 'wanted')) a.remove(); },
  civTalk(c) {
    const lines = S.isRecognizedNinja
      ? ['Siz o ninjalardan değil misiniz? Teşekkürler!', 'Kızım posterinizi astı odasına!', 'Polis artık sizinle çalışıyormuş, doğru mu?']
      : S.wanted > 0 ? ['Uzak dur benden!', 'Polis seni arıyor, biliyor musun?'] : Sky.rainAmt > 0.3 ? ['Bu yağmur hiç dinmeyecek mi?', 'Şemsiyemi evde unuttum, of.'] : ['Neon Bulvar bu gece çok kalabalık.', 'Limanda bir şeyler dönüyor diyorlar.', 'Smoothie dükkânının ananası yine dönüyor!', 'Kartelciler çarşıda haraç topluyor…'];
    c.want.set(0, 0, 0); c.face(Game.player.pos.x, Game.player.pos.z);
    UI.dialog([{ who: 'Vatandaş', text: pick(lines) }, { choice: [
      { text: 'Kartel hakkında bir şey duydun mu?', reply: { who: 'Vatandaş', text: pick(['Liman deposunda gece kamyonlar görüyorum.', 'Mor ceketliler… onlardan uzak dur.', 'Kule\'de çalışan kuzenim garip ışıklar görmüş.']) } },
      { text: 'İyi geceler.', reply: { who: 'Vatandaş', text: 'Sana da. Dikkatli ol.' } }
    ] }]);
  }
};

// ---------------------------------------------------------------- Toplanabilirler
const Pickups = {
  list: [],
  spawn(x, y, z, opt) {
    const m = new THREE.Mesh(opt.geo || Geo.box, Mat.plastic(opt.color || '#ffd23b', { em: opt.color || '#ffd23b', emi: 1.2 }));
    m.scale.setScalar(opt.size || 0.6); m.position.set(x, y + 0.8, z); Game.scene.add(m);
    const o = Object.assign({ m, x, y, z, r: opt.r || 1.6 }, opt); this.list.push(o); return o;
  },
  spawnMoney(pos, amt) { this.spawn(pos.x + rand(-0.5, 0.5), pos.y, pos.z + rand(-0.5, 0.5), { color: '#b6ff3b', size: 0.35, r: 2.4, money: amt, life: 30 }); },
  remove(o) { Game.scene.remove(o.m); const i = this.list.indexOf(o); if (i >= 0) this.list.splice(i, 1); },
  clearTag(tag) { for (const o of this.list.slice()) if (o.tag === tag) this.remove(o); },
  update(dt) {
    const p = Game.player; if (!p) return;
    for (const o of this.list.slice()) {
      o.m.rotation.y += dt * 2; o.m.position.y = o.y + 0.8 + Math.sin(Game.t * 3 + o.x) * 0.2;
      if (o.life !== undefined && (o.life -= dt) <= 0) { this.remove(o); continue; }
      if (Math.abs(p.pos.y - o.y) < 3 && dist2(p.pos.x, p.pos.z, o.x, o.z) < o.r * o.r) {
        if (o.money) { changeMoney(o.money); UI.toast('+' + o.money + ' ₺'); }
        Sound.ok(); FX.burst(o.m.position, o.color || '#ffd23b', 10, 4);
        this.remove(o); o.onPick && o.onPick(o);
      }
    }
  }
};

// ---------------------------------------------------------------- Metal Ejderhası
const Dragon = {
  d: null,
  build() {
    const segs = [], g = new THREE.Group(); Game.scene.add(g);
    const mm = Mat.getMetalSkin(), acc = Mat.neon('#ff8a1f');
    const head = new THREE.Group(); g.add(head);
    const hb = new THREE.Mesh(Geo.box, mm); hb.scale.set(1.6, 1.1, 2.4); head.add(hb);
    const jaw = new THREE.Mesh(Geo.box, mm); jaw.scale.set(1.3, 0.35, 1.6); jaw.position.set(0, -0.6, 0.6); head.add(jaw);
    for (const s of [-1, 1]) { const horn = new THREE.Mesh(Geo.cone, mm); horn.scale.set(0.3, 1.2, 0.3); horn.position.set(s * 0.6, 0.9, -0.6); horn.rotation.x = -0.6; head.add(horn); const eye = new THREE.Mesh(Geo.box, acc); eye.scale.set(0.25, 0.2, 0.1); eye.position.set(s * 0.5, 0.25, 1.2); head.add(eye); }
    for (let i = 0; i < 18; i++) {
      const s = new THREE.Group(); const k = 1 - i / 22;
      const b = new THREE.Mesh(Geo.box, mm); b.scale.set(1.3 * k, 1.1 * k, 1.5); s.add(b);
      const fin = new THREE.Mesh(Geo.cone, i % 2 ? acc : mm); fin.scale.set(0.3, 0.8 * k, 0.6); fin.position.y = 0.8 * k; s.add(fin);
      if (i === 3 || i === 4) for (const sd of [-1, 1]) { const w = new THREE.Mesh(Geo.box, mm); w.scale.set(5, 0.12, 1.6); w.position.x = sd * 2.8; w.userData.wing = sd; s.add(w); }
      g.add(s); segs.push(s);
    }
    g.traverse(n => { if (n.isMesh) n.castShadow = true; });
    return { g, head, segs, trail: [], yaw: 0, pitch: 0, speed: 26 };
  },
  toggle() {
    const p = Game.player;
    if (p.dragon) return this.dismount();
    if (!S.abilities.dragon) { UI.toast('Metal Ejderhası henüz açılmadı (Görev 3.3)'); return; }
    if (Player.energy < 40) { UI.toast('Ejderha için 40 enerji gerek'); return; }
    if (p.vehicle) return;
    this.d ||= this.build(); const d = this.d; d.g.visible = true;
    d.head.position.set(p.pos.x, p.pos.y + 4, p.pos.z); d.yaw = p.yaw; d.pitch = 0.2;
    d.trail = []; for (let i = 0; i < 120; i++) d.trail.push(d.head.position.clone().addScaledVector(_v1.set(-Math.sin(d.yaw), 0, -Math.cos(d.yaw)), i * 0.4));
    p.dragon = d; Player.metalOff(); Player.energy -= 25;
    FX.ring(p.pos, '#e8f0ff', 10, 0.7); FX.burst(d.head.position, '#ff8a1f', 30, 10); Cam.shake = 0.5; Sound.slam(); UI.toast('🐉 Metal Ejderhası!'); Bus.emit('ability', 'dragon');
  },
  dismount() {
    const p = Game.player, d = p.dragon; if (!d) return;
    p.dragon = null; d.g.visible = false; p.vel.set(0, 2, 0); p.pos.copy(d.head.position); p.pos.y -= 1;
    FX.burst(d.head.position, '#e8f0ff', 20, 8);
  },
  control(dt, ctl) {
    const p = Game.player, d = p.dragon;
    Player.energy -= dt * 3.2; if (Player.energy <= 0) { Player.energy = 0; this.dismount(); UI.toast('Enerji bitti — ejderha dağıldı'); return; }
    const mx = ctl ? Input.move.x : 0, my = ctl ? Input.move.y : 0;
    d.yaw = angLerp(d.yaw, Cam.yaw + Math.PI, dt * 2.5) - mx * dt * 1.6;
    const up = (ctl && Input.isDown('jump') ? 1 : 0) - (ctl && (Input.isDown('sprint') || Input.isDown('descend') || Input.isDown('dash')) ? 1 : 0);
    d.pitch = lerp(d.pitch, up * 0.7, dt * 3);
    const sp = d.speed * (0.45 + Math.max(0, my) * 0.9) + (my < 0 ? -6 : 0);
    const f = _v1.set(Math.sin(d.yaw) * Math.cos(d.pitch), Math.sin(d.pitch), Math.cos(d.yaw) * Math.cos(d.pitch));
    d.head.position.addScaledVector(f, sp * dt);
    const g = World.groundAt(d.head.position.x, d.head.position.z, 999); if (d.head.position.y < g + 2.5) d.head.position.y = g + 2.5;
    d.head.position.y = Math.min(d.head.position.y, 260);
    d.head.rotation.set(-d.pitch, d.yaw, 0);
    d.trail.unshift(d.head.position.clone()); d.trail.length = 120;
    d.segs.forEach((s, i) => {
      const a = d.trail[Math.min(119, (i + 1) * 5)], b = d.trail[Math.min(119, (i + 1) * 5 + 2)];
      s.position.copy(a); s.position.y += Math.sin(Game.t * 4 - i * 0.5) * 0.3; s.lookAt(_v2.copy(a).multiplyScalar(2).sub(b));
      s.children.forEach(c => { if (c.userData.wing) c.rotation.z = Math.sin(Game.t * 5) * 0.4 * c.userData.wing; });
    });
    // oyuncu ejderha başının arkasında
    const seat = d.segs[1].position; p.pos.copy(seat); p.pos.y += 0.6; p.yaw = d.yaw; p.st.anim = 'ride'; p.poseOverride = 'ride'; p.onGround = true;
    p.fig.root.position.copy(p.pos); p.fig.root.rotation.set(0, p.yaw, 0); p.fig.animate(dt, p.st); p.poseOverride = null;
    if (Math.random() < 0.5) FX.trail(d.segs[17].position, '#ff8a1f', 0.25, 0.6);
    if (ctl && Input.isDown('attack') && p.cd <= 0) { p.cd = 0.28; const from = _v1.copy(d.head.position).addScaledVector(f, 2); Projectiles.fire(p, 'shard', from, f, 55, 20, { aoe: 2.5, ability: 'dragon' }); Sound.shoot(); }
    if (ctl && Input.pressed('heavy') && Player.energy > 15) { Player.energy -= 15; FX.ring(_v1.set(d.head.position.x, g, d.head.position.z), '#e8f0ff', 14, 0.6); const fake = Object.assign(Object.create(Actor.prototype), { pos: _v2.set(d.head.position.x, g, d.head.position.z), yaw: 0, kind: 'player', team: 'player', alive: true }); Combat.melee(fake, 12, 30, { aoe: true, knock: 18, lift: 8, ability: 'dragon', vehicles: 12 }); Cam.shake = 0.5; }
    if (ctl && Input.pressed('dragon')) this.dismount();
    if (ctl && Input.pressed('pause')) UI.pause();
    if (ctl && Input.pressed('phone')) UI.phone();
  }
};
