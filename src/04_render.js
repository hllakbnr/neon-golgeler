// ============================================================================
//  RENDER · MATERYAL/SHADER · GÖKYÜZÜ · GÜN/GECE · HAVA DURUMU · EFEKTLER
// ============================================================================
const SHARED_UNI = { uNight: { value: 0 }, uWet: { value: 0 }, uTime: { value: 0 } };
const Render = {
  init() {
    const canvas = $('gl');
    const q = Settings.quality;
    const renderer = new THREE.WebGLRenderer({ canvas, antialias: q !== 'low', powerPreference: 'high-performance', stencil: false });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, q === 'high' ? 2 : q === 'medium' ? 1.5 : 1));
    renderer.setSize(innerWidth, innerHeight);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.05;
    renderer.shadowMap.enabled = !!Settings.shadows;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(62, innerWidth / innerHeight, 0.15, Settings.viewDist + 200);
    scene.fog = new THREE.Fog(0x1a0a33, 60, Settings.viewDist);
    // Ortam yansıması (parlak ABS plastik için)
    const pmrem = new THREE.PMREMGenerator(renderer);
    scene.environment = pmrem.fromScene(new RoomEnvironment(renderer), 0.04).texture;
    // Işıklar
    const hemi = new THREE.HemisphereLight(0xbfd8ff, 0x302040, 0.8);
    const sun = new THREE.DirectionalLight(0xffffff, 2.2);
    sun.castShadow = !!Settings.shadows;
    const sm = q === 'high' ? 2048 : 1024;
    sun.shadow.mapSize.set(sm, sm);
    const sc = sun.shadow.camera; sc.left = -55; sc.right = 55; sc.top = 55; sc.bottom = -55; sc.near = 1; sc.far = 260;
    sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.04;
    scene.add(hemi, sun, sun.target);
    Object.assign(Game, { renderer, scene, camera });
    this.hemi = hemi; this.sun = sun;
    this.buildSky();
    Rain.init(); FX.init(); LightPool.init();
    addEventListener('resize', () => { renderer.setSize(innerWidth, innerHeight); camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); });
  },
  buildSky() {
    const geo = new THREE.SphereGeometry(1, 24, 12);
    this.skyMat = new THREE.ShaderMaterial({
      side: THREE.BackSide, depthWrite: false, fog: false,
      uniforms: { top: { value: new THREE.Color() }, hor: { value: new THREE.Color() }, sunDir: { value: new THREE.Vector3() }, sunCol: { value: new THREE.Color() }, night: SHARED_UNI.uNight, cloud: { value: 0 }, time: SHARED_UNI.uTime },
      vertexShader: 'varying vec3 vP; void main(){ vP = position; vec4 p = projectionMatrix * modelViewMatrix * vec4(position,1.0); gl_Position = p.xyww; }',
      fragmentShader: `uniform vec3 top; uniform vec3 hor; uniform vec3 sunDir; uniform vec3 sunCol; uniform float night; uniform float cloud; uniform float time; varying vec3 vP;
        float h(vec3 p){ return fract(sin(dot(p, vec3(12.9898,78.233,37.719)))*43758.5453); }
        void main(){ vec3 d = normalize(vP); float y = clamp(d.y,0.0,1.0);
          vec3 c = mix(hor, top, pow(y, 0.55));
          float s = max(dot(d, normalize(sunDir)), 0.0);
          c += sunCol * (pow(s, 600.0)*4.0 + pow(s, 12.0)*0.35) * (1.0 - cloud*0.8);
          vec3 cell = floor(d*220.0); float st = step(0.9975, h(cell)) * night * (1.0-cloud) * smoothstep(0.05,0.3,d.y);
          st *= 0.6 + 0.4*sin(time*2.0 + h(cell+1.0)*30.0);
          c += vec3(st);
          c = mix(c, vec3(dot(c, vec3(0.33)))*0.7, cloud*0.6);
          if (d.y < 0.0) c = mix(hor, hor*0.4, clamp(-d.y*4.0,0.0,1.0));
          gl_FragColor = vec4(c, 1.0); }`
    });
    this.sky = new THREE.Mesh(geo, this.skyMat); this.sky.frustumCulled = false; this.sky.renderOrder = -10;
    this.sky.scale.setScalar(Settings.viewDist + 100);
    Game.scene.add(this.sky);
  }
};

