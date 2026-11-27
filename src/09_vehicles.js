// ============================================================================
//  ARAÇLAR — OnFoot <-> InVehicle, arcade sürüş fiziği (kayma/drift, ıslak
//  zemin), modifiye, trafik havuzu, polis takibi, yarış/kovalama AI, radyo
// ============================================================================
let VEH_UID = 1;
class Vehicle {
  constructor(type, x, z, yaw = 0, opt = {}) {
    this.type = type; this.def = VEHICLES[type] || VEHICLES.street;
    this.color = opt.color || this.def.color; this.mods = Object.assign({ speed: 0, armor: 0, grip: 0 }, opt.mods || {});
    this.uid = opt.uid || ('v' + (VEH_UID++)); this.owned = !!opt.owned; this.temp = !!opt.temp; this.tag = opt.tag || null;
    this.pos = new THREE.Vector3(x, World.surfaceAt(x, z), z); this.yaw = yaw; this.speed = 0; this.vel = new THREE.Vector3(); this.steer = 0;
    this.maxHp = this.hp = this.def.hp * (1 + this.mods.armor * 0.4); this.driver = null; this.passengers = []; this.wreck = false;
    this.ai = opt.ai || null; this.police = type === 'police'; this.npcDriver = !!opt.npcDriver;
    this.mesh = this.build(); Game.scene.add(this.mesh); Game.vehicles.push(this);
  }
  build() {
    this.bodyMeshes = [];
    const g = new THREE.Group(), d = this.def, body = Mat.plastic(this.color, { rough: 0.22 }), dark = Mat.plastic('#141418'), glass = Mat.plastic('#1a2a4a', { rough: 0.05, metal: 0.4 });
    const tpl = AssetManager.instance('veh_' + this.type) || (this.type === 'sport' && Settings.modelMode === 'library' ? AssetManager.instance('lib_car') : null);
    if (tpl) tpl.traverse(n => { if (n.isMesh && /body|paint|car_?body/i.test(n.name)) { n.material = new THREE.MeshPhysicalMaterial({ color: this.color, metalness: 0.6, roughness: 0.25, clearcoat: 1, clearcoatRoughness: 0.05 }); this.bodyMeshes.push(n); } });
    const B = (m, w, h, l, x, y, z) => { const b = new THREE.Mesh(Geo.rbox, m); b.scale.set(w, h, l); b.position.set(x, y, z); b.castShadow = true; b.receiveShadow = true; g.add(b); return b; };
    if (tpl) { g.add(tpl); }
    else if (d.kind === 'bike') {
      this.bodyMeshes.push(B(body, 0.5, 0.45, 1.6, 0, 0.75, 0), B(body, 0.4, 0.3, 0.6, 0, 1.05, 0.55), B(dark, 0.5, 0.25, 0.8, 0, 1.0, -0.3));
      B(Mat.plastic('#c9d3df', { metal: 0.8 }), 0.08, 0.7, 0.08, 0, 1.2, 0.8); B(Mat.plastic('#c9d3df', { metal: 0.8 }), 0.9, 0.06, 0.06, 0, 1.55, 0.8);
      B(Mat.neon('#fff6d0'), 0.25, 0.18, 0.05, 0, 1.0, 0.96); B(Mat.neon('#ff3b3b'), 0.25, 0.1, 0.05, 0, 0.95, -0.72);
    } else {
      const L = d.len, W = d.wid, H = d.h;
      this.bodyMeshes.push(B(body, W, H * 0.45, L, 0, 0.55 + H * 0.22, 0));
      if (d.kind === 'truck') { this.bodyMeshes.push(B(body, W, H * 0.6, L * 0.32, 0, 0.6 + H * 0.65, L * 0.32)); B(Mat.plastic(this.type === 'van' ? this.color : '#d8d0e8'), W, H * 0.75, L * 0.62, 0, 0.6 + H * 0.6, -L * 0.18); B(glass, W * 0.9, H * 0.3, 0.05, 0, 0.7 + H * 0.75, L * 0.48 + 0.01); }
      else { this.bodyMeshes.push(B(body, W * 0.85, H * 0.4, L * 0.5, 0, 0.55 + H * 0.62, -L * 0.05)); B(glass, W * 0.8, H * 0.32, 0.05, 0, 0.6 + H * 0.62, L * 0.2); B(glass, W * 0.87, H * 0.28, L * 0.42, 0, 0.58 + H * 0.62, -L * 0.05); }
      for (const s of [-1, 1]) { B(Mat.neon('#fff6d0'), 0.4, 0.18, 0.05, s * W * 0.32, 0.65 + H * 0.2, L / 2 + 0.01); B(Mat.neon('#ff3b3b'), 0.4, 0.14, 0.05, s * W * 0.32, 0.65 + H * 0.2, -L / 2 - 0.01); }
      const under = B(Mat.neon(this.type === 'sport' ? '#ff2fd6' : this.type === 'police' ? '#3bb0ff' : '#20f0ff'), W * 0.9, 0.04, L * 0.8, 0, 0.18, 0); under.castShadow = false; this.underglow = under;
      if (this.police) { this.sirenR = B(Mat.neon('#ff3b3b'), 0.5, 0.15, 0.25, -0.3, 0.6 + H, -0.1); this.sirenB = B(Mat.neon('#3bb0ff'), 0.5, 0.15, 0.25, 0.3, 0.6 + H, -0.1); B(Mat.plastic('#1f3a7a'), W + 0.02, 0.25, L * 0.4, 0, 0.6 + H * 0.25, 0); }
      if (this.npcDriver) { this.driverMeshes = [B(Mat.plastic(pick(CIV_PALETTE.tops)), 0.5, 0.45, 0.4, W * 0.2, 0.7 + H * 0.55, 0.1), B(Mat.plastic(pick(CIV_PALETTE.skins)), 0.35, 0.35, 0.35, W * 0.2, 1.05 + H * 0.55, 0.1)]; }
    }
    this.wheels = [];
    const L = d.len, W = d.wid, wr = d.kind === 'truck' ? 0.55 : d.kind === 'bike' ? 0.4 : 0.42;
    const wpos = d.kind === 'bike' ? [[0, 0.75], [0, -0.75]] : [[W / 2, L * 0.33], [-W / 2, L * 0.33], [W / 2, -L * 0.33], [-W / 2, -L * 0.33]];
    if (!tpl) for (const [x, z] of wpos) { const w = new THREE.Mesh(Geo.cyl, dark); w.scale.set(wr * 2, d.kind === 'bike' ? 0.18 : 0.32, wr * 2); w.rotation.z = Math.PI / 2; w.position.set(x, wr, z); w.castShadow = true; g.add(w); this.wheels.push(w); }
    g.position.copy(this.pos); g.rotation.y = this.yaw;
    return g;
  }
  repaint(c) { this.color = c; const m = Mat.plastic(c, { rough: 0.22 }); for (const b of this.bodyMeshes) { if (b.material.clearcoat === 1) b.material.color.set(c); else b.material = m; } }
  maxSpeed() { return this.def.max * (1 + 0.12 * this.mods.speed); }
  grip() { return this.def.grip * (1 + 0.15 * this.mods.grip) * (1 - Sky.wet * 0.25); }
  remove() { Game.scene.remove(this.mesh); const i = Game.vehicles.indexOf(this); if (i >= 0) Game.vehicles.splice(i, 1); this.removed = true; }
  damage(n) {
    if (this.wreck) return; this.hp -= n;
    if (this.hp <= 0) {
      this.wreck = true; this.wreckT = 0; FX.burst(_v1.set(this.pos.x, this.pos.y + 1, this.pos.z), '#ff8a1f', 40, 12, 0.35, 1.0); FX.ring(this.pos, '#ff6a1f', 9, 0.6); Cam.shake = 0.5; Sound.slam();
      for (const b of this.bodyMeshes) b.material = Mat.plastic('#222228', { rough: 0.9 });
      const fake = Object.assign(Object.create(Actor.prototype), { pos: this.pos.clone(), yaw: 0, kind: this.driver?.kind || 'enemy', team: this.driver?.team || 'gang', alive: true });
      Combat.melee(fake, 6, 30, { aoe: true, knock: 16, lift: 7 }); Combat.danger(this.pos, 40);
      for (const o of [this.driver, ...this.passengers]) if (o) Vehicles.exit(o, false);
    }
  }
  // Sürüş girişi: throttle 0..1, brake 0..1, steer -1..1, hb bool
  physics(dt, th, br, st, hb) {
    if (this.wreck) { th = br = st = 0; }
    const d = this.def, max = this.maxSpeed(), acc = d.acc * (1 + 0.1 * this.mods.speed);
    if (th > 0) this.speed += th * acc * dt * (this.speed < 0 ? 2.5 : 1);
    if (br > 0) this.speed -= br * (this.speed > 0.5 ? acc * 1.8 : acc * 0.7) * dt;
    this.speed -= this.speed * (0.25 + (hb ? 1.2 : 0)) * dt;
    if (th <= 0 && br <= 0) this.speed -= Math.sign(this.speed) * Math.min(Math.abs(this.speed), 3 * dt);
    this.speed = clamp(this.speed, -max * 0.3, max);
    this.steer = lerp(this.steer, st, Math.min(1, dt * 6));
    const turn = this.steer * clamp(this.speed / 7, -1, 1) * (d.kind === 'bike' ? 2.4 : d.kind === 'truck' ? 1.2 : 1.8) * (1 - clamp(Math.abs(this.speed) / max, 0, 1) * 0.35) * (hb ? 1.5 : 1);
    this.yaw += turn * dt;
    const fwd = _v1.set(Math.sin(this.yaw), 0, Math.cos(this.yaw));
    const target = _v2.copy(fwd).multiplyScalar(this.speed);
    const g = this.grip() * (hb ? 0.25 : 1);
    this.vel.lerp(target, Math.min(1, dt * g * 2.2));
    this.drift = this.vel.length() > 6 ? 1 - Math.abs(this.vel.clone().normalize().dot(fwd)) : 0;
    // hareket + çarpışma (ön/arka iki daire)
    const prev = this.pos.clone();
    this.pos.addScaledVector(this.vel, dt);
    const half = Math.max(0, d.len / 2 - d.wid / 2), r = d.wid / 2 + 0.15;
    let hit = false; const delta = _v3.set(0, 0, 0);
    for (const s of [1, -1]) { const pt = new THREE.Vector3(this.pos.x + fwd.x * half * s, this.pos.y, this.pos.z + fwd.z * half * s); const bx = pt.x, bz = pt.z; if (World.collide(pt, r, d.h)) { hit = true; delta.x += pt.x - bx; delta.z += pt.z - bz; } }
    if (hit) { this.pos.x += delta.x * 0.6; this.pos.z += delta.z * 0.6; const imp = Math.abs(this.speed); if (imp > 8) { this.damage(imp * 0.6); Cam.shake = Math.min(0.4, imp * 0.01); Sound.beep(90, 0.15, 'square', 0.1); } this.speed *= 0.45; this.vel.multiplyScalar(0.45); }
    // su / kara sınırı
    const base = World.baseHeight(this.pos.x, this.pos.z), gy = World.groundAt(this.pos.x, this.pos.z, this.pos.y + 1.2);
    if (base < WATER_Y && gy < WATER_Y) { this.pos.copy(prev); this.speed *= -0.3; this.vel.multiplyScalar(-0.3); }
    else { this.pos.y = lerp(this.pos.y, gy, Math.min(1, dt * 12)); if (gy > this.pos.y + 1.5) this.pos.y = gy; }
    // araç-araç
    for (const o of Game.vehicles) {
      if (o === this || o.removed) continue;
      const dx = this.pos.x - o.pos.x, dz = this.pos.z - o.pos.z, rr = (this.def.wid + o.def.wid) * 0.6 + 0.5, d2 = dx * dx + dz * dz;
      if (d2 < rr * rr && d2 > 1e-4) { const dd = Math.sqrt(d2), k = (rr - dd) / dd * 0.5; this.pos.x += dx * k; this.pos.z += dz * k; o.pos.x -= dx * k; o.pos.z -= dz * k; const rel = Math.abs(this.speed - o.speed); if (rel > 10) { this.damage(rel * 0.3); o.damage(rel * 0.3); } this.speed *= 0.8; o.speed *= 0.8; }
    }
    // yaya çarpması
    if (Math.abs(this.speed) > 5) for (const a of Game.actors) {
      if (!a.alive || a.vehicle || a.hidden || a === this.driver) continue;
      if (Math.abs(a.pos.y - this.pos.y) > 2) continue;
      const dx = a.pos.x - this.pos.x, dz = a.pos.z - this.pos.z;
      const lf = dx * fwd.x + dz * fwd.z, lr = dx * fwd.z - dz * fwd.x;
      if (Math.abs(lf) < d.len / 2 + 0.4 && Math.abs(lr) < d.wid / 2 + 0.4) {
        if (this.driver && SIDE[this.driver.team] === 'hero' && SIDE[a.team] === 'hero') continue;
        a.damage(Math.abs(this.speed) * 1.6, this.driver || null, { knock: Math.abs(this.speed) * 0.8, lift: 5, vehicle: true, speed: Math.abs(this.speed) });
        if (this.driver?.kind === 'player') Combat.danger(a.pos, 25);
        this.speed *= 0.85;
      }
    }
    this.syncMesh(dt, turn);
  }
  syncMesh(dt, turn = 0) {
    const m = this.mesh; m.position.copy(this.pos); m.rotation.y = this.yaw;
    m.rotation.z = lerp(m.rotation.z, this.def.kind === 'bike' ? -turn * 0.25 : -turn * 0.03, Math.min(1, dt * 6));
    for (const w of this.wheels) w.rotation.x += this.speed * dt * 2;
    if (this.wheels[0] && this.def.kind !== 'bike') { this.wheels[0].rotation.y = this.steer * 0.4; this.wheels[1].rotation.y = this.steer * 0.4; }
    if (this.police && (this.siren || this.driver?.kind === 'enemy' || this.ai?.mode === 'chase')) { const f = Math.sin(Game.t * 14) > 0; this.sirenR.visible = f; this.sirenB.visible = !f; }
    if (this.underglow) this.underglow.visible = SHARED_UNI.uNight.value > 0.4;
    if (this.drift > 0.25 && Math.random() < 0.6) FX.trail(_v1.set(this.pos.x - Math.sin(this.yaw) * this.def.len * 0.4, this.pos.y + 0.2, this.pos.z - Math.cos(this.yaw) * this.def.len * 0.4), Sky.wet > 0.3 ? '#a8c8ff' : '#cccccc', 0.35, 0.6);
  }
}

