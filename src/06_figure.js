// ============================================================================
//  FİGÜR (blok oyuncak karakter) + İSKELET/POZ ANİMATÖRÜ
//  Pivot isimleri: pivot_head, pivot_torso, pivot_arm_L/R, pivot_leg_L/R
//  Özel .glb/.obj modeller autoRig ile aynı pivot düzenine getirilir.
// ============================================================================
const FRIEND_CAST = { kaan: 'Hero_Main', ela: 'Ally_Partner', ray: 'Master_Lightning', kor: 'Master_Fire', derya: 'Master_Water', taskin: 'Master_Earth', ayaz: 'Master_Ice', filiz: 'Master_Green', hikmet: 'Mentor_Master', tarik: 'NPC_DojoGuy', noda: 'NPC_NoodleChef', mimar: 'Boss_Architect', kanca: 'Boss_Hook' };

class Figure {
  static tintCache = new Map();
  constructor(castId, outfit = 'civil', lookOverride = null) {
    this.castId = castId; this.outfit = outfit;
    this.root = new THREE.Group();
    this.inner = new THREE.Group(); this.root.add(this.inner);
    this.extras = {};
    this.rebuild(lookOverride);
    this.pose = { aL: [0, 0, 0], aR: [0, 0, 0], lL: [0, 0, 0], lR: [0, 0, 0], hd: [0, 0, 0], ts: [0, 0, 0] };
    this.phase = Math.random() * 6;
    this.metal = false;
  }
  look(override) {
    if (override) return override;
    const c = CAST[this.castId] || {};
    if (c.looks) return c.looks[this.outfit] || c.looks.civil;
    return c.look || CAST.Gang.look;
  }
  rebuild(lookOverride) {
    this.inner.clear(); this.extras = {}; this.meshes = [];
    const slot = this.castId + (CAST[this.castId]?.looks ? '_' + this.outfit : '');
    let tpl = AssetManager.instance(slot) || AssetManager.instance(this.castId);
    this.skinned = false; this.mixer = null; this.bones = null;
    if (!tpl && Settings.modelMode === 'library' && this.castId !== 'Dummy') { tpl = AssetManager.instance(castLibSlot(this.castId)); if (tpl) this.libSlot = castLibSlot(this.castId); }
    if (tpl && tpl.userData.skinned) { this.setupSkinned(tpl, this.look(lookOverride)); }
    else if (tpl) {
      this.custom = true; this.inner.add(tpl);
      this.parts = collectPivots(tpl);
      tpl.traverse(n => { if (n.isMesh) { this.meshes.push(n); if (/mask/i.test(n.name)) this.extras.mask = n; } });
    } else { this.custom = false; this.buildProc(this.look(lookOverride)); }
    this.buildUmbrella();
    this.lookData = this.look(lookOverride);
  }
  // ---------------------------------------------------------- İskeletli (GLB) model
  setupSkinned(tpl, L) {
    this.custom = true; this.skinned = true; this.inner.add(tpl); this.parts = {};
    this.inner.scale.setScalar(L?.scale || 1);
    // renklendirme (malzemeler figür başına önbellekli klonlanır)
    const tint = (m, i) => {
      const n = (m.name || '').toLowerCase();
      let c = L.torso;
      if (/joint|grey|gray|metal/.test(n) || i > 0) c = L.plate || L.legs || L.arms;
      if (/black|eye|dark/.test(n)) return m;
      const key = (this.libSlot || 'x') + '|' + n + '|' + i + '|' + c + '|' + (m.map ? 'tx' : '');
      let mm = Figure.tintCache.get(key);
      if (!mm) {
        mm = new THREE.MeshPhysicalMaterial({ color: new THREE.Color(c), roughness: 0.32, metalness: 0.05, clearcoat: 0.6, clearcoatRoughness: 0.25, map: m.map || null, envMapIntensity: 1.0 });
        if (m.map) mm.color.lerp(new THREE.Color(1, 1, 1), 0.55);
        Figure.tintCache.set(key, mm);
      }
      return mm;
    };
    tpl.traverse(n => {
      if (!n.isMesh) return;
      n.castShadow = true; n.frustumCulled = false;
      n.material = Array.isArray(n.material) ? n.material.map(tint) : tint(n.material, n.material.name && /joint/i.test(n.material.name) ? 1 : 0);
      this.meshes.push(n);
    });
    // kemikler
    const bones = {}; const want = {
      hips: /(^|[^a-z])hips$|pelvis/i, spine: /spine2$|spine1$|chest$|torso$|spine$/i, head: /head$/i,
      armL: /(left.?arm$)|(upper.?arm.?l$)|(arm.?l$)|(shoulder.?l$)/i, armR: /(right.?arm$)|(upper.?arm.?r$)|(arm.?r$)|(shoulder.?r$)/i,
      legL: /(left.?up.?leg$)|(upper.?leg.?l$)|(thigh.?l$)|(leg.?l$)/i, legR: /(right.?up.?leg$)|(upper.?leg.?r$)|(thigh.?r$)|(leg.?r$)/i
    };
    tpl.traverse(n => { if (!n.isBone) return; for (const k in want) if (!bones[k] && want[k].test(n.name)) bones[k] = n; });
    this.bones = bones;
    // animasyon klipleri
    const clips = tpl.userData.clips || [];
    this.mixer = new THREE.AnimationMixer(tpl); this.actions = {};
    const find = (re, not) => clips.find(c => re.test(c.name) && !(not && not.test(c.name)) && !/pose|agree|shake/i.test(c.name));
    const map = { idle: find(/idle|stand/i), walk: find(/walk/i, /jump/i), run: find(/run/i), jump: find(/jump/i), punch: find(/punch|attack/i), death: find(/death|die/i), sit: find(/sit/i), cheer: find(/dance|wave|thumbs|yes/i) };
    for (const k in map) if (map[k]) this.actions[k] = this.mixer.clipAction(map[k]);
    if (this.actions.death) { this.actions.death.setLoop(THREE.LoopOnce, 1); this.actions.death.clampWhenFinished = true; }
    if (this.actions.jump) { this.actions.jump.setLoop(THREE.LoopOnce, 1); this.actions.jump.clampWhenFinished = true; }
    if (this.actions.punch) { this.actions.punch.setLoop(THREE.LoopOnce, 1); }
    this.curKey = null; this.play('idle', 0);
    // aksesuar: saç + maske kafa kemiğine (insan modeli)
    if (bones.head && L && this.libSlot !== 'lib_robot' && this.libSlot !== 'lib_soldier') {
      this.inner.updateMatrixWorld(true);
      const hq = new THREE.Quaternion(), hs = new THREE.Vector3(), rq = new THREE.Quaternion();
      bones.head.getWorldQuaternion(hq); bones.head.getWorldScale(hs); this.root.getWorldQuaternion(rq);
      const g = new THREE.Group(); g.quaternion.copy(hq.invert().multiply(rq));
      g.scale.setScalar(0.52 * (L.scale || 1) / Math.max(hs.x, 1e-4)); g.position.set(0, 0, 0);
      bones.head.add(g); this.accRoot = g;
      if (L.hair) this.hair(g, L.hair);
      const mc = CAST[this.castId]?.mask || '#333', mask = new THREE.Group(); g.add(mask);
      this.part(mask, mc, 0.48, 0.2, 0.08, 0, 0.11, 0.21, { geo: Geo.box }); this.part(mask, mc, 0.48, 0.12, 0.46, 0, 0.11, 0, { geo: Geo.box });
      mask.visible = false; this.extras.mask = mask;
    }
    this.parts = {};
    { const g = new THREE.Group(); g.position.set(-0.43, 1.55, 0); this.inner.add(g); this.parts.arm_R = g; }
  }
  play(key, fade = 0.2) {
    const a = this.actions[key] || this.actions.idle; if (!a || this.curAct === a) { this.curKey = key; return; }
    a.reset(); a.enabled = true; a.setEffectiveWeight(1); a.play();
    if (this.curAct && fade > 0) this.curAct.crossFadeTo(a, fade, false); else if (this.curAct) this.curAct.stop();
    this.curAct = a; this.curKey = key;
  }
  rotWorld(bone, axis, ang) {
    if (!bone || !ang) return;
    const pq = new THREE.Quaternion(); if (bone.parent) bone.parent.getWorldQuaternion(pq);
    const w = new THREE.Quaternion().setFromAxisAngle(axis, ang);
    const inv = pq.clone().invert();
    bone.quaternion.premultiply(inv.multiply(w).multiply(pq));
  }
  animateSkinned(dt, st) {
    const a = st.anim;
    const key = { idle: 'idle', walk: 'walk', umbrella: 'walk', run: 'run', jump: 'jump', fall: 'jump', glide: 'idle', spin: 'idle', drive: 'sit', ride: 'sit', sit: 'sit', focus: 'sit', kneel: 'sit', cheer: 'cheer', hurt: 'idle', cower: 'idle', swim: 'walk', ko: 'death' }[a] || 'idle';
    if (key !== this.curKey) this.play(key, key === 'death' ? 0.1 : 0.22);
    const act = this.curAct;
    if (act) { if (key === 'walk') act.timeScale = clamp(st.speed / 1.7, 0.6, 1.8); else if (key === 'run') act.timeScale = clamp(st.speed / 6.5, 0.8, 1.6); else act.timeScale = 1; }
    this.mixer.update(dt);
    // katmanlı prosedürel ekler (kombo, şok dalgası, süzülme, kasırga, isabet)
    this.root.updateMatrixWorld(true);
    const rq = new THREE.Quaternion(); this.root.getWorldQuaternion(rq);
    const right = new THREE.Vector3(1, 0, 0).applyQuaternion(rq), fwd = new THREE.Vector3(0, 0, 1).applyQuaternion(rq);
    const B = this.bones; let lean = 0;
    if (st.punch > 0) { const k = Math.sin((1 - st.punch) * Math.PI); this.rotWorld(st.punchSide ? B.armL : B.armR, right, -1.5 * k); this.rotWorld(B.spine, new THREE.Vector3(0, 1, 0), (st.punchSide ? -0.35 : 0.35) * k); }
    if (st.kick > 0) { const k = Math.sin((1 - st.kick) * Math.PI); this.rotWorld(B.legR, right, -1.3 * k); lean -= 0.2 * k; }
    if (st.slam > 0) { this.rotWorld(B.armL, right, -2.6 * st.slam); this.rotWorld(B.armR, right, -2.6 * st.slam); }
    if (st.cast > 0) { this.rotWorld(B.armL, right, -1.4 * st.cast); this.rotWorld(B.armR, right, -1.4 * st.cast); }
    if (a === 'glide' || a === 'spin') { this.rotWorld(B.armL, fwd, 1.2); this.rotWorld(B.armR, fwd, -1.2); if (a === 'glide') lean += 0.45; }
    if ((a === 'drive' || a === 'ride' || a === 'sit' || a === 'focus') && !this.actions.sit) { this.rotWorld(B.legL, right, -1.4); this.rotWorld(B.legR, right, -1.4); this.rotWorld(B.armL, right, -1.1); this.rotWorld(B.armR, right, -1.1); }
    if (a === 'cheer' && !this.actions.cheer) { this.rotWorld(B.armL, right, -2.8 + Math.sin(Game.t * 8) * 0.3); this.rotWorld(B.armR, right, -2.8 - Math.sin(Game.t * 8) * 0.3); }
    if (a === 'hurt' || a === 'cower') { this.rotWorld(B.armL, right, -2.4); this.rotWorld(B.armR, right, -2.4); lean += 0.5; }
    if (a === 'umbrella') this.rotWorld(B.armR, right, -1.2);
    if (a === 'jump' && !this.actions.jump) { this.rotWorld(B.armL, right, -2.2); this.rotWorld(B.armR, right, -2.2); }
    if (a === 'ko' && !this.actions.death) lean += 0;
    if (st.hit > 0) lean -= 0.35 * st.hit;
    if (a === 'run') lean += 0.12;
    this.rotWorld(B.spine, right, lean);
    this.inner.position.y = lerp(this.inner.position.y, (a === 'sit' || a === 'focus') && !this.actions.sit ? -0.45 : a === 'swim' ? -0.9 : 0, Math.min(1, dt * 10));
    this.inner.rotation.x = lerp(this.inner.rotation.x, a === 'swim' ? 1.2 : 0, Math.min(1, dt * 6));
  }
  part(parent, color, w, h, d, x, y, z, opts) {
    const geo = opts?.geo || (Math.min(w, h, d) > 0.12 ? Geo.rbox : Geo.box);
    const m = new THREE.Mesh(geo, opts?.mat || Mat.plastic(color, opts));
    m.scale.set(w, h, d); m.position.set(x, y, z); m.castShadow = true; m.receiveShadow = false;
    if (opts?.rot) m.rotation.set(...opts.rot);
    parent.add(m); this.meshes.push(m); return m;
  }
  buildProc(L) {
    const sc = L.scale || 1;
    this.inner.scale.setScalar(sc);
    const P = (name, x, y, z, parent) => { const g = new THREE.Group(); g.name = 'pivot_' + name; g.position.set(x, y, z); parent.add(g); return g; };
    const legL = P('leg_L', 0.17, 0.95, 0, this.inner), legR = P('leg_R', -0.17, 0.95, 0, this.inner);
    const torso = P('torso', 0, 0.95, 0, this.inner);
    const armL = P('arm_L', 0.43, 0.6, 0, torso), armR = P('arm_R', -0.43, 0.6, 0, torso);
    const head = P('head', 0, 0.7, 0, torso);
    this.parts = { leg_L: legL, leg_R: legR, torso, arm_L: armL, arm_R: armR, head };
    // Bacaklar & ayakkabı
    for (const lg of [legL, legR]) {
      this.part(lg, L.legs, 0.3, 0.82, 0.32, 0, -0.43, 0);
      this.part(lg, L.shoes || '#222', 0.32, 0.14, 0.42, 0, -0.88, 0.04);
    }
    // Gövde
    this.part(torso, L.torso, 0.66, 0.7, 0.38, 0, 0.35, 0);
    if (L.jacket) { // açık ceket: yan paneller + sırt
      this.part(torso, L.jacket, 0.2, 0.72, 0.4, 0.24, 0.35, 0.005); this.part(torso, L.jacket, 0.2, 0.72, 0.4, -0.24, 0.35, 0.005);
      this.part(torso, L.jacket, 0.68, 0.72, 0.06, 0, 0.35, -0.18);
      this.part(torso, L.jacket, 0.72, 0.1, 0.42, 0, 0.67, 0);
    }
    if (L.plate) this.part(torso, L.plate, 0.5, 0.26, 0.05, 0, 0.5, 0.2);
    if (L.apron) this.part(torso, L.apron, 0.5, 0.6, 0.04, 0, 0.12, 0.2);
    this.part(torso, L.belt || '#333', 0.68, 0.09, 0.4, 0, 0.04, 0);
    if (L.emblem) this.emblem(torso, L.emblem);
    if (L.cape) this.part(torso, L.cape, 0.62, 1.05, 0.04, 0, 0.1, -0.22);
    // Kollar & eller
    for (const [a, s] of [[armL, 1], [armR, -1]]) {
      this.part(a, L.arms, 0.22, 0.62, 0.24, 0, -0.3, 0);
      this.part(a, L.hands, 0.2, 0.18, 0.22, 0, -0.69, 0.01);
      if (L.shoulder) this.part(a, L.shoulder, 0.32, 0.14, 0.32, s * 0.03, 0.02, 0);
    }
    if (L.cane) { this.part(armR, '#6b4a2a', 0.06, 1.1, 0.06, 0, -0.95, 0.12); }
    // Kafa
    this.part(head, L.skin, 0.46, 0.46, 0.44, 0, 0.24, 0);
    const eye = L.eyes || '#111';
    this.part(head, eye, 0.07, 0.08, 0.02, 0.1, 0.27, 0.225); this.part(head, eye, 0.07, 0.08, 0.02, -0.1, 0.27, 0.225);
    this.part(head, '#ffffff', 0.025, 0.03, 0.01, 0.115, 0.29, 0.236); this.part(head, '#ffffff', 0.025, 0.03, 0.01, -0.085, 0.29, 0.236);
    this.part(head, '#5a2a2a', 0.14, 0.03, 0.02, 0, 0.12, 0.225);
    if (L.glasses) this.part(head, L.glasses, 0.42, 0.09, 0.03, 0, 0.27, 0.235);
    if (L.beard) this.part(head, L.beard, 0.4, 0.16, 0.08, 0, 0.06, 0.2);
    this.hair(head, L.hair || { style: 'short', color: '#222' });
    // Maske (ağız/yüz örtüsü) — sivil ve ninja kıyafette çalışır
    const mc = CAST[this.castId]?.mask || '#333';
    const mask = new THREE.Group(); head.add(mask);
    this.part(mask, mc, 0.48, 0.2, 0.08, 0, 0.11, 0.21); this.part(mask, mc, 0.48, 0.12, 0.46, 0, 0.11, 0);
    mask.visible = false; this.extras.mask = mask;
    this.merge();
  }
  // Performans: her pivotun statik parçalarını tek geometriye (vertex renkli) birleştir → figür başına ~6 çizim çağrısı
  merge() {
    if (!Figure.mat) Figure.mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.3, metalness: 0.0, envMapIntensity: 0.9 });
    this.inner.updateMatrixWorld(true);
    const pivots = Object.values(this.parts), skip = new Set([this.extras.mask]);
    const inv = new THREE.Matrix4(), rel = new THREE.Matrix4(), col = new THREE.Color();
    const merged = [];
    for (const pv of pivots) {
      const list = [], rm = [];
      const walk = (o) => { for (const c of o.children) { if (skip.has(c) || pivots.includes(c)) continue; if (c.isMesh) { rm.push(c); list.push(c); } else walk(c); } };
      walk(pv);
      if (list.length < 2) continue;
      inv.copy(pv.matrixWorld).invert();
      const geos = list.map(m => {
        const g = m.geometry.clone(); rel.multiplyMatrices(inv, m.matrixWorld); g.applyMatrix4(rel);
        const n = g.attributes.position.count, arr = new Float32Array(n * 3); col.copy(m.material.color);
        for (let i = 0; i < n; i++) { arr[i * 3] = col.r; arr[i * 3 + 1] = col.g; arr[i * 3 + 2] = col.b; }
        g.setAttribute('color', new THREE.BufferAttribute(arr, 3));
        for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv', 'color'].includes(k)) g.deleteAttribute(k);
        return g;
      });
      const mg = mergeGeometries(geos, false); if (!mg) continue;
      for (const g of geos) g.dispose();
      for (const m of rm) m.parent.remove(m);
      const mm = new THREE.Mesh(mg, Figure.mat); mm.castShadow = true; pv.add(mm); merged.push(mm);
    }
    // birleştirilmeyen (tekil/özel) parçalar + birleştirilmişler
    const rest = []; this.inner.traverse(n => { if (n.isMesh && !merged.includes(n)) rest.push(n); });
    this.meshes = merged.concat(rest.filter(m => !this.isExtra(m)));
  }
  isExtra(m) { let o = m; while (o) { if (o === this.extras.mask || o === this.extras.umbrella) return true; o = o.parent; } return false; }
  emblem(parent, e) {
    const c = e.color, g = new THREE.Group(); g.position.set(0, 0.42, 0.205); parent.add(g);
    const mat = Mat.plastic(c, { em: c, emi: 0.6 });
    const add = (geo, sx, sy, sz, x, y, rz = 0) => { const m = new THREE.Mesh(geo, mat); m.scale.set(sx, sy, sz); m.position.set(x, y, 0); m.rotation.z = rz; g.add(m); };
    switch (e.shape) {
      case 'gear': add(Geo.torus, 0.08, 0.08, 0.2, 0, 0); add(Geo.box, 0.05, 0.22, 0.03, 0, 0); add(Geo.box, 0.22, 0.05, 0.03, 0, 0); break;
      case 'bolt': add(Geo.box, 0.05, 0.16, 0.03, 0.03, 0.05, -0.5); add(Geo.box, 0.05, 0.16, 0.03, -0.03, -0.06, -0.5); add(Geo.box, 0.1, 0.04, 0.03, 0, 0); break;
      case 'flame': add(Geo.cone, 0.14, 0.24, 0.03, 0, 0); break;
      case 'wave': add(Geo.box, 0.22, 0.04, 0.03, 0, 0.05, 0.3); add(Geo.box, 0.22, 0.04, 0.03, 0, -0.04, -0.3); break;
      case 'rock': add(Geo.box, 0.16, 0.13, 0.03, 0, 0, 0.4); break;
      case 'flake': add(Geo.box, 0.22, 0.03, 0.03, 0, 0); add(Geo.box, 0.22, 0.03, 0.03, 0, 0, 1.05); add(Geo.box, 0.22, 0.03, 0.03, 0, 0, -1.05); break;
      case 'leaf': add(Geo.sphere, 0.1, 0.2, 0.03, 0, 0, 0.5); break;
      case 'core': add(Geo.sphere, 0.16, 0.16, 0.06, 0, 0); break;
      case 'swirl': add(Geo.torus, 0.07, 0.07, 0.2, -0.03, 0.02); add(Geo.torus, 0.05, 0.05, 0.2, 0.05, -0.04); break;
      default: add(Geo.box, 0.12, 0.12, 0.03, 0, 0, 0.785);
    }
  }
  hair(head, H) {
    const c = H.color, p = (w, h, d, x, y, z, o) => this.part(head, c, w, h, d, x, y, z, o);
    const cap = () => { p(0.5, 0.14, 0.48, 0, 0.5, 0); p(0.5, 0.26, 0.08, 0, 0.36, -0.22); p(0.06, 0.24, 0.46, 0.24, 0.38, -0.01); p(0.06, 0.24, 0.46, -0.24, 0.38, -0.01); };
    switch (H.style) {
      case 'spiky': cap(); for (let i = 0; i < 6; i++) p(0.14, 0.26, 0.14, -0.18 + (i % 3) * 0.18, 0.62, -0.1 + Math.floor(i / 3) * 0.18, { geo: Geo.cone, rot: [Math.floor(i / 3) ? 0.3 : -0.4, 0, (i % 3 - 1) * -0.4] }); p(0.5, 0.08, 0.1, 0, 0.47, 0.22); break;
      case 'braid': cap(); p(0.52, 0.1, 0.12, 0, 0.47, 0.2, { rot: [0, 0, 0.15] }); for (let i = 0; i < 5; i++) p(0.13, 0.13, 0.13, 0.22 - i * 0.01, 0.28 - i * 0.14, 0.12 + i * 0.01); break;
      case 'ponytail': cap(); p(0.14, 0.42, 0.14, 0, 0.3, -0.3, { rot: [0.4, 0, 0] }); break;
      case 'bun': cap(); p(0.22, 0.22, 0.22, 0, 0.64, -0.08, { geo: Geo.sphere }); break;
      case 'long': cap(); p(0.5, 0.55, 0.1, 0, 0.12, -0.24); break;
      case 'short': cap(); break;
      case 'bald': break;
      case 'elder': p(0.08, 0.16, 0.3, 0.25, 0.32, -0.04); p(0.08, 0.16, 0.3, -0.25, 0.32, -0.04); p(0.42, 0.1, 0.06, 0, 0.36, -0.23); break;
      case 'cap': p(0.52, 0.16, 0.5, 0, 0.52, 0); p(0.5, 0.04, 0.2, 0, 0.45, 0.3); p(0.08, 0.06, 0.02, 0, 0.53, 0.255, { mat: Mat.plastic('#ffd23b') }); break;
      case 'visor': p(0.54, 0.36, 0.52, 0, 0.42, -0.01); p(0.5, 0.11, 0.06, 0, 0.3, 0.24, { mat: Mat.neon(c === '#222' ? '#ff3b3b' : '#20f0ff') }); break;
      case 'crest': p(0.52, 0.22, 0.5, 0, 0.5, -0.01); p(0.12, 0.4, 0.4, 0, 0.74, -0.04, { geo: Geo.cone, rot: [0, 0, 0] }); p(0.06, 0.18, 0.52, 0.26, 0.4, -0.01); p(0.06, 0.18, 0.52, -0.26, 0.4, -0.01); break;
      case 'hood': p(0.56, 0.18, 0.54, 0, 0.53, -0.02); p(0.08, 0.5, 0.54, 0.27, 0.26, -0.02); p(0.08, 0.5, 0.54, -0.27, 0.26, -0.02); p(0.56, 0.5, 0.08, 0, 0.26, -0.27); break;
      case 'crown': cap(); for (let i = 0; i < 5; i++) p(0.1, 0.28, 0.1, Math.cos(i * 1.26) * 0.2, 0.66, Math.sin(i * 1.26) * 0.2, { geo: Geo.cone, mat: Mat.plastic(c, { em: '#bff4ff', emi: 0.5 }) }); break;
      case 'leaf': cap(); for (let i = 0; i < 6; i++) p(0.12, 0.3, 0.05, Math.cos(i * 1.05) * 0.22, 0.62, Math.sin(i * 1.05) * 0.22, { geo: Geo.sphere, rot: [Math.sin(i) * 0.5, 0, Math.cos(i) * 0.5] }); break;
      case 'pompadour': cap(); p(0.46, 0.22, 0.3, 0, 0.62, 0.12, { rot: [-0.4, 0, 0] }); break;
      case 'chef': p(0.4, 0.5, 0.4, 0, 0.72, 0, { geo: Geo.cyl }); p(0.5, 0.08, 0.48, 0, 0.47, 0); break;
      case 'band': p(0.5, 0.1, 0.48, 0, 0.5, 0); p(0.5, 0.08, 0.47, 0, 0.4, 0.005, { mat: Mat.plastic(c) }); this.part(head, '#141418', 0.5, 0.06, 0.48, 0, 0.47, 0); break;
      default: cap();
    }
  }
  buildUmbrella() {
    const arm = this.parts.arm_R; if (!arm) return;
    const g = new THREE.Group(); g.position.set(0, -0.7, 0.15); arm.add(g);
    const stick = new THREE.Mesh(Geo.cylLo, Mat.plastic('#222')); stick.scale.set(0.04, 1.3, 0.04); stick.position.y = 0.6; g.add(stick);
    const can = new THREE.Mesh(Geo.cone, Mat.plastic(pick(['#ff3b6b', '#20c9b0', '#ffd23b', '#7a5cff', '#141418']))); can.scale.set(1.6, 0.5, 1.6); can.position.y = 1.35; can.rotation.y = Math.PI / 4; g.add(can);
    g.visible = false; this.extras.umbrella = g;
  }
  setMask(on) { if (this.extras.mask) this.extras.mask.visible = on; }
  setUmbrella(on) { if (this.extras.umbrella) this.extras.umbrella.visible = on; }
  setMetal(on) {
    if (this.metal === on) return; this.metal = on;
    const mm = Mat.getMetalSkin();
    for (const m of this.meshes) { if (on) { m.userData.orig = m.material; m.material = mm; } else if (m.userData.orig) m.material = m.userData.orig; }
  }
  setOutfit(o) { if (this.outfit === o) return; const mask = this.extras.mask?.visible; this.outfit = o; this.rebuild(); this.setMask(!!mask); }
  // ---------------------------------------------------------- Poz animasyonu
  animate(dt, st) {
    if (this.skinned) return this.animateSkinned(dt, st);
    const P = this.pose, sp = st.speed || 0;
    this.phase += dt * (2.2 + sp * 1.15);
    const s = Math.sin(this.phase), c = Math.cos(this.phase);
    const T = { aL: [0, 0, 0.06], aR: [0, 0, -0.06], lL: [0, 0, 0], lR: [0, 0, 0], hd: [0, 0, 0], ts: [0, 0, 0] };
    let bob = 0;
    const a = st.anim;
    if (a === 'walk' || a === 'run') {
      const amp = a === 'run' ? 1.0 : 0.55;
      T.lL[0] = s * amp; T.lR[0] = -s * amp; T.aL[0] = -s * amp * 0.9; T.aR[0] = s * amp * 0.9; T.ts[0] = a === 'run' ? 0.18 : 0.04; bob = Math.abs(c) * (a === 'run' ? 0.09 : 0.04);
    } else if (a === 'idle') { T.aL[2] = 0.08 + Math.sin(Game.t * 1.6) * 0.03; T.aR[2] = -T.aL[2]; T.hd[1] = Math.sin(Game.t * 0.4) * 0.15; }
    else if (a === 'jump' || a === 'fall') { T.aL = [-2.4, 0, 0.3]; T.aR = [-2.4, 0, -0.3]; T.lL[0] = -0.6; T.lR[0] = 0.3; }
    else if (a === 'glide') { T.aL = [0, 0, 1.45]; T.aR = [0, 0, -1.45]; T.lL[0] = 0.3; T.lR[0] = 0.4; T.ts[0] = 0.5; }
    else if (a === 'spin') { T.aL = [0, 0, 1.5]; T.aR = [0, 0, -1.5]; T.lL[2] = 0.2; T.lR[2] = -0.2; }
    else if (a === 'drive') { T.lL[0] = -1.45; T.lR[0] = -1.45; T.aL[0] = -1.2; T.aR[0] = -1.2; }
    else if (a === 'ride') { T.lL = [-1.2, 0, 0.5]; T.lR = [-1.2, 0, -0.5]; T.aL[0] = -1.4; T.aR[0] = -1.4; T.ts[0] = 0.25; }
    else if (a === 'sit') { T.lL[0] = -1.5; T.lR[0] = -1.5; T.aL[0] = -0.4; T.aR[0] = -0.4; bob = -0.45; }
    else if (a === 'cheer') { T.aL = [-2.8 + Math.sin(Game.t * 8) * 0.3, 0, 0.3]; T.aR = [-2.8 - Math.sin(Game.t * 8) * 0.3, 0, -0.3]; bob = Math.abs(Math.sin(Game.t * 6)) * 0.08; }
    else if (a === 'kneel') { T.lL[0] = -1.5; T.lR[0] = 0.2; bob = -0.4; T.ts[0] = 0.3; T.hd[0] = 0.4; }
    else if (a === 'hurt' || a === 'cower') { T.aL = [-2.6, 0, -0.6]; T.aR = [-2.6, 0, 0.6]; T.ts[0] = 0.5; T.hd[0] = 0.5; bob = -0.25; T.lL[0] = -0.8; T.lR[0] = -0.8; }
    else if (a === 'swim') { T.aL = [-2.8 + s * 1.4, 0, 0.3]; T.aR = [-2.8 - s * 1.4, 0, -0.3]; T.ts[0] = 1.3; T.lL[0] = s * 0.4; T.lR[0] = -s * 0.4; bob = -0.9; }
    else if (a === 'ko') { T.aL = [-2.9, 0, 0.4]; T.aR = [-2.9, 0, -0.4]; }
    else if (a === 'umbrella') { T.lL[0] = s * 0.5; T.lR[0] = -s * 0.5; T.aR = [-1.25, 0, -0.1]; T.aL[0] = -s * 0.4; bob = Math.abs(c) * 0.04; }
    else if (a === 'focus') { T.lL = [-1.5, 0, 0.6]; T.lR = [-1.5, 0, -0.6]; T.aL = [-1.2, 0, -0.6]; T.aR = [-1.2, 0, 0.6]; bob = -0.5; T.hd[0] = 0.2; }
    // Saldırı katmanları
    if (st.punch > 0) { const k = Math.sin((1 - st.punch) * Math.PI); const arm = st.punchSide ? T.aL : T.aR; arm[0] = lerp(arm[0], -1.65, k); arm[2] = 0; T.ts[1] = (st.punchSide ? -0.35 : 0.35) * k; }
    if (st.kick > 0) { const k = Math.sin((1 - st.kick) * Math.PI); T.lR[0] = -1.4 * k; T.ts[0] = -0.2 * k; }
    if (st.slam > 0) { const k = st.slam; T.aL = [-3.0 * k, 0, 0.2]; T.aR = [-3.0 * k, 0, -0.2]; }
    if (st.cast > 0) { T.aR = [-1.6, 0, 0]; T.aL = [-1.6, 0, 0]; }
    if (st.hit > 0) { T.ts[0] = -0.4 * st.hit; T.hd[0] = -0.3 * st.hit; }
    const k = Math.min(1, dt * 14);
    for (const key in T) for (let i = 0; i < 3; i++) P[key][i] = lerp(P[key][i], T[key][i], k);
    const pr = this.parts;
    const ap = (n, v) => { if (pr[n]) pr[n].rotation.set(v[0], v[1], v[2]); };
    ap('arm_L', P.aL); ap('arm_R', P.aR); ap('leg_L', P.lL); ap('leg_R', P.lR); ap('head', P.hd); ap('torso', P.ts);
    this.inner.position.y = lerp(this.inner.position.y, bob, k);
  }
}
function makeFigure(castId, outfit, look) { return new Figure(castId, outfit, look); }
function civilianLook(seed) {
  const r = mulberry32(seed), P = CIV_PALETTE, pk = (a) => a[Math.floor(r() * a.length)];
  const top = pk(P.tops), skin = pk(P.skins);
  return { skin, hair: { style: pk(P.styles), color: pk(P.hairs) }, torso: top, arms: r() > 0.5 ? top : skin, hands: skin, legs: pk(P.legs), shoes: pk(['#222', '#f4f4f4', '#6b4a2a']), belt: '#333', jacket: r() > 0.75 ? pk(P.tops) : null };
}