// ---------------------------------------------------------------- Materyal fabrikası
const Mat = {
  cache: new Map(),
  plastic(color, o = {}) {
    const key = 'p' + color + (o.rough ?? '') + (o.metal ?? '') + (o.em ?? '') + (o.tr ?? '');
    let m = this.cache.get(key);
    if (!m) {
      m = new THREE.MeshStandardMaterial({ color, roughness: o.rough ?? 0.3, metalness: o.metal ?? 0.0, envMapIntensity: 0.9 });
      if (o.em) { m.emissive = new THREE.Color(o.em); m.emissiveIntensity = o.emi ?? 1.2; }
      if (o.tr) { m.transparent = true; m.opacity = o.tr; m.depthWrite = false; }
      this.cache.set(key, m);
    }
    return m;
  },
  neon(color) {
    const key = 'n' + color; let m = this.cache.get(key);
    if (!m) { m = new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(1.6), toneMapped: false, fog: true }); this.cache.set(key, m); }
    return m;
  },
  metalSkin: null,
  getMetalSkin() { return this.metalSkin ||= new THREE.MeshStandardMaterial({ color: 0xd6dde6, metalness: 1.0, roughness: 0.18, envMapIntensity: 1.6 }); },
  // Bina: dünya-konumlu pencere deseni, gece ışıkları (onBeforeCompile)
  building() {
    if (this._b) return this._b;
    const m = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.38, metalness: 0.05, envMapIntensity: 0.8 });
    m.onBeforeCompile = (sh) => {
      sh.uniforms.uNight = SHARED_UNI.uNight;
      sh.vertexShader = 'varying vec3 vNgW; varying vec3 vNgN; varying float vSeed;\n' + sh.vertexShader.replace('#include <worldpos_vertex>', `#include <worldpos_vertex>
        vec4 ngW = vec4(transformed, 1.0); vec3 ngN = normal; float ngS = 0.0;
        #ifdef USE_INSTANCING
          ngW = instanceMatrix * ngW; ngN = mat3(instanceMatrix) * ngN; ngS = instanceMatrix[3].x * 0.13 + instanceMatrix[3].z * 0.29;
        #endif
        ngW = modelMatrix * ngW; vNgW = ngW.xyz; vNgN = normalize(mat3(modelMatrix) * ngN); vSeed = ngS;`);
      sh.fragmentShader = 'uniform float uNight; varying vec3 vNgW; varying vec3 vNgN; varying float vSeed;\n' + sh.fragmentShader.replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
        {
          float side = 1.0 - step(0.6, abs(vNgN.y));
          float hz = abs(vNgN.x) > 0.5 ? vNgW.z : vNgW.x;
          vec2 cell = vec2(floor(hz / 2.6), floor((vNgW.y - 1.2) / 3.4));
          vec2 f = vec2(fract(hz / 2.6), fract((vNgW.y - 1.2) / 3.4));
          float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.28, f.y) * step(f.y, 0.82) * step(1.2, vNgW.y) * side;
          float r = fract(sin(dot(cell + vec2(vSeed, vSeed*1.7), vec2(12.9898, 78.233))) * 43758.5453);
          float lit = step(0.5, r);
          vec3 wc = mix(vec3(1.0, 0.78, 0.45), mix(vec3(0.45, 0.9, 1.0), vec3(1.0, 0.4, 0.9), step(0.85, r)), step(0.72, r));
          diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.08, 0.1, 0.18), win * 0.75);
          totalEmissiveRadiance += win * lit * uNight * wc * 1.4;
          float stud = side * step(0.94, fract(vNgW.y / 3.4)) * 0.15;
          diffuseColor.rgb *= 1.0 - stud;
        }`).replace('#include <roughnessmap_fragment>', '#include <roughnessmap_fragment>\n');
    };
    m.customProgramCacheKey = () => 'ngBuilding';
    return this._b = m;
  },
  // Zemin: yol/kaldırım/şerit deseni + ıslak birikinti yansıması
  ground() {
    if (this._g) return this._g;
    const m = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.85, metalness: 0.0, envMapIntensity: 1.0 });
    m.onBeforeCompile = (sh) => {
      sh.uniforms.uWet = SHARED_UNI.uWet; sh.uniforms.uNight = SHARED_UNI.uNight;
      sh.vertexShader = 'varying vec3 vGW;\n' + sh.vertexShader.replace('#include <worldpos_vertex>', '#include <worldpos_vertex>\n vGW = (modelMatrix * vec4(transformed,1.0)).xyz;');
      sh.fragmentShader = 'uniform float uWet; uniform float uNight; varying vec3 vGW; float ngP = 0.0;\n' +
        'float ngH(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }\n' +
        'float ngN(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(ngH(i),ngH(i+vec2(1,0)),f.x), mix(ngH(i+vec2(0,1)),ngH(i+vec2(1,1)),f.x), f.y); }\n' +
        sh.fragmentShader.replace('#include <color_fragment>', `#include <color_fragment>
        {
          float dx = abs(vGW.x - 80.0 * floor(vGW.x / 80.0 + 0.5));
          float dz = abs(vGW.z - 80.0 * floor(vGW.z / 80.0 + 0.5));
          float road = max(step(dx, 7.0), step(dz, 7.0));
          float walk = max(step(dx, 10.0), step(dz, 10.0)) * (1.0 - road);
          vec3 asphalt = vec3(0.13, 0.12, 0.16);
          vec3 side = vec3(0.55, 0.52, 0.6);
          vec3 lot = vec3(0.32, 0.3, 0.36);
          vec3 col = mix(lot, side, walk); col = mix(col, asphalt, road);
          float lineX = step(dx, 0.18) * step(0.5, fract(vGW.z / 6.0)) * (1.0 - step(dz, 7.0));
          float lineZ = step(dz, 0.18) * step(0.5, fract(vGW.x / 6.0)) * (1.0 - step(dx, 7.0));
          col = mix(col, vec3(1.0, 0.82, 0.2), max(lineX, lineZ) * road);
          float tiles = walk * step(0.92, max(fract(vGW.x / 1.6), fract(vGW.z / 1.6))) * 0.25;
          col *= 1.0 - tiles;
          ngP = smoothstep(0.52, 0.7, ngN(vGW.xz * 0.12)) * uWet;
          col = mix(col, col * 0.45, uWet * 0.6);
          diffuseColor.rgb *= col;
        }`).replace('#include <roughnessmap_fragment>', `#include <roughnessmap_fragment>
          roughnessFactor = mix(roughnessFactor, 0.06, max(ngP, uWet * 0.35));`).replace('#include <metalnessmap_fragment>', `#include <metalnessmap_fragment>
          metalnessFactor = mix(metalnessFactor, 0.35, ngP);`);
    };
    m.customProgramCacheKey = () => 'ngGround';
    return this._g = m;
  },
  water() {
    if (this._w) return this._w;
    const m = new THREE.MeshStandardMaterial({ color: 0x0b2a4a, roughness: 0.08, metalness: 0.6, envMapIntensity: 1.4 });
    m.onBeforeCompile = (sh) => {
      sh.uniforms.uTime = SHARED_UNI.uTime;
      sh.vertexShader = 'uniform float uTime; varying vec3 vWW;\n' + sh.vertexShader.replace('#include <begin_vertex>', '#include <begin_vertex>\n vec4 ww = modelMatrix * vec4(position,1.0); vWW = ww.xyz;');
      sh.fragmentShader = 'uniform float uTime; varying vec3 vWW;\n' + sh.fragmentShader.replace('#include <normal_fragment_maps>', `#include <normal_fragment_maps>
        normal = normalize(normal + vec3(sin(vWW.x*0.35+uTime*1.3)*0.08 + sin(vWW.z*0.9+uTime*2.1)*0.04, 0.0, cos(vWW.z*0.4+uTime*1.1)*0.08));`);
    };
    m.customProgramCacheKey = () => 'ngWater';
    return this._w = m;
  }
};
// Paylaşılan geometriler
const Geo = {
  box: new THREE.BoxGeometry(1, 1, 1),
  boxB: (() => { const g = new THREE.BoxGeometry(1, 1, 1); g.translate(0, 0.5, 0); return g; })(), // tabanı y=0
  cyl: new THREE.CylinderGeometry(0.5, 0.5, 1, 14),
  cylLo: new THREE.CylinderGeometry(0.5, 0.5, 1, 8),
  cone: new THREE.ConeGeometry(0.5, 1, 4),
  sphere: new THREE.SphereGeometry(0.5, 12, 8),
  plane: new THREE.PlaneGeometry(1, 1),
  ring: new THREE.RingGeometry(0.85, 1, 40),
  torus: new THREE.TorusGeometry(1, 0.12, 6, 28)
};
const haloTex = (() => {
  const c = document.createElement('canvas'); c.width = c.height = 64; const g = c.getContext('2d');
  const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.3, 'rgba(255,255,255,.45)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 64, 64); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
})();

// ---------------------------------------------------------------- Gün/Gece & Hava
const Sky = {
  wet: 0, rainAmt: 0, cloud: 0, flashT: 0, nextWeatherAt: 0, curfew: false, forced: null,
  keys: [ // saat, gökyüzü üst, ufuk, güneş rengi, hemi yoğunluk
    [0, '#07041a', '#3a0f5e', '#5a6cff', 0.35], [5, '#120a35', '#ff5fa0', '#ff8a5a', 0.45], [7, '#4a7fd8', '#ffc08a', '#ffd2a0', 0.8],
    [12, '#3a8fff', '#cfe8ff', '#ffffff', 1.0], [17, '#3a6fd8', '#ffb080', '#ffc080', 0.85], [19.5, '#2a1260', '#ff3fa0', '#ff5a7a', 0.55],
    [21, '#0b0628', '#5a1a7a', '#6a5cff', 0.4], [24, '#07041a', '#3a0f5e', '#5a6cff', 0.35]
  ],
  colA: new THREE.Color(), colB: new THREE.Color(),
  sample(h, idx) {
    const k = this.keys; let i = 0; while (i < k.length - 1 && k[i + 1][0] <= h) i++;
    const a = k[i], b = k[Math.min(i + 1, k.length - 1)]; const t = b[0] === a[0] ? 0 : (h - a[0]) / (b[0] - a[0]);
    if (idx === 4) return lerp(a[4], b[4], t);
    return this.colA.set(a[idx]).lerp(this.colB.set(b[idx]), t).clone();
  },
  setWeather(w, force) {
    S.weather = w; if (force) this.forced = w;
    if (w === 'rain' || w === 'storm') logEvent('rain', RADIO.news.rain); else if (w === 'clear') logEvent('clear', RADIO.news.clear);
  },
  update(dt) {
    const prevH = S.time;
    S.time += dt * Settings.timeScale / 3600;
    if (S.time >= 24) { S.time -= 24; S.day++; }
    const h = S.time;
    // Rastgele hava değişimi (görev zorlamıyorsa)
    if (!this.forced && Game.t > this.nextWeatherAt) {
      this.nextWeatherAt = Game.t + rand(140, 320);
      const r = Math.random(); this.setWeather(r < 0.45 ? 'clear' : r < 0.7 ? 'cloudy' : r < 0.92 ? 'rain' : 'storm');
    }
    const w = S.weather;
    const tRain = w === 'rain' ? 0.7 : w === 'storm' ? 1 : 0;
    const tCloud = w === 'cloudy' ? 0.55 : w === 'rain' ? 0.8 : w === 'storm' ? 1 : 0;
    this.rainAmt = lerp(this.rainAmt, tRain, dt * 0.4);
    this.cloud = lerp(this.cloud, tCloud, dt * 0.3);
    this.wet = tRain > 0 ? Math.min(1, this.wet + dt * 0.08) : Math.max(0, this.wet - dt * 0.012);
    // Güneş
    const ang = ((h - 6) / 12) * Math.PI;
    const sy = Math.sin(ang), sx = Math.cos(ang);
    const day = clamp(sy * 2.2 + 0.25, 0, 1);
    const night = 1 - day;
    SHARED_UNI.uNight.value = clamp(night * 1.1, 0, 1);
    SHARED_UNI.uWet.value = this.wet;
    const top = this.sample(h, 1), hor = this.sample(h, 2), sunC = this.sample(h, 3);
    const cloudGrey = new THREE.Color(0x2a2a38);
    top.lerp(cloudGrey, this.cloud * 0.6); hor.lerp(cloudGrey, this.cloud * 0.5);
    Render.skyMat.uniforms.top.value.copy(top); Render.skyMat.uniforms.hor.value.copy(hor);
    Render.skyMat.uniforms.sunCol.value.copy(sunC); Render.skyMat.uniforms.cloud.value = this.cloud;
    const sd = new THREE.Vector3(sx * 0.8, sy, 0.45).normalize();
    // Gece "ay" yönü ışığı: Vice City morumsu ay ışığı
    const lightDir = sy > -0.05 ? sd : new THREE.Vector3(-sx * 0.6, Math.max(0.3, -sy), -0.4).normalize();
    Render.skyMat.uniforms.sunDir.value.copy(sd);
    const p = Game.player ? Game.player.pos : _v1.set(0, 0, 0);
    Render.sun.position.set(p.x + lightDir.x * 120, p.y + lightDir.y * 120, p.z + lightDir.z * 120);
    Render.sun.target.position.copy(p);
    Render.sun.color.copy(sy > -0.05 ? sunC : new THREE.Color(0x8a7cff));
    Render.sun.intensity = (sy > -0.05 ? lerp(0.4, 2.6, day) : 0.55) * (1 - this.cloud * 0.55);
    Render.hemi.intensity = this.sample(h, 4) * (1 - this.cloud * 0.25) + 0.15;
    Render.hemi.color.copy(top).lerp(new THREE.Color(0xffffff), 0.5);
    Render.hemi.groundColor.set(night > 0.5 ? 0x3a1450 : 0x504060);
    Game.renderer.toneMappingExposure = lerp(1.25, 1.0, day);
    const fogC = hor.clone().lerp(new THREE.Color(0x101018), 0.35);
    Game.scene.fog.color.copy(fogC);
    Game.scene.fog.near = lerp(60, 25, this.rainAmt);
    Game.scene.fog.far = lerp(Settings.viewDist, Settings.viewDist * 0.55, this.rainAmt);
    Render.sky.position.copy(Game.camera.position);
    // Fırtına şimşeği
    if (w === 'storm') {
      this.flashT -= dt;
      if (this.flashT <= 0) { this.flashT = rand(4, 11); $('flash').style.transition = 'none'; $('flash').style.opacity = 0.55; setTimeout(() => { $('flash').style.transition = 'opacity .6s'; $('flash').style.opacity = 0; }, 80); }
    }
    Rain.update(dt, this.rainAmt);
  },
  isNight() { return S.time >= 19.5 || S.time < 5.5; },
  hourIn(a, b) { const h = S.time; return a <= b ? (h >= a && h <= b) : (h >= a || h <= b); },
  label() { const h = Math.floor(S.time), m = Math.floor((S.time % 1) * 60); return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`; },
  weatherIcon() { return { clear: this.isNight() ? '🌙' : '☀️', cloudy: '☁️', rain: '🌧', storm: '⛈' }[S.weather] || '☀️'; }
};