const Vehicles = {
  traffic: [], policeCars: [], radioIdx: 0, radioT: 0, radioLine: '',
  spawn(type, x, z, yaw, opt) { return new Vehicle(type, x, z, yaw, opt); },
  nearest(p, r) { let b = null, bd = r * r; for (const v of Game.vehicles) { if (v.wreck || v.removed) continue; const d = dist2(v.pos.x, v.pos.z, p.x, p.z); if (d < bd && Math.abs(v.pos.y - p.y) < 3) { bd = d; b = v; } } return b; },
  enter(a, v) {
    if (v.driver && v.driver !== a) {
      // araç gaspı
      const dr = v.driver; this.exit(dr, false);
      if (dr.kind === 'enemy' || dr.kind === 'police') dr.damage(5, a, { noCrime: dr.kind === 'enemy' });
    }
    if (v.npcDriver) { v.npcDriver = false; const c = new Actor({ kind: 'civ', team: 'civ', cast: 'Civ', look: civilianLook(randi(1, 99999)), pos: _v1.set(v.pos.x + Math.cos(v.yaw) * 2, v.pos.y, v.pos.z - Math.sin(v.yaw) * 2), hp: 30 }); c.ai = { mode: 'walk', from: 0, to: 0, side: 1, t: 0, sp: 1.5 }; Population.civs.push(c); Population.panic(c, v.pos); if (!S.isRecognizedNinja) Crime.commit(CRIME_W.carjack, 'araç gaspı'); (v.driverMeshes || []).forEach(m => m.visible = false); v.ai = null; const ti = this.traffic.indexOf(v); if (ti >= 0) this.traffic.splice(ti, 1); }
    if (v.ai && v.ai.mode !== 'player') { v.ai = null; const ti = this.traffic.indexOf(v); if (ti >= 0) this.traffic.splice(ti, 1); }
    a.vehicle = v; v.driver = a; a.want.set(0, 0, 0); a.vel.set(0, 0, 0);
    a.hidden = v.def.kind !== 'bike'; a.st.anim = v.def.kind === 'bike' ? 'ride' : 'drive';
    if (a.kind === 'player') { Player.metalOff(); a.spinT = 0; Bus.emit('enterVehicle', v); this.radioT = 2; UI.toast('🚗 ' + v.def.name + ' · ' + Input.hint('vehicle') + ' in · ' + 'Radyo: [N]'); }
  },
  board(a, v) { if (v.passengers.length >= (v.def.kind === 'bike' ? 1 : 3)) return; a.vehicle = v; v.passengers.push(a); a.hidden = v.def.kind !== 'bike'; a.st.anim = 'ride'; },
  exit(a, silent) {
    const v = a.vehicle; if (!v) return;
    if (v.driver === a) v.driver = null; else v.passengers.splice(v.passengers.indexOf(a), 1);
    a.vehicle = null; a.hidden = false;
    const side = v.passengers.length % 2 ? 1 : -1;
    a.pos.set(v.pos.x + Math.cos(v.yaw) * (v.def.wid / 2 + 1) * side, v.pos.y + 0.3, v.pos.z - Math.sin(v.yaw) * (v.def.wid / 2 + 1) * side);
    World.collide(a.pos, 0.5, 1.8); a.pos.y = World.groundAt(a.pos.x, a.pos.z, a.pos.y + 1);
    a.yaw = v.yaw; a.vel.set(0, 0, 0);
    if (a.kind === 'player') { Bus.emit('exitVehicle', v); $('radio').textContent = ''; $('speedo').textContent = ''; }
  },
  drive(v, dt, ctl) {
    const p = Game.player;
    p.pos.copy(v.pos); p.pos.y += v.def.kind === 'bike' ? 0.35 : 0.2; p.yaw = v.yaw;
    p.st.anim = v.def.kind === 'bike' ? 'ride' : 'drive'; p.st.speed = 0;
    for (const ps of v.passengers) { ps.pos.set(v.pos.x - Math.sin(v.yaw) * 0.6, v.pos.y + 0.4, v.pos.z - Math.cos(v.yaw) * 0.6); ps.yaw = v.yaw; ps.st.anim = 'ride'; }
    const th = ctl ? Input.throttle : 0, br = ctl ? Input.brake : 0, st = ctl ? -Input.move.x : 0;
    v.physics(dt, th, br, st, ctl && Input.isDown('handbrake'));
    if (ctl && Input.pressed('horn')) { Sound.horn(); Combat.danger(v.pos, 15); }
    if (ctl && Input.pressed('radio')) this.nextStation();
    if (ctl && Input.pressed('phone')) UI.phone();
    if (ctl && Input.pressed('pause')) UI.pause();
    if (ctl && Input.pressed('wheel')) UI.toast('Araçtayken silah değiştirilemez');
    $('speedo').textContent = Math.round(Math.abs(v.speed) * 3.6) + ' km/s';
    S.stats.distance += Math.abs(v.speed) * dt;
    this.radio(dt);
  },
  impulse(pos, r, force) {
    for (const v of Game.vehicles) { if (v.removed) continue; const dx = v.pos.x - pos.x, dz = v.pos.z - pos.z, d = Math.hypot(dx, dz); if (d < r && d > 0.01) { v.vel.x += dx / d * force * 1.5; v.vel.z += dz / d * force * 1.5; v.damage(force * 1.5); v.mesh.rotation.z = rand(-0.3, 0.3); } }
  },
  // -------------------------------------------------------- trafik havuzu
  updateTraffic(dt) {
    const p = Game.player.pos, maxN = { low: 5, medium: 9, high: 13 }[Settings.quality] || 9;
    for (const v of this.traffic.slice()) if (v.removed || dist2(v.pos.x, v.pos.z, p.x, p.z) > 170 * 170) { v.remove(); this.traffic.splice(this.traffic.indexOf(v), 1); }
    const curfew = S.flags.curfew;
    if (this.traffic.length < (curfew ? 1 : maxN) && World.roadEdges.length && Math.random() < dt * 3) {
      const e = pick(World.roadEdges); const [ai, bi] = Math.random() < 0.5 ? e : [e[1], e[0]];
      const A = World.roadNodes[ai], B = World.roadNodes[bi];
      const d = Math.sqrt(dist2(A.x, A.z, p.x, p.z));
      if (d > 50 && d < 150) {
        const yaw = Math.atan2(B.x - A.x, B.z - A.z);
        const off = 3.5, x = A.x + Math.cos(yaw) * -off, z = A.z - Math.sin(yaw) * -off;
        const type = Math.random() < 0.12 ? 'heavy' : Math.random() < 0.2 ? 'sport' : Math.random() < 0.15 ? 'motor' : Math.random() < 0.1 && S.isRecognizedNinja ? 'police' : 'street';
        const color = type === 'police' ? null : pick(['#3bb0ff', '#ff3b6b', '#ffd23b', '#f4f4f4', '#2fd67a', '#7a5cff', '#ff8a1f', '#141418']);
        const v = this.spawn(type, x, z, yaw, { ai: { mode: 'traffic', from: ai, to: bi }, npcDriver: type !== 'motor', color });
        this.traffic.push(v);
      }
    }
    for (const v of this.traffic) if (v.ai && !v.driver) this.ai(v, dt);
  },
  ai(v, dt) {
    const ai = v.ai; let tx, tz, desired = v.def.max * 0.42;
    if (ai.mode === 'traffic') {
      const A = World.roadNodes[ai.from], B = World.roadNodes[ai.to]; if (!A || !B) return;
      const yaw = Math.atan2(B.x - A.x, B.z - A.z);
      tx = B.x - Math.cos(yaw) * 3.5; tz = B.z + Math.sin(yaw) * 3.5;
      if (dist2(tx, tz, v.pos.x, v.pos.z) < 7 * 7) { const nn = B.n.filter(i => i !== ai.from); ai.from = ai.to; ai.to = nn.length ? pick(nn) : ai.from; }
      desired = 13;
      // kavşak ışıkları: x-ekseni / z-ekseni yolları sırayla yeşil (8 sn)
      if (B.n.length > 2) {
        const alongX = Math.abs(B.x - A.x) > Math.abs(B.z - A.z);
        const phase = Math.floor((Game.t + (B.x * 0.013 + B.z * 0.007)) / 8) % 2;
        const green = alongX ? phase === 0 : phase === 1;
        const dB = Math.sqrt(dist2(B.x, B.z, v.pos.x, v.pos.z));
        if (!green && dB > 9.5 && dB < 20) desired = dB < 12 ? 0 : 4;
      }
    } else if (ai.mode === 'path' || ai.mode === 'race') {
      const wp = ai.path[ai.idx]; if (!wp) { v.physics(dt, 0, 1, 0, false); return; }
      tx = wp[0]; tz = wp[1]; desired = v.maxSpeed() * (ai.speedK || 0.8);
      if (dist2(tx, tz, v.pos.x, v.pos.z) < (ai.mode === 'race' ? 14 * 14 : 10 * 10)) { ai.idx++; if (ai.loop && ai.idx >= ai.path.length) ai.idx = 0; if (ai.onWp) ai.onWp(ai.idx); }
      // kauçuk bant (yarış dengesi)
      if (ai.mode === 'race' && Game.player) { const pd = Math.sqrt(dist2(Game.player.pos.x, Game.player.pos.z, v.pos.x, v.pos.z)); desired *= ai.ahead ? 0.85 : clamp(0.9 + pd / 150, 0.9, 1.2); }
    } else if (ai.mode === 'chase') {
      const t = Game.player; tx = t.pos.x; tz = t.pos.z; desired = v.maxSpeed() * 0.85;
      const d = Math.sqrt(dist2(tx, tz, v.pos.x, v.pos.z));
      if (d < 12 && !t.vehicle && !ai.unloaded) { ai.unloaded = true; for (let i = 0; i < 2; i++) Enemies.spawn('police', v.pos.x + rand(-2, 2), v.pos.z + rand(-2, 2), undefined, { tag: 'wanted' }); }
      if (d < 10) desired = 2;
    }
    const want = Math.atan2(tx - v.pos.x, tz - v.pos.z);
    let diff = ((want - v.yaw + Math.PI) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2) - Math.PI;
    const st = clamp(diff * 2.2, -1, 1);
    if (Math.abs(diff) > 0.6) desired *= 0.55;
    // önü kontrol (yavaşla/dur)
    const fx = Math.sin(v.yaw), fz = Math.cos(v.yaw); let block = false;
    if (ai.mode === 'traffic') {
      for (const o of Game.vehicles) { if (o === v) continue; const dx = o.pos.x - v.pos.x, dz = o.pos.z - v.pos.z, lf = dx * fx + dz * fz, lr = Math.abs(dx * fz - dz * fx); if (lf > 0 && lf < 11 && lr < 2.5) { block = true; break; } }
      if (!block) for (const a of Game.actors) { if (!a.alive || a.hidden) continue; const dx = a.pos.x - v.pos.x, dz = a.pos.z - v.pos.z, lf = dx * fx + dz * fz, lr = Math.abs(dx * fz - dz * fx); if (lf > 0 && lf < 8 && lr < 2) { block = true; if (a.kind === 'player' && Math.random() < 0.01) Sound.horn(); break; } }
      if (Game.combat && Math.random() < 0.002) desired *= 1.6;
    }
    if (block) desired = 0;
    const th = v.speed < desired ? 1 : 0, br = v.speed > desired + 2 ? 1 : 0;
    v.physics(dt, th * (ai.mode === 'traffic' ? 0.6 : 1), br, st, false);
  },
  policeChase(dt) {
    const p = Game.player.pos;
    this.policeCars = this.policeCars.filter(v => !v.removed && !v.wreck);
    if (this.policeCars.length < Math.min(3, Math.floor(S.wanted)) && Math.random() < dt * 0.5) {
      const ni = World.nearestNode(p.x + rand(-80, 80), p.z + rand(-80, 80)), n = World.roadNodes[ni];
      if (n && dist2(n.x, n.z, p.x, p.z) > 45 * 45) { const v = this.spawn('police', n.x, n.z, 0, { ai: { mode: 'chase' }, tag: 'police' }); v.siren = true; this.policeCars.push(v); }
    }
    for (const v of this.policeCars) if (!v.driver) this.ai(v, dt);
  },
  clearPolice() { for (const v of this.policeCars) if (!v.driver) v.remove(); this.policeCars = []; },
  updateAll(dt) {
    for (const v of Game.vehicles.slice()) {
      if (v.wreck) { v.wreckT += dt; if (Math.random() < 0.3) FX.trail(_v1.set(v.pos.x, v.pos.y + 1.5, v.pos.z), '#333', 0.5, 1.2); if (v.wreckT > 25 && !v.driver) v.remove(); continue; }
      if (!v.driver && !v.ai) { v.speed *= Math.max(0, 1 - dt * 2); if (Math.abs(v.speed) > 0.2 || v.vel.lengthSq() > 0.05) v.physics(dt, 0, 0, 0, false); else v.syncMesh(dt); }
    }
    if (this.mission) for (const v of this.mission) if (!v.removed && v.ai && !v.driver) this.ai(v, dt);
  },
  // -------------------------------------------------------- sahip olunan araçlar
  own(v) { if (S.vehicles.find(x => x.uid === v.uid)) return; v.owned = true; S.vehicles.push({ uid: v.uid, type: v.type, color: v.color, mods: v.mods }); },
  deliver(rec, at) {
    const [x, z] = at || [Game.player.pos.x + 5, Game.player.pos.z + 5];
    for (const v of Game.vehicles) if (v.uid === rec.uid) v.remove();
    return this.spawn(rec.type, x, z, Game.player.yaw, { uid: rec.uid, color: rec.color, mods: rec.mods, owned: true });
  },
  // -------------------------------------------------------- radyo
  nextStation() { const st = RADIO.stations.filter(s => !s.locked || S.eggs[s.locked]); this.radioIdx = (this.radioIdx + 1) % st.length; this.radioT = 0; Sound.ui(); },
  radio(dt) {
    const st = RADIO.stations.filter(s => !s.locked || S.eggs[s.locked]); const s = st[this.radioIdx % st.length];
    this.radioT -= dt;
    if (this.radioT <= 0) {
      this.radioT = 14;
      if (s.kind === 'music') this.radioLine = pick(RADIO.music);
      else if (s.kind === 'tape') this.radioLine = pick(RADIO.tape);
      else this.radioLine = Radio.bulletin();
      if (s.kind === 'news' && Sky.hourIn(3, 4) && !S.eggs.e_radio) { this.radioLine = RADIO.news.special; Eggs.found('e_radio'); }
    }
    $('radio').textContent = '📻 ' + s.name + ' — ' + this.radioLine;
  }
};
const Radio = {
  bulletin() {
    const ev = S.eventLog.slice(-4);
    const host = CAST.Radio_NewsHost.name;
    if (ev.length && Math.random() < 0.7) { const e = pick(ev); return host + ': ' + e.text; }
    if (S.wanted > 0 && !S.isRecognizedNinja) return host + ': ' + RADIO.news.wanted;
    if (S.isRecognizedNinja) return host + ': Şehrin ninjaları bu gece de devriyede. Suç oranı %' + Math.max(5, 60 - Math.floor(S.reputation / 2)) + ' düştü.';
    return host + ': ' + RADIO.news.start;
  }
};
