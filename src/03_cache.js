// ============================================================================
//  ÖNBELLEK (IndexedDB) · SUPABASE (REST) · VARLIK YÖNETİCİSİ · OTOMATİK RİG
//  Her varlık: {id, slot, kind, fmt, version, updatedAt, url, source}
//  Açılışta: manifest ↔ IndexedDB kaydı karşılaştırılır; sürüm/damga aynıysa
//  blob indirilmeden doğrudan IndexedDB'den yüklenir, rig meta da önbellekten gelir.
// ============================================================================
const AssetCache = {
  db: null,
  open() {
    if (this.db) return Promise.resolve(this.db);
    return new Promise((res) => {
      if (!window.indexedDB) { res(null); return; }
      const rq = indexedDB.open('ng_cache', 2);
      rq.onupgradeneeded = () => {
        const db = rq.result;
        if (!db.objectStoreNames.contains('assets')) db.createObjectStore('assets', { keyPath: 'id' });
      };
      rq.onsuccess = () => { this.db = rq.result; res(this.db); };
      rq.onerror = () => { console.warn('IndexedDB açılamadı'); res(null); };
    });
  },
  async tx(mode, fn) {
    const db = await this.open(); if (!db) return null;
    return new Promise((res, rej) => {
      const t = db.transaction('assets', mode); const st = t.objectStore('assets');
      const r = fn(st); t.oncomplete = () => res(r && r.result !== undefined ? r.result : r); t.onerror = () => rej(t.error);
    });
  },
  get(id) { return this.tx('readonly', st => st.get(id)); },
  put(rec) { return this.tx('readwrite', st => st.put(rec)); },
  del(id) { return this.tx('readwrite', st => st.delete(id)); },
  clear() { return this.tx('readwrite', st => st.clear()); },
  all() { return this.tx('readonly', st => st.getAll()); }
};

// ---------------------------------------------------------------- Supabase (SDK'sız REST)
const SB_KEY = 'ng_supabase_v1';
const Supa = {
  cfg: Object.assign({ url: '', key: '', bucket: 'ng-assets', table: 'ng_assets' }, JSON.parse(localStorage.getItem(SB_KEY) || '{}')),
  save() { localStorage.setItem(SB_KEY, JSON.stringify(this.cfg)); },
  ok() { return !!(this.cfg.url && this.cfg.key); },
  h(extra) { return Object.assign({ apikey: this.cfg.key, Authorization: 'Bearer ' + this.cfg.key }, extra || {}); },
  base() { return this.cfg.url.replace(/\/+$/, ''); },
  async list() {
    const r = await fetch(`${this.base()}/rest/v1/${this.cfg.table}?select=*`, { headers: this.h() });
    if (!r.ok) throw new Error('Supabase liste hatası ' + r.status);
    return r.json();
  },
  async upload(path, blob, ct) {
    const r = await fetch(`${this.base()}/storage/v1/object/${this.cfg.bucket}/${encodeURI(path)}`, { method: 'POST', headers: this.h({ 'x-upsert': 'true', 'Content-Type': ct || 'application/octet-stream' }), body: blob });
    if (!r.ok) throw new Error('Supabase yükleme hatası ' + r.status + ' ' + (await r.text()));
    return this.publicUrl(path);
  },
  publicUrl(path) { return `${this.base()}/storage/v1/object/public/${this.cfg.bucket}/${encodeURI(path)}`; },
  async upsert(row) {
    const r = await fetch(`${this.base()}/rest/v1/${this.cfg.table}`, { method: 'POST', headers: this.h({ 'Content-Type': 'application/json', Prefer: 'resolution=merge-duplicates,return=representation' }), body: JSON.stringify(row) });
    if (!r.ok) throw new Error('Supabase satır hatası ' + r.status + ' ' + (await r.text()));
    return r.json();
  }
};