// ---------------------------------------------------------------- Yağmur (havuzlanmış çizgiler)
const Rain = {
  n: 0, mesh: null, pos: null,
  init() {
    this.n = Settings.quality === 'low' ? 900 : Settings.quality === 'medium' ? 1600 : 2600;
    const g = new THREE.BufferGeometry(); this.pos = new Float32Array(this.n * 6);
    for (let i = 0; i < this.n; i++) { const x = rand(-35, 35), y = rand(0, 30), z = rand(-35, 35); this.pos.set([x, y, z, x + 0.05, y - 0.7, z], i * 6); }
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3));
    this.mesh = new THREE.LineSegments(g, new THREE.LineBasicMaterial({ color: 0xa8c8ff, transparent: true, opacity: 0.45, fog: false }));
    this.mesh.frustumCulled = false; this.mesh.visible = false;
    Game.scene.add(this.mesh);
  },
  update(dt, amt) {
    this.mesh.visible = amt > 0.03;
    if (!this.mesh.visible) return;
    this.mesh.material.opacity = 0.18 + amt * 0.4;
    const c = Game.camera.position; this.mesh.position.set(c.x, c.y - 12, c.z);
    const fall = dt * 34, active = Math.floor(this.n * amt), p = this.pos;
    for (let i = 0; i < this.n; i++) {
      const o = i * 6;
      if (i > active) { p[o + 1] = p[o + 4] = -999; continue; }
      p[o + 1] -= fall; p[o + 4] -= fall;
      if (p[o + 1] < 0 || p[o + 1] < -900) { const x = rand(-35, 35), z = rand(-35, 35), y = rand(24, 32); p[o] = x; p[o + 1] = y; p[o + 2] = z; p[o + 3] = x + 0.05; p[o + 4] = y - 0.7; p[o + 5] = z; }
    }
    this.mesh.geometry.attributes.position.needsUpdate = true;
  }
};

