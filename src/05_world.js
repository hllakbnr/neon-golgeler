// ============================================================================
//  AÇIK DÜNYA — arazi, su, şehir blokları, köprüler, simge yapılar, çarpışma,
//  parça (chunk) tabanlı instancing + mesafe/frustum culling, yol ağı
// ============================================================================
const WATER_Y = -1.0;
const CHUNK = 160;
function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

const World = {
  rng: mulberry32(1337),
  land: [
    { x0: -560, x1: -150, z0: -560, z1: 560, h: 0 },   // batı (liman, çarşı, dağ)
    { x0: -90, x1: 410, z0: -560, z1: 560, h: 0 },     // merkez + doğu
    { x0: 460, x1: 620, z0: 160, z1: 400, h: 0, island: true }, // ada
    // kanal köprüleri
    { x0: -152, x1: -88, z0: -248, z1: -232, h: 0.35, bridge: true }, { x0: -152, x1: -88, z0: -8, z1: 8, h: 0.35, bridge: true },
    { x0: -152, x1: -88, z0: 232, z1: 248, h: 0.35, bridge: true }, { x0: -152, x1: -88, z0: 472, z1: 488, h: 0.35, bridge: true },
    { x0: 408, x1: 462, z0: 232, z1: 248, h: 0.35, bridge: true, east: true },
    // iskeleler
    { x0: -488, x1: -472, z0: 558, z1: 640, h: 0.2 }, { x0: -368, x1: -352, z0: 558, z1: 640, h: 0.2 }, { x0: -248, x1: -232, z0: 558, z1: 640, h: 0.2 }
  ],
  boxes: [], grid: new Map(), cell: 32,
  chunks: new Map(), interact: [], neon: [], props: [],
  roadNodes: [], roadEdges: [], sidewalkPts: [], shelters: [],
  dynamic: [], // dönen heykel vb.
  mtn: { x0: -560, x1: -150, z0: -560, z1: -160, cx: -345, cz: -360 },
  isMountain(x, z) { const m = this.mtn; return x > m.x0 && x < m.x1 && z > m.z0 && z < m.z1; },
  terrainH(x, z) {
    const m = this.mtn;
    const dx = x - m.cx, dz = z - m.cz;
    let h = 92 * Math.exp(-(dx * dx + dz * dz) / (2 * 95 * 95));
    h += 6 * Math.sin(x * 0.045) * Math.cos(z * 0.05) + 3 * Math.sin(x * 0.11 + z * 0.07);
    const e = Math.min(x - m.x0, m.x1 - x, z - m.z0, m.z1 - z);
    const f = smooth(clamp(e / 45, 0, 1));
    return Math.max(0.08, h * f + 0.08);
  },
  landAt(x, z) { for (let i = this.land.length - 1; i >= 0; i--) { const r = this.land[i]; if (x >= r.x0 && x <= r.x1 && z >= r.z0 && z <= r.z1) return r; } return null; },
  baseHeight(x, z) {
    if (this.isMountain(x, z)) return this.terrainH(x, z);
    const r = this.landAt(x, z); return r ? r.h : -4;
  },
  // ---------------------------------------------------------- çarpışma kutuları
  addBox(x0, x1, z0, z1, y0, y1, tag) {
    const b = { x0, x1, z0, z1, y0, y1, tag: tag || null, id: this.boxes.length };
    this.boxes.push(b);
    const c = this.cell;
    for (let gx = Math.floor(x0 / c); gx <= Math.floor(x1 / c); gx++) for (let gz = Math.floor(z0 / c); gz <= Math.floor(z1 / c); gz++) {
      const k = gx + ',' + gz; let a = this.grid.get(k); if (!a) this.grid.set(k, a = []); a.push(b);
    }
    return b;
  },
  removeBox(b) { b.dead = true; },
  nearBoxes(x, z) { return this.grid.get(Math.floor(x / this.cell) + ',' + Math.floor(z / this.cell)) || []; },
  // Zemin yüksekliği (çatı/teras dahil): ayaklar y'nin 0.7 üstüne kadar basamak çıkabilir
  groundAt(x, z, y) {
    let h = this.baseHeight(x, z);
    for (const b of this.nearBoxes(x, z)) {
      if (b.dead) continue;
      if (x >= b.x0 && x <= b.x1 && z >= b.z0 && z <= b.z1 && b.y1 <= y + 0.7 && b.y1 > h) h = b.y1;
    }
    return h;
  },
  // Yer seviyesi yüzeyi (teras/çatı değil): arazi + en fazla 3.7 m üstündeki basamaklar
  // Bir noktayı (ör. toplanabilir eşya) bina içindeyse en yakın kenarın dışına taşır
  freeSpot(x, z, y = 0) {
    for (let it = 0; it < 4; it++) {
      let moved = false;
      for (const b of this.nearBoxes(x, z)) {
        if (b.dead || !(x > b.x0 - 0.6 && x < b.x1 + 0.6 && z > b.z0 - 0.6 && z < b.z1 + 0.6) || y >= b.y1 - 0.65 || y + 1.8 <= b.y0) continue;
        const l = x - b.x0, r = b.x1 - x, f = z - b.z0, k = b.z1 - z, m = Math.min(l, r, f, k);
        if (m === l) x = b.x0 - 1.4; else if (m === r) x = b.x1 + 1.4; else if (m === f) z = b.z0 - 1.4; else z = b.z1 + 1.4; moved = true;
      }
      if (!moved) break;
    }
    return [x, z];
  },
  surfaceAt(x, z) { return this.groundAt(x, z, this.baseHeight(x, z) + 3); },
  // Yatay itme: silindir (r) vs AABB; ayak y, boy hgt
  collide(p, r, hgt = 1.8) {
    let hit = false;
    for (const b of this.nearBoxes(p.x, p.z)) {
      if (b.dead) continue;
      if (p.y >= b.y1 - 0.65 || p.y + hgt <= b.y0) continue;
      const cx = clamp(p.x, b.x0, b.x1), cz = clamp(p.z, b.z0, b.z1);
      const dx = p.x - cx, dz = p.z - cz, d2 = dx * dx + dz * dz;
      if (d2 < r * r) {
        hit = true;
        if (d2 > 1e-6) { const d = Math.sqrt(d2), k = (r - d) / d; p.x += dx * k; p.z += dz * k; }
        else { // merkez kutunun içinde: en kısa eksenden çıkar
          const l = p.x - b.x0, rr = b.x1 - p.x, f = p.z - b.z0, bk = b.z1 - p.z, m = Math.min(l, rr, f, bk);
          if (m === l) p.x = b.x0 - r; else if (m === rr) p.x = b.x1 + r; else if (m === f) p.z = b.z0 - r; else p.z = b.z1 + r;
        }
      }
    }
    return hit;
  },
  // Işın/çizgi görüşü (stealth kameraları & polis için yaklaşık)
  lineClear(ax, az, bx, bz, y) {
    const steps = Math.ceil(Math.sqrt(dist2(ax, az, bx, bz)) / 3);
    for (let i = 1; i < steps; i++) {
      const t = i / steps, x = lerp(ax, bx, t), z = lerp(az, bz, t);
      for (const b of this.nearBoxes(x, z)) if (!b.dead && x > b.x0 && x < b.x1 && z > b.z0 && z < b.z1 && y > b.y0 && y < b.y1) return false;
    }
    return true;
  },
  // ---------------------------------------------------------- chunk instancing
  chunkOf(x, z) {
    const k = Math.floor(x / CHUNK) + ',' + Math.floor(z / CHUNK);
    let c = this.chunks.get(k);
    if (!c) { c = { key: k, cx: (Math.floor(x / CHUNK) + 0.5) * CHUNK, cz: (Math.floor(z / CHUNK) + 0.5) * CHUNK, bld: [], box: [], neon: [], cyl: [], cone: [], sph: [], lib: {}, halos: [], group: new THREE.Group() }; this.chunks.set(k, c); }
    return c;
  },
  _m: new THREE.Matrix4(), _q: new THREE.Quaternion(), _s: new THREE.Vector3(), _p: new THREE.Vector3(), _e: new THREE.Euler(),
  mtx(x, y, z, sx, sy, sz, ry = 0) { this._p.set(x, y, z); this._q.setFromEuler(this._e.set(0, ry, 0)); this._s.set(sx, sy, sz); return this._m.compose(this._p, this._q, this._s).clone(); },
  addBuilding(x, z, w, d, h, color, y0 = 0) { this.chunkOf(x, z).bld.push([this.mtx(x, y0, z, w, h, d), color]); this.addBox(x - w / 2, x + w / 2, z - d / 2, z + d / 2, y0, y0 + h, 'bld'); },
  addProp(x, y, z, w, h, d, color, solid = false, ry = 0) { this.chunkOf(x, z).box.push([this.mtx(x, y, z, w, h, d, ry), color]); if (solid) this.addBox(x - w / 2, x + w / 2, z - d / 2, z + d / 2, y, y + h); },
  addNeon(x, y, z, w, h, d, color, light = true, ry = 0) {
    this.chunkOf(x, z).neon.push([this.mtx(x, y, z, w, h, d, ry), color]);
    if (light) { this.neon.push({ x, y: y + h / 2, z, c: color }); this.chunkOf(x, z).halos.push([x, y + h / 2, z, color, Math.max(w, h, d) * 1.6]); }
  },
  addCyl(x, y, z, r, h, color, solid = false) { this.chunkOf(x, z).cyl.push([this.mtx(x, y, z, r * 2, h, r * 2), color]); if (solid) this.addBox(x - r, x + r, z - r, z + r, y, y + h); },
  addCone(x, y, z, r, h, color) { this.chunkOf(x, z).cone.push([this.mtx(x, y, z, r * 2, h, r * 2, Math.PI / 4), color]); },
  // ---- sokak mobilyası: kütüphane GLB'si varsa instanced model, yoksa çok parçalı yedek model
  addLib(slot, x, y, z, h, ry) { const c = this.chunkOf(x, z); (c.lib[slot] ||= []).push(this.mtx(x, y, z, h, h, h, ry)); },
  lamp(x, z, dx, dz, lc, light) {
    const ry = Math.atan2(dx, dz);
    if (AssetManager.templates.lib_lamp) { this.addLib('lib_lamp', x, 0, z, 3.3, ry); this.addNeon(x + dx * 0.6, 6.1, z + dz * 0.6, 0.6, 0.15, 0.6, lc, light); return; }
    this.addCyl(x, 0, z, 0.16, 6.4, '#2a2540'); this.addCyl(x, 0, z, 0.32, 0.5, '#2a2540');
    this.addProp(x + dx * 0.55, 6.25, z + dz * 0.55, dx ? 1.3 : 0.18, 0.16, dz ? 1.3 : 0.18, '#2a2540');
    this.addNeon(x + dx * 1.05, 5.95, z + dz * 1.05, dx ? 0.9 : 0.5, 0.28, dz ? 0.9 : 0.5, lc, light);
    this.addHalo(x + dx * 1.05, 5.75, z + dz * 1.05, lc, 5);
  },
  tree(x, z) {
    if (AssetManager.templates.lib_tree) { this.addLib('lib_tree', x, 0, z, rand(2.6, 3.6), rand(0, 6.28)); return; }
    const g = pick(['#2fd67a', '#4a9a2a', '#6fbf3a', '#3bbf7a']);
    this.addCyl(x, 0, z, 0.32, 2.6, '#6b4a2a'); this.addCyl(x, 0, z, 0.9, 0.35, '#8a7a6a');
    this.addSph(x, 3.4, z, 1.9, g); this.addSph(x + 0.7, 4.4, z - 0.4, 1.3, g); this.addSph(x - 0.6, 4.2, z + 0.5, 1.2, g);
  },
  bench(x, z, ry) {
    if (AssetManager.templates.lib_bench) { this.addLib('lib_bench', x, 0, z, 0.6, ry); return; }
    const along = Math.abs(Math.sin(ry)) > 0.5;
    this.addProp(x, 0.45, z, along ? 0.6 : 1.8, 0.12, along ? 1.8 : 0.6, '#c9603a'); this.addProp(x + (along ? 0.28 : 0), 0.55, z + (along ? 0 : 0.28), along ? 0.1 : 1.8, 0.5, along ? 1.8 : 0.1, '#c9603a');
    for (const s of [-0.7, 0.7]) this.addProp(x + (along ? 0 : s), 0, z + (along ? s : 0), 0.12, 0.45, 0.5, '#2a2540');
  },
  addSph(x, y, z, r, color) { this.chunkOf(x, z).sph.push([this.mtx(x, y, z, r * 2, r * 1.7, r * 2), color]); },
  libGeo(slot) {
    this._libGeo ||= {}; if (this._libGeo[slot] !== undefined) return this._libGeo[slot];
    const t = AssetManager.templates[slot]; if (!t) return this._libGeo[slot] = null;
    t.updateMatrixWorld(true); const geos = [], col = new THREE.Color();
    t.traverse(m => { if (!m.isMesh) return; const g = m.geometry.clone(); g.applyMatrix4(m.matrixWorld); if (!g.attributes.normal) g.computeVertexNormals(); const n = g.attributes.position.count, arr = new Float32Array(n * 3); col.copy(Array.isArray(m.material) ? m.material[0].color : m.material.color || col.set('#ffffff')); for (let i = 0; i < n; i++) arr.set([col.r, col.g, col.b], i * 3); g.setAttribute('color', new THREE.BufferAttribute(arr, 3)); for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'color'].includes(k)) g.deleteAttribute(k); if (g.index) geos.push(g.toNonIndexed()); else geos.push(g); });
    let mg = null; try { mg = geos.length ? mergeGeometries(geos, false) : null; } catch (e) { console.warn('Kütüphane prop birleştirilemedi', slot, e); }
    return this._libGeo[slot] = mg;
  },
  addHalo(x, y, z, color, size) { this.chunkOf(x, z).halos.push([x, y, z, color, size]); },
  finalizeChunks() {
    const col = new THREE.Color();
    const make = (list, geo, mat) => {
      if (!list.length) return null;
      const im = new THREE.InstancedMesh(geo, mat, list.length);
      list.forEach(([m, c], i) => { im.setMatrixAt(i, m); im.setColorAt(i, col.set(c)); });
      im.instanceMatrix.needsUpdate = true; if (im.instanceColor) im.instanceColor.needsUpdate = true;
      im.computeBoundingSphere(); im.computeBoundingBox && im.computeBoundingBox();
      return im;
    };
    const propMat = new THREE.MeshPhysicalMaterial({ color: 0xffffff, roughness: 0.3, metalness: 0.0, clearcoat: Settings.quality === 'low' ? 0 : 0.45, clearcoatRoughness: 0.2 });
    const neonMat = new THREE.MeshBasicMaterial({ color: 0xffffff, toneMapped: false });
    const haloMat = new THREE.PointsMaterial({ size: 1, map: haloTex, vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, sizeAttenuation: true, toneMapped: false });
    this.haloMat = haloMat;
    const cylG = Geo.cylLo.clone(); cylG.translate(0, 0.5, 0); const coneG = Geo.cone.clone(); coneG.translate(0, 0.5, 0);
    for (const c of this.chunks.values()) {
      const b = make(c.bld, Geo.boxB, Mat.building()); if (b) { b.castShadow = true; b.receiveShadow = true; c.group.add(b); }
      const p = make(c.box, Geo.boxB, propMat); if (p) { p.castShadow = true; p.receiveShadow = true; c.group.add(p); }
      const n = make(c.neon, Geo.boxB, neonMat); if (n) c.group.add(n);
      const cy = make(c.cyl, cylG, propMat); if (cy) { cy.castShadow = true; c.group.add(cy); }
      const co = make(c.cone, coneG, propMat); if (co) { co.castShadow = true; c.group.add(co); }
      const sp = make(c.sph, Geo.sphere, propMat); if (sp) { sp.castShadow = true; sp.receiveShadow = true; c.group.add(sp); }
      for (const slot in c.lib) {
        const g = this.libGeo(slot); if (!g) continue;
        const im = new THREE.InstancedMesh(g, this.libMat ||= new THREE.MeshPhysicalMaterial({ vertexColors: true, roughness: 0.4, clearcoat: 0.3 }), c.lib[slot].length);
        c.lib[slot].forEach((m, i) => im.setMatrixAt(i, m)); im.instanceMatrix.needsUpdate = true; im.computeBoundingSphere(); im.castShadow = true; im.receiveShadow = true; c.group.add(im);
      }
      if (c.halos.length) {
        const g = new THREE.BufferGeometry(); const pos = new Float32Array(c.halos.length * 3), cl = new Float32Array(c.halos.length * 3);
        c.halos.forEach((h, i) => { pos.set([h[0], h[1], h[2]], i * 3); col.set(h[3]); cl.set([col.r, col.g, col.b], i * 3); });
        g.setAttribute('position', new THREE.BufferAttribute(pos, 3)); g.setAttribute('color', new THREE.BufferAttribute(cl, 3));
        const pts = new THREE.Points(g, haloMat); c.group.add(pts); c.halo = pts;
        // ıslak zemin neon yansımaları (tek instanced düzlem)
        const refl = new THREE.InstancedMesh(Geo.plane, this.reflMat ||= new THREE.MeshBasicMaterial({ map: haloTex, transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending, toneMapped: false }), c.halos.length);
        c.halos.forEach((h, i) => { const m = new THREE.Matrix4().compose(_v1.set(h[0], this.baseHeight(h[0], h[2]) + 0.03, h[2] + 0), new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI / 2, 0, 0)), _v2.set(h[4] * 1.4, h[4] * 3.2, 1)); refl.setMatrixAt(i, m); refl.setColorAt(i, col.set(h[3])); });
        refl.computeBoundingSphere(); c.group.add(refl);
      }
      Game.scene.add(c.group);
    }
    LightPool.anchors = this.neon;
  },
  updateCulling() {
    const cam = Game.camera.position, vd = Settings.viewDist + CHUNK * 0.75;
    for (const c of this.chunks.values()) c.group.visible = dist2(cam.x, cam.z, c.cx, c.cz) < vd * vd;
    const night = SHARED_UNI.uNight.value;
    if (this.haloMat) { this.haloMat.size = 3.5; this.haloMat.opacity = 0.25 + night * 0.75; }
    if (this.reflMat) this.reflMat.opacity = Sky.wet * (0.25 + night * 0.65);
    for (const d of this.dynamic) d(Game.dt);
  },
  // ---------------------------------------------------------- yardımcı: ağ (mesh) ekle
  mesh(geo, mat, x, y, z, sx = 1, sy = 1, sz = 1, parent = Game.scene, ry = 0) {
    const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.scale.set(sx, sy, sz); m.rotation.y = ry; m.castShadow = true; m.receiveShadow = true; parent.add(m); return m;
  },
  block(x, y, z, w, h, d, color, solid = true, parent) { const m = this.mesh(Geo.boxB, Mat.plastic(color), x, y, z, w, h, d, parent); if (solid) this.addBox(x - w / 2, x + w / 2, z - d / 2, z + d / 2, y, y + h); return m; },
  sign(text, x, y, z, w, h, color, ry = 0, parent = Game.scene) {
    const c = document.createElement('canvas'); c.width = 512; c.height = 128; const g = c.getContext('2d');
    g.fillStyle = 'rgba(10,4,30,0.92)'; g.fillRect(0, 0, 512, 128);
    g.strokeStyle = color; g.lineWidth = 8; g.strokeRect(6, 6, 500, 116);
    g.font = '900 64px Segoe UI, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.shadowColor = color; g.shadowBlur = 24; g.fillStyle = '#ffffff'; g.fillText(text, 256, 68); g.fillStyle = color; g.fillText(text, 256, 66);
    const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
    const m = new THREE.Mesh(Geo.plane, new THREE.MeshBasicMaterial({ map: t, toneMapped: false, side: THREE.DoubleSide }));
    m.position.set(x, y, z); m.scale.set(w, h, 1); m.rotation.y = ry; parent.add(m);
    this.neon.push({ x, y, z, c: color }); this.addHalo(x, y, z, color, w * 0.9);
    return m;
  },
  addInteract(o) { this.interact.push(o); return o; },
  // ---------------------------------------------------------- inşa
  build(progress) {
    const R = this.rng;
    // Su
    const water = new THREE.Mesh(new THREE.PlaneGeometry(4000, 4000, 1, 1), Mat.water());
    water.rotation.x = -Math.PI / 2; water.position.y = WATER_Y; water.receiveShadow = true; Game.scene.add(water); this.water = water;
    // Kara plakaları
    for (const r of this.land) {
      const w = r.x1 - r.x0, d = r.z1 - r.z0, top = r.h, th = r.bridge ? 1.2 : 4;
      const m = new THREE.Mesh(Geo.boxB, r.bridge ? Mat.plastic('#6a6478') : Mat.ground());
      m.position.set((r.x0 + r.x1) / 2, top - th, (r.z0 + r.z1) / 2); m.scale.set(w, th, d); m.receiveShadow = true; Game.scene.add(m);
      if (r.bridge) { // korkuluklar + neon
        const along = w > d; const len = along ? w : d;
        for (const s of [-1, 1]) {
          const rx = along ? (r.x0 + r.x1) / 2 : (s < 0 ? r.x0 : r.x1), rz = along ? (s < 0 ? r.z0 : r.z1) : (r.z0 + r.z1) / 2;
          this.block(rx, top, rz, along ? len : 0.5, 1.1, along ? 0.5 : len, '#d8d0e8', true);
          for (let k = 0; k <= len; k += 12) this.addNeon(along ? r.x0 + k : rx, top + 1.1, along ? rz : r.z0 + k, 0.5, 0.25, 0.5, r.east ? '#20f0ff' : '#ff2fd6');
        }
        if (r.east) { // köprü kulesi kabloları
          for (const px of [418, 452]) for (const pz of [231, 249]) this.addCyl(px, top, pz, 0.7, 26, '#d8d0e8', true);
          this.addNeon(435, top + 26, 231, 34, 0.5, 0.5, '#20f0ff'); this.addNeon(435, top + 26, 249, 34, 0.5, 0.5, '#20f0ff');
        }
      }
    }
    // Kanal duvarı
    this.addProp(-120, -3, 0, 60, 2.2, 1120, '#3a3550');
    this.buildMountain();
    progress && progress(0.2);
    // Şehir blokları
    const reserved = this.reservedBlocks();
    for (let i = -7; i <= 4; i++) for (let j = -7; j <= 6; j++) {
      const cx = 80 * i + 40, cz = 80 * j + 40;
      if (i === -2) continue; // kanal sütunu
      if (cx < -150 && cz < -160) continue; // dağ
      if (!this.landAt(cx, cz) || this.landAt(cx, cz).island) continue;
      const key = i + ',' + j;
      if (reserved[key]) { reserved[key].call(this, cx, cz); continue; }
      const dist = districtAt(cx, cz).id;
      if (dist === 'Harbor_District' && j >= 6) { this.dockYard(cx, cz); continue; }
      this.cityBlock(cx, cz, dist);
    }
    progress && progress(0.5);
    this.streetFurniture();
    this.buildIsland();
    this.buildTechTower();
    this.buildPiers();
    this.buildRoadGraph();
    progress && progress(0.7);
    this.finalizeChunks();
    progress && progress(0.8);
  },
  palettes: {
    Neon_Boulevard: ['#7a5cff', '#ff2fd6', '#20c9e0', '#2a1f5a', '#ff7ad9', '#3b2a8a', '#f4f0ff'],
    Tech_Tower: ['#c8d4e8', '#8aa0c8', '#2a3a6b', '#e8f0ff', '#5a6c9a', '#1d2a4a'],
    Old_Bazaar: ['#e8b48f', '#d9a21b', '#c9603a', '#f2e6c8', '#8a3a2a', '#6fa86a'],
    Harbor_District: ['#c9603a', '#3a6fa8', '#d9a21b', '#5a5f6a', '#8a2a2a', '#2f7a6a'],
    East_Res: ['#ffd2a0', '#a0e8c8', '#ffb0c8', '#c8d4ff', '#f4f4e8', '#ffe08a']
  },
  cityBlock(cx, cz, dist) {
    const R = this.rng, pal = this.palettes[dist] || this.palettes.Neon_Boulevard;
    const hr = { Neon_Boulevard: [18, 64], Tech_Tower: [36, 110], Old_Bazaar: [7, 16], Harbor_District: [9, 22], East_Res: [10, 30] }[dist] || [10, 30];
    const layout = R();
    const lots = [];
    if (dist === 'Old_Bazaar') { // dar sokaklı çarşı: 3x3 küçük dükkân
      for (let a = -1; a <= 1; a++) for (let b = -1; b <= 1; b++) if (R() > 0.15) lots.push([cx + a * 20, cz + b * 20, 15, 15]);
    } else if (layout < 0.25) lots.push([cx, cz, 50, 50]);
    else if (layout < 0.6) { lots.push([cx - 14, cz, 24, 52], [cx + 14, cz, 24, 52]); }
    else { for (const a of [-1, 1]) for (const b of [-1, 1]) lots.push([cx + a * 14, cz + b * 14, 24, 24]); }
    for (const [x, z, w, d] of lots) {
      const h = Math.round(lerp(hr[0], hr[1], Math.pow(R(), 1.4)) / 3.4) * 3.4 + 1.2;
      const c = pal[Math.floor(R() * pal.length)];
      this.addBuilding(x, z, w, d, h, c);
      // çatı detayları
      if (R() > 0.4) this.addProp(x + rand(-w / 4, w / 4), h, z + rand(-d / 4, d / 4), 3, 2, 3, '#b8b8c8', true);
      if (R() > 0.6) this.addCyl(x - w / 4, h, z - d / 4, 1.4, 3, '#8a6a4a', true);
      this.addProp(x, h, z, w + 0.6, 0.6, d + 0.6, '#ffffff'); // korkuluk kenarı (beyaz plastik)
      // neon tabelalar ve şeritler (yola bakan cepheler)
      if (dist === 'Neon_Boulevard' || dist === 'Tech_Tower' || R() > 0.6) {
        const nc = pick(['#ff2fd6', '#20f0ff', '#b6ff3b', '#ffb020', '#ff3b6b', '#7a5cff']);
        const face = Math.floor(R() * 4);
        const sy = rand(4, Math.min(h - 2, 22));
        if (face === 0) this.addNeon(x, sy, z + d / 2 + 0.3, w * 0.6, 1.6, 0.3, nc);
        else if (face === 1) this.addNeon(x, sy, z - d / 2 - 0.3, w * 0.6, 1.6, 0.3, nc);
        else if (face === 2) this.addNeon(x + w / 2 + 0.3, sy, z, 0.3, 1.6, d * 0.6, nc);
        else this.addNeon(x - w / 2 - 0.3, sy, z, 0.3, 1.6, d * 0.6, nc);
        if (dist === 'Neon_Boulevard' && R() > 0.5) this.addNeon(x + w / 2 + 0.25, 3, z + d / 2 + 0.25, 0.25, h - 4, 0.25, nc, false);
      }
      // saçak (yağmurda sivillerin sığınağı)
      if (h < 40 && R() > 0.35) {
        const sc = pick(['#ff3b6b', '#20c9b0', '#ffd23b', '#7a5cff', '#f4f4f4']);
        this.addProp(x, 3.2, z + d / 2 + 1.2, w * 0.7, 0.25, 2.4, sc);
        this.shelters.push([x, z + d / 2 + 1.2]);
      }
    }
  },
  dockYard(cx, cz) {
    const R = this.rng;
    for (let a = -2; a <= 2; a++) for (let b = -1; b <= 1; b++) {
      if (R() < 0.35) continue;
      const stack = 1 + Math.floor(R() * 3), c = pick(['#c9603a', '#3a6fa8', '#d9a21b', '#2f7a6a', '#8a2a2a', '#f4f4f4']);
      const x = cx + a * 11, z = cz + b * 16;
      for (let s = 0; s < stack; s++) this.addProp(x, s * 2.6, z, 6, 2.6, 12.2, s ? pick(['#c9603a', '#3a6fa8', '#d9a21b']) : c, true);
    }
    // vinç
    const x = cx + 22, z = cz + 24;
    this.addProp(x - 3, 0, z, 1, 34, 1, '#ffd23b', true); this.addProp(x + 3, 0, z, 1, 34, 1, '#ffd23b', true);
    this.addProp(x, 34, z - 8, 2, 1.5, 34, '#ffd23b'); this.addNeon(x, 35.6, z + 8, 0.6, 0.6, 0.6, '#ff3b3b');
  },
  streetFurniture() {
    const R = this.rng;
    // sokak lambaları ve ağaçlar
    for (let x = -560; x <= 400; x += 80) for (let z = -560; z <= 560; z += 32) {
      if (this.isMountain(x, z) || !this.landAt(x + 9, z) || this.landAt(x + 9, z).bridge) continue;
      const d = districtAt(x, z).id;
      const lc = d === 'Neon_Boulevard' ? (z % 64 === 0 ? '#ff2fd6' : '#20f0ff') : '#ffd28a';
      this.lamp(x + 8.6, z, -1, 0, lc, Math.abs(z) % 96 === 0);
      if ((d === 'East_Res' || d === 'Old_Bazaar') && R() > 0.5) this.tree(x - 8.6, z + 16);
      if ((d === 'Neon_Boulevard' || d === 'East_Res') && R() > 0.7) this.bench(x + 9.2, z + 12, Math.PI / 2);
    }
    for (let z = -560; z <= 560; z += 80) for (let x = -560; x <= 400; x += 36) {
      if (this.isMountain(x, z) || !this.landAt(x, z + 9) || this.landAt(x, z + 9).bridge) continue;
      const lc = districtAt(x, z).id === 'Neon_Boulevard' ? '#ff7ad9' : '#ffd28a';
      this.lamp(x, z + 8.6, 0, -1, lc, false);
    }
    // Neon Bulvar ana cadde kemerleri
    for (let z = -520; z <= 520; z += 80) {
      this.addProp(-8, 0, z + 40, 0.6, 9, 0.6, '#2a1f5a', true); this.addProp(8, 0, z + 40, 0.6, 9, 0.6, '#2a1f5a', true);
      this.addNeon(0, 9, z + 40, 16.6, 0.5, 0.5, z % 160 === 0 ? '#ff2fd6' : '#20f0ff');
    }
  },
  buildMountain() {
    const m = this.mtn, W = m.x1 - m.x0, D = m.z1 - m.z0, seg = Settings.quality === 'low' ? 56 : 80;
    const g = new THREE.PlaneGeometry(W, D, seg, seg); g.rotateX(-Math.PI / 2);
    const pos = g.attributes.position, cols = new Float32Array(pos.count * 3), c = new THREE.Color();
    const path = [[-300, -160], [-330, -230], [-300, -290], [-360, -310], [-345, -360], [-410, -300], [-345, -360], [-420, -420], [-470, -470]];
    const dPath = (x, z) => { let best = 1e9; for (let i = 0; i < path.length - 1; i++) { const [ax, az] = path[i], [bx, bz] = path[i + 1]; const vx = bx - ax, vz = bz - az; const t = clamp(((x - ax) * vx + (z - az) * vz) / (vx * vx + vz * vz), 0, 1); const d = Math.hypot(x - (ax + vx * t), z - (az + vz * t)); if (d < best) best = d; } return best; };
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i) + (m.x0 + m.x1) / 2, z = pos.getZ(i) + (m.z0 + m.z1) / 2;
      const h = this.terrainH(x, z); pos.setY(i, h);
      if (dPath(x, z) < 4.5) c.set('#c9a27a'); else if (h > 80) c.set('#f4f8ff'); else if (h > 50) c.set('#8a8a9a'); else c.set(h > 25 ? '#4a9a5a' : '#5ab86a');
      c.offsetHSL(0, 0, (Math.sin(x * 0.7) * Math.cos(z * 0.6)) * 0.03);
      cols.set([c.r, c.g, c.b], i * 3);
    }
    g.setAttribute('color', new THREE.BufferAttribute(cols, 3)); g.computeVertexNormals();
    const mesh = new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.55, metalness: 0, flatShading: true }));
    mesh.position.set((m.x0 + m.x1) / 2, 0, (m.z0 + m.z1) / 2); mesh.receiveShadow = true; mesh.castShadow = false; Game.scene.add(mesh);
    // Patika boyunca kapı kemerleri ve fenerler
    for (let i = 0; i < 5; i++) {
      const [ax, az] = path[i], [bx, bz] = path[i + 1]; const x = (ax + bx) / 2, z = (az + bz) / 2, h = this.terrainH(x, z);
      this.addProp(x - 3, h, z, 0.6, 5, 0.6, '#ff3b3b'); this.addProp(x + 3, h, z, 0.6, 5, 0.6, '#ff3b3b'); this.addProp(x, h + 5, z, 8, 0.7, 0.9, '#1a1a1a');
      this.addNeon(x, h + 4.2, z, 0.5, 0.5, 0.5, '#ffb020');
    }
    // Manastır (zirve)
    const mx = m.cx, mz = m.cz, mh = this.terrainH(mx, mz);
    this.block(mx, mh - 2, mz, 34, 2.4, 34, '#d8d0b8');
    for (let t = 0; t < 3; t++) {
      const s = 16 - t * 4.5, y = mh + 0.4 + t * 6;
      this.block(mx, y, mz, s, 5, s, t % 2 ? '#f4f0e8' : '#c9302a', t === 0);
      const roof = this.mesh(Geo.cone, Mat.plastic('#2a2a3a'), mx, y + 5.6, mz, s * 1.6, 2.2, s * 1.6); roof.rotation.y = Math.PI / 4;
      this.addNeon(mx, y + 4.6, mz + s / 2 + 0.1, s * 0.8, 0.3, 0.2, '#ffb020');
    }
    this.sign('MANASTIR', mx, mh + 3.4, mz + 8.2, 7, 1.8, '#ffb020');
    // Gizli bakış çıkıntısı
    const px = -470, pz = -470, ph = this.terrainH(px, pz);
    this.block(px, ph - 0.5, pz, 9, 1, 9, '#8a8a9a');
    this.addNeon(px + 4, ph + 0.5, pz + 4, 0.3, 1.2, 0.3, '#20f0ff');
  },
  buildPiers() {
    for (const px of [-480, -360, -240]) for (let z = 566; z <= 636; z += 14) { this.addCyl(px - 7, -3, z, 0.4, 4.2, '#5a4030'); this.addCyl(px + 7, -3, z, 0.4, 4.2, '#5a4030'); this.addNeon(px + 7, 1.3, z, 0.3, 0.3, 0.3, '#ffd28a', z % 28 === 0); }
    // tekneler
    for (const [x, z, c] of [[-420, 610, '#f4f4f4'], [-300, 620, '#ff3b6b'], [-200, 600, '#3bb0ff']]) {
      this.addProp(x, -1.3, z, 5, 1.6, 12, c); this.addProp(x, 0.3, z + 2, 3.6, 1.8, 4, '#e8e8f0');
    }
  },
  buildIsland() {
    // duvarlar, gözetleme kuleleri, hapishane bloğu, yasak bölge işareti
    const x0 = 466, x1 = 614, z0 = 166, z1 = 394;
    this.block((x0 + x1) / 2, 0, z0, x1 - x0, 5, 1.5, '#4a4f3a'); this.block((x0 + x1) / 2, 0, z1, x1 - x0, 5, 1.5, '#4a4f3a');
    this.block(x1, 0, (z0 + z1) / 2, 1.5, 5, z1 - z0, '#4a4f3a');
    this.block(x0, 0, (z0 + 225) / 2, 1.5, 5, 225 - z0, '#4a4f3a'); this.block(x0, 0, (255 + z1) / 2, 1.5, 5, z1 - 255, '#4a4f3a');
    for (const [x, z] of [[x0, z0], [x1, z0], [x0, z1], [x1, z1], [x0, 222], [x0, 258]]) {
      this.block(x, 0, z, 4, 12, 4, '#33382a'); this.addProp(x, 12, z, 6, 0.6, 6, '#222');
      this.addNeon(x, 12.6, z, 0.6, 0.6, 0.6, '#ff3b3b');
    }
    this.block(560, 0, 300, 40, 14, 26, '#6a6f5a'); this.block(560, 14, 300, 42, 0.8, 28, '#33382a');
    this.addNeon(560, 10, 313.2, 30, 0.5, 0.3, '#ff3b3b');
    this.sign('YASAK BÖLGE', 470, 7, 240, 10, 2.2, '#ff3b3b', Math.PI / 2);
    this.block(520, 0, 200, 16, 8, 14, '#5a5f4a'); this.block(600, 0, 360, 12, 6, 18, '#5a5f4a');
  },
  buildTechTower() {
    const [x, z] = [280, -280], W = 44, H = 172;
    this.addBuilding(x, z, W, W, H, '#c8d4e8');
    for (let y = 10; y < H; y += 20) this.addNeon(x, y, z + W / 2 + 0.3, W, 0.4, 0.3, y % 40 === 10 ? '#20f0ff' : '#ff2fd6', y < 60);
    this.addNeon(x, H, z, W + 1, 1.2, W + 1, '#20f0ff');
    // teraslar (90 ve 140) + çatı
    for (const ty of [90, 140]) {
      this.block(x, ty - 1, z + W / 2 + 13, W, 1, 26, '#e8f0ff');
      this.block(x, ty, z + W / 2 + 26, W, 1.2, 0.6, '#ffffff'); this.block(x - W / 2, ty, z + W / 2 + 13, 0.6, 1.2, 26, '#ffffff'); this.block(x + W / 2, ty, z + W / 2 + 13, 0.6, 1.2, 26, '#ffffff');
      this.addNeon(x, ty + 1.2, z + W / 2 + 26, W, 0.2, 0.2, '#ff2fd6');
    }
    this.block(x, H, z + W / 2, W, 1.4, 0.6, '#ffffff'); this.block(x, H, z - W / 2, W, 1.4, 0.6, '#ffffff');
    this.block(x - W / 2, H, z, 0.6, 1.4, W, '#ffffff'); this.block(x + W / 2, H, z, 0.6, 1.4, W, '#ffffff');
    this.addCyl(x, H, z, 3, 18, '#8aa0c8', true); this.addNeon(x, H + 18, z, 1.4, 1.4, 1.4, '#ff3b3b');
    // çekirdek kaidesi (final)
    const core = this.mesh(Geo.sphere, Mat.plastic('#ff2fd6', { em: '#ff2fd6', emi: 2.5 }), x, H + 6, z - 14, 3, 3, 3);
    this.coreMesh = core; this.dynamic.push((dt) => { core.rotation.y += dt; core.position.y = H + 6 + Math.sin(Game.t * 2) * 0.4; });
    this.sign('NEO TEKNOLOJİ', x, 14, z + W / 2 + 0.5, 22, 4, '#20f0ff');
    // ön meydan
    this.addProp(x, 0, z + W / 2 + 18, 30, 0.2, 24, '#e8f0ff');
    this.addInteract({ id: 'elevator', x, z: z + W / 2 + 3, r: 3.5, label: 'Asansör', cond: () => S.completed.m22 || Missions.active?.id === 'm22', action: () => UI.elevatorMenu() });
  },
  // ---------------------------------------------------------- simge yapılar
  reservedBlocks() {
    const W = this;
    const shop = (cx, cz, w, d, h, col, text, tc, face = 1) => { W.addBuilding(cx, cz, w, d, h, col); W.sign(text, cx, Math.min(h - 1.5, 6.5), cz + face * (d / 2 + 0.2), Math.min(w * 0.8, 16), 2.6, tc); W.addProp(cx, 3.2, cz + face * (d / 2 + 1.4), w * 0.8, 0.3, 2.8, tc); W.shelters.push([cx, cz + face * (d / 2 + 1.4)]); };
    return {
      // Çay evi (Eski Çarşı)
      '-5,-1': function (cx, cz) {
        this.block(cx, 0, cz, 22, 6, 18, '#8a3a2a'); this.block(cx, 6, cz, 24, 0.6, 20, '#2a1a1a');
        const r = this.mesh(Geo.cone, Mat.plastic('#2a2a3a'), cx, 6.6, cz, 30, 3.2, 26); r.rotation.y = Math.PI / 4;
        this.sign('ÇAY EVİ', cx, 4.6, cz + 9.2, 8, 1.8, '#ffb020');
        for (let k = -2; k <= 2; k++) { this.addNeon(cx + k * 4, 5, cz + 10.4, 0.8, 1, 0.8, '#ff3b3b'); }
        this.addInteract({ id: 'teahouse', x: cx, z: cz + 12, r: 4, label: 'Çay Evi (Hikmet Usta)', action: () => UI.npcTalk('Mentor_Master') });
      },
      // Çarşı meydanı
      '-4,0': function (cx, cz) {
        for (let a = -2; a <= 2; a++) for (let b = -2; b <= 2; b++) if ((a + b) % 2 === 0 && !(a === 0 && b === 0)) {
          const c = pick(['#ff3b6b', '#ffd23b', '#20c9b0', '#7a5cff', '#ff8a1f']);
          this.addProp(cx + a * 10, 0, cz + b * 10, 4, 1.1, 3, '#c9a27a', true); this.addProp(cx + a * 10, 2.6, cz + b * 10, 5, 0.25, 4, c);
          for (const s of [-1, 1]) this.addProp(cx + a * 10 + s * 2.3, 0, cz + b * 10 + 1.8, 0.2, 2.6, 0.2, '#6b4a2a');
          this.shelters.push([cx + a * 10, cz + b * 10 + 2.5]);
        }
        this.addCyl(cx, 0, cz, 3, 1, '#d8d0b8', true); this.addCyl(cx, 1, cz, 0.6, 3, '#d8d0b8'); this.addNeon(cx, 4, cz, 1, 1, 1, '#20f0ff');
      },
      // İlk güvenli ev (Liman üstü)
      '-4,4': function (cx, cz) { W.safehouse('harborSafe', cx, cz, '#3a6fa8'); },
      // Kartel sığınağı
      '-7,4': function (cx, cz) { this.addBuilding(cx, cz - 14, 44, 24, 12, '#3a1f5a'); this.addNeon(cx, 8, cz - 1.7, 30, 0.6, 0.3, '#b6ff3b'); this.sign('KANCA LOJİSTİK', cx, 10, cz - 1.6, 12, 2, '#b6ff3b'); for (let k = 0; k < 4; k++) this.addProp(cx - 15 + k * 10, 0, cz + 16, 6, 2.6, 6, '#5a2a8a', true); },
      // Kartel deposu
      '-6,5': function (cx, cz) { this.addBuilding(cx, cz - 18, 50, 16, 14, '#c9603a'); this.addBuilding(cx + 18, cz + 14, 14, 26, 10, '#8a2a2a'); this.sign('DEPO 7', cx, 10, cz - 9.6, 8, 2, '#ffb020'); for (let k = 0; k < 3; k++) this.addProp(cx - 18 + k * 7, 0, cz + 26, 6, 2.6, 12, pick(['#3a6fa8', '#d9a21b']), true); },
      // Liman kapısı
      '-4,5': function (cx, cz) { this.addBuilding(cx - 16, cz - 10, 20, 30, 14, '#5a5f6a'); this.addProp(cx + 20, 0, cz + 30, 1, 6, 1, '#ffd23b', true); this.addProp(cx + 2, 6, cz + 30, 36, 1.2, 1, '#ffd23b'); this.sign('LİMAN', cx + 2, 7.6, cz + 30.6, 8, 1.6, '#ffd23b'); this.addProp(cx - 16, 0, cz + 30, 1, 6, 1, '#ffd23b', true); },
      // Silahçı
      '-3,1': function (cx, cz) { shop(cx, cz, 26, 28, 9, '#5a5f6a', 'DEMİRCİ SİLAH', '#ff8a1f'); W.addInteract({ id: 'weaponShop', x: cx, z: cz + 16, r: 4, label: 'Silah & Ekipman Dükkânı', action: () => UI.weaponShop() }); },
      // Hurda Garaj (modifiye)
      '-3,3': function (cx, cz) {
        this.block(cx, 0, cz - 8, 34, 8, 2, '#6a6f7a'); this.block(cx - 17, 0, cz + 4, 2, 8, 26, '#6a6f7a'); this.block(cx + 17, 0, cz + 4, 2, 8, 26, '#6a6f7a'); this.block(cx, 8, cz + 4, 36, 1, 28, '#3a3a44');
        this.sign('HURDA GARAJ', cx, 6.5, cz + 17.6, 14, 2.4, '#20f0ff');
        this.addNeon(cx, 7.4, cz + 17.6, 34, 0.3, 0.3, '#ff2fd6');
        W.addInteract({ id: 'garage', x: cx, z: cz + 10, r: 7, label: 'Hurda Garaj — Modifiye', cond: () => S.flags.modShop, action: () => UI.modShop() });
        W.addInteract({ id: 'garage2', x: cx, z: cz + 10, r: 7, label: 'Garaj — Araç çağır', cond: () => S.vehicles.length > 0 && !S.flags.modShop, action: () => UI.garageMenu() });
      },
      // Erişte dükkânı
      '-1,1': function (cx, cz) {
        shop(cx, cz, 30, 40, 10, '#c9302a', 'ŞEF NODA ERİŞTE', '#ffd23b');
        for (let k = -2; k <= 2; k++) this.addNeon(cx + k * 5, 5.2, cz + 22, 1, 1.2, 1, '#ff3b3b');
        W.addInteract({ id: 'noodle', x: cx, z: cz + 22, r: 4, label: 'Şef Noda', action: () => UI.npcTalk('NPC_NoodleChef') });
        W.addInteract({ id: 'backroom', x: cx, z: cz - 21, r: 3, label: 'Paslı arka kapı', cond: () => Sky.isNight(), action: () => Eggs.backroom() });
        this.block(cx, 0, cz - 20.6, 2.2, 3.4, 0.6, '#3a2a2a', false);
        this.addNeon(cx, 3.6, cz - 20.6, 0.4, 0.4, 0.2, '#7a5cff');
      },
      // Neon Smoothie dükkânı (çatıda dönen dev neon ananas)
      '0,0': function (cx, cz) {
        this.block(cx, 0, cz, 30, 8, 24, '#7a5cff'); this.block(cx, 8, cz, 32, 0.8, 26, '#b6ff3b');
        this.sign('NEON SMOOTHIE', cx, 6, cz + 12.2, 16, 2.6, '#b6ff3b');
        this.addProp(cx, 3.2, cz + 14, 26, 0.3, 4, '#ff7ad9'); W.shelters.push([cx, cz + 14]);
        const g = new THREE.Group(); g.position.set(cx, 8.8, cz); Game.scene.add(g);
        const body = this.mesh(Geo.sphere, Mat.plastic('#ffc21b'), 0, 4.2, 0, 6, 8, 6, g);
        for (let k = 0; k < 6; k++) { const leaf = this.mesh(Geo.cone, Mat.plastic('#2fd67a'), Math.cos(k) * 1.2, 9, Math.sin(k) * 1.2, 1.4, 4.2, 0.6, g); leaf.rotation.z = Math.cos(k) * 0.5; leaf.rotation.x = Math.sin(k) * 0.5; }
        for (let k = 0; k < 4; k++) { const ring = this.mesh(Geo.torus, Mat.neon(k % 2 ? '#ff2fd6' : '#20f0ff'), 0, 1.8 + k * 1.7, 0, 3.1 - Math.abs(k - 1.5) * 0.5, 3.1 - Math.abs(k - 1.5) * 0.5, 1, g); ring.rotation.x = Math.PI / 2; ring.castShadow = false; }
        this.mesh(Geo.cyl, Mat.plastic('#ff7ad9'), 0, 0.5, 0, 5, 1, 5, g);
        this.neon.push({ x: cx, y: 14, z: cz, c: '#ffc21b' }); this.addHalo(cx, 13, cz, '#ffc21b', 14);
        W.dynamic.push((dt) => { g.rotation.y += dt * 0.6; body.scale.y = 8 + Math.sin(Game.t * 3) * 0.25; });
        for (const s of [-1, 1]) { this.addProp(cx + s * 8, 0, cz + 18, 3, 1.1, 3, '#f4f4f4', true); this.addCyl(cx + s * 8, 1.1, cz + 18, 0.1, 2.4, '#f4f4f4'); this.addCone(cx + s * 8, 3.4, cz + 18, 2.6, 1.2, '#ff2fd6'); }
        W.addInteract({ id: 'smoothie', x: cx, z: cz + 16, r: 5, label: 'Neon Smoothie', action: () => UI.smoothieMenu() });
      },
      // Turbo Dojo
      '1,-1': function (cx, cz) { shop(cx, cz, 34, 36, 12, '#ff2fd6', 'TURBO DOJO', '#ffd23b'); W.addInteract({ id: 'dojo', x: cx, z: cz + 20, r: 4, label: 'Turbo Tarık', action: () => UI.npcTalk('NPC_DojoGuy') }); },
      // Spor salonu
      '0,3': function (cx, cz) { shop(cx, cz, 40, 36, 10, '#3a3a44', 'DEMİR SALON', '#ff3b3b'); W.addInteract({ id: 'gym', x: cx, z: cz + 20, r: 4, label: 'Spor Salonu', action: () => Missions.tryStartAt('gym') }); },
      // Restoran
      '1,2': function (cx, cz) { shop(cx, cz, 36, 36, 9, '#f2e6c8', 'LOKANTA NEON', '#ff7ad9'); for (const s of [-1, 1]) this.addProp(cx + s * 10, 0, cz + 22, 3, 1, 3, '#f4f4f4', true); },
      // Polis merkezi
      '2,0': function (cx, cz) { shop(cx, cz, 44, 40, 18, '#1f3a7a', 'EMNİYET', '#3bb0ff'); this.addNeon(cx - 8, 18, cz, 3, 0.8, 1, '#ff3b3b'); this.addNeon(cx + 8, 18, cz, 3, 0.8, 1, '#3bb0ff'); },
      // Neon güvenli ev
      '-1,-4': function (cx, cz) { W.safehouse('neonSafe', cx, cz, '#7a5cff'); },
      // Doğu güvenli ev
      '3,4': function (cx, cz) { W.safehouse('eastSafe', cx, cz, '#2fd67a'); },
      // Hastane
      '1,4': function (cx, cz) { shop(cx, cz, 40, 40, 24, '#f4f4f4', 'HASTANE', '#ff3b3b'); },
      // Teknoloji kulesi bloğu (kule ayrıca)
      '3,-4': function () { },
      // Aktarıcılar
      '2,-3': function (cx, cz) { W.relay(cx, cz); },
      '4,-2': function (cx, cz) { W.relay(cx, cz); }
    };
  },
  relay(cx, cz) { this.block(cx, 0, cz, 10, 1, 10, '#2a3a6b'); this.addCyl(cx, 1, cz, 2, 10, '#8aa0c8', true); for (let k = 0; k < 4; k++) this.addNeon(cx, 2.5 + k * 2.2, cz, 4.4, 0.25, 4.4, '#ffd23b', k === 2); },
  safehouse(id, cx, cz, col) {
    this.block(cx, 0, cz - 6, 26, 9, 20, col); this.block(cx, 9, cz - 6, 28, 0.8, 22, '#2a2a3a');
    this.block(cx - 6, 0, cz + 4.4, 2.4, 3.6, 0.4, '#3a2a1a', false);
    this.sign('GÜVENLİ EV', cx + 4, 6.6, cz + 4.3, 8, 1.6, '#b6ff3b');
    this.addNeon(cx - 6, 3.8, cz + 4.6, 0.4, 0.4, 0.4, '#b6ff3b');
    const [lx, lz] = LOC[id];
    this.addInteract({ id, x: lx, z: lz, r: 4, label: 'Güvenli Ev', cond: () => S.safehouses.includes(id), action: () => UI.safehouseMenu(id) });
  },
  // ---------------------------------------------------------- yol ağı (trafik/yaya)
  buildRoadGraph() {
    const ok = (x, z) => { const r = this.landAt(x, z); return r && !r.island && !this.isMountain(x, z) && !(x > -150 && x < -90 && !r.bridge); };
    const idx = new Map();
    for (let x = -560; x <= 400; x += 80) for (let z = -560; z <= 560; z += 80) if (ok(x, z)) { idx.set(x + ',' + z, this.roadNodes.length); this.roadNodes.push({ x, z, n: [] }); }
    const link = (a, b) => { this.roadNodes[a].n.push(b); this.roadNodes[b].n.push(a); this.roadEdges.push([a, b]); };
    for (const [k, i] of idx) {
      const [x, z] = k.split(',').map(Number);
      const e = idx.get((x + 80) + ',' + z), s = idx.get(x + ',' + (z + 80));
      if (e !== undefined && ok(x + 40, z) && (x + 40 < -150 || x + 40 > -90 || this.landAt(x + 40, z)?.bridge)) link(i, e);
      if (s !== undefined && ok(x, z + 40)) link(i, s);
    }
    this.roadNodes = this.roadNodes.map(n => n); // korunur
  },
  nearestNode(x, z) { let b = 0, bd = 1e12; this.roadNodes.forEach((n, i) => { const d = dist2(n.x, n.z, x, z); if (d < bd && n.n.length) { bd = d; b = i; } }); return b; },
  nearestShelter(x, z) { let b = null, bd = 1e12; for (const s of this.shelters) { const d = dist2(s[0], s[1], x, z); if (d < bd) { bd = d; b = s; } } return bd < 60 * 60 ? b : null; }
};
