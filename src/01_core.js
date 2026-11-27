// ============================================================================
//  NEON GÖLGELER — 3D Açık Dünya Hikayeli Aksiyon-Macera
//  Modüler tek-dosya yapı: Core · Data · Cache · Render · World · Figure ·
//  Input · Actors · Vehicles · UI · Missions · Main
// ============================================================================
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

// ---------------------------------------------------------------- Yardımcılar
const $ = (id) => document.getElementById(id);
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;
const rand = (a = 0, b = 1) => a + Math.random() * (b - a);
const randi = (a, b) => Math.floor(rand(a, b + 1));
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const dist2 = (ax, az, bx, bz) => { const dx = ax - bx, dz = az - bz; return dx * dx + dz * dz; };
const angLerp = (a, b, t) => { let d = ((b - a + Math.PI) % (Math.PI * 2)); if (d < 0) d += Math.PI * 2; return a + (d - Math.PI) * t; };
const wait = (ms) => new Promise(r => setTimeout(r, ms));
const smooth = (t) => t * t * (3 - 2 * t);
const IS_TOUCH = ('ontouchstart' in window) || navigator.maxTouchPoints > 0;
const IS_MOBILE = /Android|iPhone|iPad|Mobile/i.test(navigator.userAgent);
const IS_ELECTRON = /Electron/i.test(navigator.userAgent);
const _v1 = new THREE.Vector3(), _v2 = new THREE.Vector3(), _v3 = new THREE.Vector3();

// ---------------------------------------------------------------- Olay veriyolu
const Bus = {
  h: {},
  on(ev, fn) { (this.h[ev] ||= []).push(fn); return () => this.off(ev, fn); },
  off(ev, fn) { const a = this.h[ev]; if (a) { const i = a.indexOf(fn); if (i >= 0) a.splice(i, 1); } },
  emit(ev, data) { const a = this.h[ev]; if (a) for (const fn of a.slice()) { try { fn(data); } catch (e) { console.error('[Bus]', ev, e); } } }
};

// ---------------------------------------------------------------- Ayarlar
const SETTINGS_KEY = 'ng_settings_v1';
const Settings = Object.assign({
  quality: IS_MOBILE ? 'low' : 'high',   // low | medium | high
  viewDist: IS_MOBILE ? 260 : 420,
  shadows: !IS_MOBILE,
  invertY: false,
  sens: 1.0,
  timeScale: 60,           // 1 gerçek saniye = 60 oyun saniyesi (1 oyun saati = 60 sn)
  volume: 0.6,
  showFps: true,
  touchForce: false
}, JSON.parse(localStorage.getItem(SETTINGS_KEY) || '{}'));
const saveSettings = () => localStorage.setItem(SETTINGS_KEY, JSON.stringify(Settings));

// ---------------------------------------------------------------- Oyun durumu
const SAVE_KEY = 'ng_save_v1';
function freshState() {
  return {
    version: 1,
    money: 150,
    reputation: 0,              // 0..100+
    isRecognizedNinja: false,   // 2.6 sonrası true
    wanted: 0,                  // 0..5
    bondLevel: 0,               // 0..100 (Ela Poyraz ile bağ)
    morality: 0,                // - sert/intikamcı · + koruyucu/birleştirici
    moralPath: null,            // 'vengeful' | 'protective'
    flags: {},
    abilities: { metal: true, shockwave: true, tornado: false, glide: false, dragon: false },
    completed: {},              // görev id -> true
    outfit: 'civil',            // 'civil' | 'ninja'
    mask: false,
    carried: ['fists'],         // taşınan silahlar (MAX_CARRY)
    storage: [],                // güvenli ev/garaj deposu
    equipped: 0,
    vehicles: [],               // sahip olunan araçlar [{uid,type,color,mods:{speed,armor,grip}}]
    safehouses: [],
    eggs: {},
    messages: [{ from: 'Hikmet Usta', text: 'Kaan, rıhtımda bu gece hareket var. Dikkatli ol evlat.', t: 0 }],
    allyWith: false,            // Ela yanımızda mı
    allyUnlocked: false,
    time: 21.5,                 // oyun saati 0..24
    day: 1,
    weather: 'clear',
    pos: null,                  // [x,y,z]
    eventLog: [],               // radyo bültenleri için
    stats: { kos: 0, crimes: 0, races: 0, distance: 0 },
    ending: null
  };
}
let S = freshState();
const MAX_CARRY = 3; // yumruk hariç taşıma yuvası
function saveGame() {
  try {
    if (Game.player) S.pos = [Game.player.pos.x, Game.player.pos.y, Game.player.pos.z];
    localStorage.setItem(SAVE_KEY, JSON.stringify(S));
    return true;
  } catch (e) { console.warn('Kaydetme hatası', e); return false; }
}
function loadGame() {
  const raw = localStorage.getItem(SAVE_KEY);
  if (!raw) return false;
  try { S = Object.assign(freshState(), JSON.parse(raw)); return true; } catch (e) { return false; }
}
function logEvent(key, text) {
  S.eventLog.push({ key, text, day: S.day, t: S.time });
  if (S.eventLog.length > 30) S.eventLog.shift();
  Bus.emit('event', { key, text });
}
function addMessage(from, text) {
  S.messages.unshift({ from, text, t: S.time });
  if (S.messages.length > 40) S.messages.pop();
  UI && UI.toast('📱 ' + from + ': ' + text.slice(0, 60) + (text.length > 60 ? '…' : ''));
}
function changeBond(d, why) {
  S.bondLevel = clamp(S.bondLevel + d, 0, 100);
  if (d > 0) UI.toast(`💞 Bağ +${d}${why ? ' · ' + why : ''}`);
}
function changeRep(d) {
  const before = S.reputation;
  S.reputation = Math.max(0, S.reputation + d);
  if (Math.floor(before / 20) < Math.floor(S.reputation / 20)) UI.toast('⭐ Saygınlık seviyesi ' + Math.floor(S.reputation / 20), true);
}
function changeMoney(d) { S.money = Math.max(0, S.money + d); }
function changeMorality(d) { S.morality += d; }

// Global oyun nesnesi — tüm sistemler buraya bağlanır
const Game = {
  t: 0, dt: 0, paused: false, mode: 'title', // title | play | cutscene | dialog | menu
  player: null, ally: null, actors: [], vehicles: [],
  scene: null, camera: null, renderer: null,
  inputLock: 0
};
let UI = null; // UI modülü sonra atanır