// ---------------------------------------------------------------- Otomatik rig
// Çok parçalı modellerde arm_R, arm_L, leg_R, leg_L, head, torso node'larını bulur,
// eklem noktalarına pivot grupları kurar ve parçaları dünya dönüşümünü koruyarak bağlar.
const RIG_PATTERNS = {
  head: /^(head|kafa|bas)/i, torso: /^(torso|body|chest|govde)/i,
  arm_L: /^(arm|kol)[_.\-\s]?l(eft)?\b|^l(eft)?[_.\-\s]?arm/i, arm_R: /^(arm|kol)[_.\-\s]?r(ight)?\b|^r(ight)?[_.\-\s]?arm/i,
  leg_L: /^(leg|bacak)[_.\-\s]?l(eft)?\b|^l(eft)?[_.\-\s]?leg/i, leg_R: /^(leg|bacak)[_.\-\s]?r(ight)?\b|^r(ight)?[_.\-\s]?leg/i
};
function normalizeModel(root, targetH = 2.0) {
  root.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(root);
  const size = box.getSize(new THREE.Vector3());
  const s = size.y > 0.0001 ? targetH / size.y : 1;
  const wrap = new THREE.Group();
  root.scale.multiplyScalar(s);
  root.updateMatrixWorld(true);
  const b2 = new THREE.Box3().setFromObject(root);
  const c = b2.getCenter(new THREE.Vector3());
  root.position.x -= c.x; root.position.z -= c.z; root.position.y -= b2.min.y;
  wrap.add(root);
  return wrap;
}
function autoRig(wrap, cachedMeta) {
  wrap.updateMatrixWorld(true);
  const found = {};
  wrap.traverse(n => { if (!n.name) return; for (const k in RIG_PATTERNS) if (!found[k] && RIG_PATTERNS[k].test(n.name)) found[k] = n; });
  const meta = cachedMeta || {};
  const order = ['arm_L', 'arm_R', 'leg_L', 'leg_R', 'head', 'torso'];
  for (const k of order) {
    const node = found[k]; if (!node) continue;
    let joint;
    if (meta[k]) joint = new THREE.Vector3().fromArray(meta[k]);
    else {
      const b = new THREE.Box3().setFromObject(node); const c = b.getCenter(new THREE.Vector3()); const sz = b.getSize(new THREE.Vector3());
      if (k === 'head') joint = new THREE.Vector3(c.x, b.min.y, c.z);
      else if (k === 'torso') joint = new THREE.Vector3(c.x, b.min.y + sz.y * 0.1, c.z);
      else joint = new THREE.Vector3(c.x, b.max.y - sz.y * 0.08, c.z);
      meta[k] = joint.toArray().map(v => +v.toFixed(4));
    }
    const pivot = new THREE.Group(); pivot.name = 'pivot_' + k;
    pivot.position.copy(joint); wrap.add(pivot); wrap.updateMatrixWorld(true);
    pivot.attach(node);
  }
  wrap.traverse(n => { if (n.isMesh) { n.castShadow = true; n.receiveShadow = false; } });
  return { meta, parts: Object.keys(found) };
}
function collectPivots(obj) {
  const parts = {};
  obj.traverse(n => { if (n.name && n.name.startsWith('pivot_')) parts[n.name.slice(6)] = n; });
  return parts;
}