// ---------------------------------------------------------------- Efekt havuzu
const FX = {
  max: 700, inst: null, pos: [], vel: [], life: [], maxLife: [], size: [], grav: [], cur: 0,
  rings: [], tornadoes: [], dummy: new THREE.Object3D(), col: new THREE.Color(),
  init() {
    this.max = Settings.quality === 'low' ? 350 : 700;
    const m = new THREE.MeshBasicMaterial({ toneMapped: false });
    this.inst = new THREE.InstancedMesh(Geo.box, m, this.max);
    this.inst.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.inst.frustumCulled = false;
    for (let i = 0; i < this.max; i++) {
      this.pos.push(new THREE.Vector3(0, -999, 0)); this.vel.push(new THREE.Vector3()); this.life.push(0); this.maxLife.push(1); this.size.push(0.2); this.grav.push(1);
      this.inst.setColorAt(i, this.col.set(0xffffff));
      this.dummy.position.set(0, -999, 0); this.dummy.updateMatrix(); this.inst.setMatrixAt(i, this.dummy.matrix);
    }
    Game.scene.add(this.inst);
    for (let i = 0; i < 14; i++) {
      const r = new THREE.Mesh(Geo.ring, new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0, side: THREE.DoubleSide, depthWrite: false, toneMapped: false, blending: THREE.AdditiveBlending }));
      r.rotation.x = -Math.PI / 2; r.visible = false; r.userData = { t: 0, dur: 0.5, max: 6 }; Game.scene.add(r); this.rings.push(r);
    }
  },
  burst(p, color, n = 12, speed = 6, size = 0.18, life = 0.6, grav = 1) {
    for (let k = 0; k < n; k++) {
      const i = this.cur = (this.cur + 1) % this.max;
      this.pos[i].copy(p); this.vel[i].set(rand(-1, 1), rand(0.2, 1.3), rand(-1, 1)).normalize().multiplyScalar(speed * rand(0.4, 1));
      this.life[i] = this.maxLife[i] = life * rand(0.6, 1.2); this.size[i] = size * rand(0.6, 1.3); this.grav[i] = grav;
      this.inst.setColorAt(i, this.col.set(color));
    }
    if (this.inst.instanceColor) this.inst.instanceColor.needsUpdate = true;
  },
  trail(p, color, size = 0.12, life = 0.35) {
    const i = this.cur = (this.cur + 1) % this.max;
    this.pos[i].copy(p); this.vel[i].set(rand(-0.3, 0.3), rand(0, 0.5), rand(-0.3, 0.3));
    this.life[i] = this.maxLife[i] = life; this.size[i] = size; this.grav[i] = 0;
    this.inst.setColorAt(i, this.col.set(color)); if (this.inst.instanceColor) this.inst.instanceColor.needsUpdate = true;
  },
  ring(p, color, max = 6, dur = 0.45) {
    const r = this.rings.find(x => !x.visible) || this.rings[0];
    r.visible = true; r.position.set(p.x, p.y + 0.15, p.z); r.material.color.set(color); r.userData = { t: 0, dur, max }; r.scale.setScalar(0.3);
  },
  update(dt) {
    const d = this.dummy;
    for (let i = 0; i < this.max; i++) {
      if (this.life[i] <= 0) continue;
      this.life[i] -= dt;
      const v = this.vel[i]; v.y -= 14 * this.grav[i] * dt;
      this.pos[i].addScaledVector(v, dt);
      const k = Math.max(0, this.life[i] / this.maxLife[i]);
      d.position.copy(this.life[i] > 0 ? this.pos[i] : _v1.set(0, -999, 0));
      d.rotation.set(this.life[i] * 7, this.life[i] * 5, 0);
      d.scale.setScalar(this.size[i] * (0.3 + k * 0.7));
      d.updateMatrix(); this.inst.setMatrixAt(i, d.matrix);
    }
    this.inst.instanceMatrix.needsUpdate = true;
    for (const r of this.rings) {
      if (!r.visible) continue;
      const u = r.userData; u.t += dt; const k = u.t / u.dur;
      r.scale.setScalar(0.3 + k * u.max); r.material.opacity = (1 - k) * 0.9;
      if (k >= 1) r.visible = false;
    }
  }
};