// ---------------------------------------------------------------- Varlık yöneticisi
const MANIFEST_KEY = 'ng_asset_manifest_v1';
const AssetManager = {
  manifest: JSON.parse(localStorage.getItem(MANIFEST_KEY) || '{}'),
  templates: {},   // slot -> Object3D (riglenmiş)
  textures: {},    // slot -> Texture
  status: {},      // slot -> 'cache' | 'download' | 'error' | 'proc'
  gltf: null, obj: null,
  saveManifest() { localStorage.setItem(MANIFEST_KEY, JSON.stringify(this.manifest)); },
  slots() {
    const s = Object.keys(CAST).filter(k => CAST[k].look || CAST[k].looks).map(k => ({ id: k, kind: 'model', label: CAST[k].name }));
    for (const v in VEHICLES) s.push({ id: 'veh_' + v, kind: 'model', label: VEHICLES[v].name });
    s.push({ id: 'tex_ground', kind: 'texture', label: 'Zemin dokusu' }, { id: 'tex_building', kind: 'texture', label: 'Bina dokusu' });
    return s;
  },
  async syncRemote() {
    if (!Supa.ok()) return 0;
    let n = 0;
    try {
      const rows = await Supa.list();
      for (const r of rows) {
        const cur = this.manifest[r.id];
        const upd = r.updated_at || '';
        if (!cur || (r.version || 0) > (cur.version || 0) || upd > (cur.updatedAt || '')) {
          this.manifest[r.id] = { id: r.id, slot: r.slot || r.id, kind: r.kind || 'model', fmt: r.fmt || 'glb', url: r.url, version: r.version || 1, updatedAt: upd, source: 'supabase', name: r.display_name || '' };
          n++;
        }
        if (r.display_name && CAST[r.slot || r.id]) CAST[r.slot || r.id].name = r.display_name;
      }
      this.saveManifest();
    } catch (e) { console.warn('[Supabase]', e.message); UI && UI.toast('Supabase eşitleme başarısız: ' + e.message); }
    return n;
  },
  async loadAll(progress) {
    const entries = Object.values(this.manifest);
    let i = 0;
    for (const e of entries) {
      try { await this.loadOne(e.id); } catch (err) { console.warn('Varlık yüklenemedi', e.id, err); this.status[e.slot] = 'error'; }
      progress && progress(++i / Math.max(1, entries.length));
    }
  },
  async getBlob(entry, force) {
    const rec = await AssetCache.get(entry.id).catch(() => null);
    if (!force && rec && rec.blob && rec.version === entry.version && rec.updatedAt === entry.updatedAt) {
      return { blob: rec.blob, meta: rec.rigMeta || null, from: 'cache' };
    }
    if (!entry.url) { if (rec && rec.blob) return { blob: rec.blob, meta: rec.rigMeta, from: 'cache' }; throw new Error('Kaynak yok'); }
    const r = await fetch(entry.url, { cache: 'no-store' });
    if (!r.ok) throw new Error('İndirme hatası ' + r.status);
    const blob = await r.blob();
    await AssetCache.put({ id: entry.id, slot: entry.slot, kind: entry.kind, fmt: entry.fmt, version: entry.version, updatedAt: entry.updatedAt, blob, size: blob.size, rigMeta: null, savedAt: Date.now() });
    return { blob, meta: null, from: 'download' };
  },
  async loadOne(id, force) {
    const e = this.manifest[id]; if (!e) return;
    const { blob, meta, from } = await this.getBlob(e, force);
    if (e.kind === 'texture') {
      const url = URL.createObjectURL(blob);
      const tex = await new Promise((res, rej) => new THREE.TextureLoader().load(url, res, undefined, rej));
      tex.colorSpace = THREE.SRGBColorSpace; tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
      this.textures[e.slot] = tex; this.status[e.slot] = from;
      Bus.emit('textureLoaded', e.slot);
      return;
    }
    let obj;
    if (e.fmt === 'obj') {
      obj = (this.obj ||= new OBJLoader()).parse(await blob.text());
    } else {
      const buf = await blob.arrayBuffer();
      obj = await new Promise((res, rej) => (this.gltf ||= new GLTFLoader()).parse(buf, '', g => res(g.scene), rej));
    }
    const isVeh = e.slot.startsWith('veh_');
    const wrap = normalizeModel(obj, isVeh ? (VEHICLES[e.slot.slice(4)]?.h || 1.5) : 2.0 * (CAST[e.slot]?.look?.scale || 1));
    if (!isVeh) {
      const rig = autoRig(wrap, meta);
      if (!meta) { const rec = await AssetCache.get(e.id); if (rec) { rec.rigMeta = rig.meta; await AssetCache.put(rec); } }
    }
    wrap.userData.custom = true;
    this.templates[e.slot] = wrap; this.status[e.slot] = from;
    Bus.emit('modelLoaded', e.slot);
  },
  instance(slot) {
    const t = this.templates[slot]; if (!t) return null;
    const c = t.clone(true);
    return c;
  },
  async addLocalFile(slot, file) {
    const fmt = (file.name.split('.').pop() || 'glb').toLowerCase();
    const kind = /png|jpe?g|webp/.test(fmt) ? 'texture' : 'model';
    const id = slot;
    const prev = this.manifest[id];
    const version = (prev?.version || 0) + 1;
    const updatedAt = new Date().toISOString();
    let url = '';
    let source = 'local';
    if (Supa.ok()) {
      try {
        const path = `${slot}/${version}_${file.name}`;
        url = await Supa.upload(path, file, file.type);
        await Supa.upsert({ id, slot, kind, fmt, url, version, updated_at: updatedAt, display_name: CAST[slot]?.name || slot });
        source = 'supabase';
      } catch (err) { UI.toast('Supabase yükleme başarısız, yerel kaydedildi: ' + err.message); }
    }
    this.manifest[id] = { id, slot, kind, fmt: fmt === 'gltf' ? 'glb' : fmt, url, version, updatedAt, source, name: file.name };
    this.saveManifest();
    await AssetCache.put({ id, slot, kind, fmt, version, updatedAt, blob: file, size: file.size, rigMeta: null, savedAt: Date.now() });
    await this.loadOne(id);
  },
  async refreshOne(id) {
    const e = this.manifest[id]; if (!e) return;
    if (e.url) await this.loadOne(id, true); else await this.loadOne(id);
  },
  async clearAndRescan() {
    await AssetCache.clear();
    this.templates = {}; this.textures = {}; this.status = {};
    await this.syncRemote();
    // Yerel-yalnız varlıklar (url yok) önbellek silinince kaybolur → manifestten düş
    for (const k of Object.keys(this.manifest)) if (!this.manifest[k].url) delete this.manifest[k];
    this.saveManifest();
    await this.loadAll();
    Bus.emit('assetsReset');
  },
  removeSlot(id) { delete this.manifest[id]; delete this.templates[id]; this.saveManifest(); AssetCache.del(id); Bus.emit('assetsReset'); }
};