// ---------------------------------------------------------------- Neon ışık havuzu
const LightPool = {
  lights: [], anchors: [], timer: 0,
  init() {
    const n = Settings.quality === 'low' ? 3 : Settings.quality === 'medium' ? 5 : 8;
    for (let i = 0; i < n; i++) { const l = new THREE.PointLight(0xff2fd6, 0, 26, 1.6); l.castShadow = false; Game.scene.add(l); this.lights.push(l); }
  },
  update(dt) {
    this.timer -= dt; const night = SHARED_UNI.uNight.value;
    if (this.timer <= 0 && Game.player) {
      this.timer = 0.6;
      const p = Game.player.pos;
      const sorted = this.anchors.filter(a => Math.abs(a.x - p.x) < 90 && Math.abs(a.z - p.z) < 90).sort((a, b) => dist2(a.x, a.z, p.x, p.z) - dist2(b.x, b.z, p.x, p.z));
      this.lights.forEach((l, i) => { const a = sorted[i]; if (a) { l.position.set(a.x, a.y, a.z); l.color.set(a.c); l.userData.on = 1; } else l.userData.on = 0; });
    }
    for (const l of this.lights) l.intensity = lerp(l.intensity, (l.userData.on ? 1 : 0) * night * 60 * (1 + Sky.wet * 0.4), dt * 3);
  }
};
