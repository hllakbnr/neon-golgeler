// ============================================================================
//  INPUT MANAGER — Klavye+Fare · Gamepad (standart eşleme) · Dokunmatik
//  Aktif cihaz otomatik algılanır; arayüz ipuçları buna göre güncellenir.
// ============================================================================
const ACTIONS = ['jump', 'attack', 'heavy', 'interact', 'vehicle', 'metal', 'spin', 'dragon', 'sprint', 'wheel', 'wardrobe', 'mask', 'phone', 'callally', 'pause', 'horn', 'radio', 'handbrake', 'descend', 'next', 'prev'];
const KEYMAP = {
  Space: 'jump', KeyJ: 'attack', KeyL: 'heavy', KeyE: 'interact', KeyF: 'vehicle', KeyR: 'metal', Digit1: 'spin', Digit2: 'dragon',
  ShiftLeft: 'sprint', ShiftRight: 'sprint', KeyQ: 'wheel', KeyO: 'wardrobe', KeyK: 'mask', Tab: 'phone', KeyP: 'phone', KeyG: 'callally',
  Escape: 'pause', KeyH: 'horn', KeyN: 'radio', ControlLeft: 'descend', KeyC: 'descend', Enter: 'next'
};
const PAD = { 0: 'jump', 2: 'attack', 3: 'heavy', 1: 'interact', 5: 'metal', 4: 'wheel', 7: 'attack', 6: 'heavy', 12: 'spin', 13: 'dragon', 14: 'mask', 15: 'wardrobe', 8: 'phone', 9: 'pause', 10: 'sprint', 11: 'vehicle' };
const HINTS = {
  kbm: { jump: 'Boşluk', attack: 'Sol Tık', heavy: 'Sağ Tık', interact: 'E', vehicle: 'F', metal: 'R', spin: '1', dragon: '2', wheel: 'Q', wardrobe: 'O', mask: 'K', phone: 'Tab', callally: 'G', sprint: 'Shift', pause: 'Esc' },
  pad: { jump: 'Ⓐ', attack: 'Ⓧ/RT', heavy: 'Ⓨ/LT', interact: 'Ⓑ', vehicle: 'R3', metal: 'RB', spin: '⬆', dragon: '⬇', wheel: 'LB', wardrobe: '➡', mask: '⬅', phone: 'Back', callally: '—', sprint: 'L3', pause: 'Start' },
  touch: { jump: 'ZIPLA', attack: 'VUR', heavy: 'ŞOK', interact: 'E', vehicle: 'ARAÇ', metal: 'METAL', spin: 'KASIRGA', dragon: 'EJDER', wheel: '🗡', wardrobe: '👕', mask: '😷', phone: '📱', callally: '📞', sprint: 'KOŞ', pause: '⏸' }
};
const Input = {
  device: 'kbm', keys: {}, down: {}, prev: {}, mouse: { dx: 0, dy: 0, locked: false, wheel: 0 },
  move: { x: 0, y: 0 }, look: { x: 0, y: 0 }, pad: null, touchMove: { x: 0, y: 0 }, touchLook: { x: 0, y: 0 }, touchBtns: {},
  throttle: 0, brake: 0,
  init() {
    addEventListener('keydown', (e) => {
      if (e.target && /INPUT|TEXTAREA|SELECT/.test(e.target.tagName)) return;
      this.keys[e.code] = true; this.setDevice('kbm');
      if (e.code === 'Tab' || e.code === 'Space') e.preventDefault();
    });
    addEventListener('keyup', (e) => { this.keys[e.code] = false; });
    addEventListener('blur', () => { this.keys = {}; });
    const cv = $('gl');
    cv.addEventListener('mousedown', (e) => {
      this.setDevice('kbm');
      if (Game.mode === 'play' && !this.mouse.locked && !IS_TOUCH) cv.requestPointerLock?.();
      if (e.button === 0) this.keys.Mouse0 = true; if (e.button === 2) this.keys.Mouse2 = true;
    });
    addEventListener('mouseup', (e) => { if (e.button === 0) this.keys.Mouse0 = false; if (e.button === 2) this.keys.Mouse2 = false; });
    cv.addEventListener('contextmenu', e => e.preventDefault());
    document.addEventListener('pointerlockchange', () => { this.mouse.locked = document.pointerLockElement === cv; });
    addEventListener('mousemove', (e) => { if (this.mouse.locked) { this.mouse.dx += e.movementX; this.mouse.dy += e.movementY; } });
    addEventListener('wheel', (e) => { this.mouse.wheel += Math.sign(e.deltaY); }, { passive: true });
    addEventListener('gamepadconnected', () => { this.setDevice('pad'); UI && UI.toast('🎮 Gamepad bağlandı'); });
    this.initTouch();
    if (IS_TOUCH && (IS_MOBILE || Settings.touchForce)) this.setDevice('touch');
  },
  initTouch() {
    const joy = $('joy'), knob = $('joyk'); let jid = null, jc = { x: 0, y: 0 };
    const R = 60;
    joy.addEventListener('touchstart', (e) => { const t = e.changedTouches[0]; jid = t.identifier; const r = joy.getBoundingClientRect(); jc = { x: r.left + r.width / 2, y: r.top + r.height / 2 }; this.setDevice('touch'); e.preventDefault(); }, { passive: false });
    const jm = (e) => { for (const t of e.changedTouches) if (t.identifier === jid) { let dx = t.clientX - jc.x, dy = t.clientY - jc.y; const l = Math.hypot(dx, dy); if (l > R) { dx *= R / l; dy *= R / l; } knob.style.transform = `translate(${dx}px,${dy}px)`; this.touchMove.x = dx / R; this.touchMove.y = -dy / R; } };
    const je = (e) => { for (const t of e.changedTouches) if (t.identifier === jid) { jid = null; knob.style.transform = ''; this.touchMove.x = this.touchMove.y = 0; } };
    joy.addEventListener('touchmove', (e) => { jm(e); e.preventDefault(); }, { passive: false }); joy.addEventListener('touchend', je); joy.addEventListener('touchcancel', je);
    const pad = $('lookpad'); let lid = null, lp = null;
    pad.addEventListener('touchstart', (e) => { const t = e.changedTouches[0]; lid = t.identifier; lp = { x: t.clientX, y: t.clientY }; this.setDevice('touch'); }, { passive: true });
    pad.addEventListener('touchmove', (e) => { for (const t of e.changedTouches) if (t.identifier === lid) { this.touchLook.x += (t.clientX - lp.x) * 0.9; this.touchLook.y += (t.clientY - lp.y) * 0.9; lp = { x: t.clientX, y: t.clientY }; } e.preventDefault(); }, { passive: false });
    pad.addEventListener('touchend', (e) => { for (const t of e.changedTouches) if (t.identifier === lid) lid = null; });
    document.querySelectorAll('#touch .tb').forEach(b => {
      const a = b.dataset.a;
      b.addEventListener('touchstart', (e) => { this.touchBtns[a] = true; b.classList.add('on'); this.setDevice('touch'); e.preventDefault(); e.stopPropagation(); }, { passive: false });
      const up = (e) => { this.touchBtns[a] = false; b.classList.remove('on'); e.preventDefault(); };
      b.addEventListener('touchend', up, { passive: false }); b.addEventListener('touchcancel', up, { passive: false });
    });
  },
  setDevice(d) {
    if (this.device === d) return;
    this.device = d; Bus.emit('inputDevice', d);
    $('touch').classList.toggle('hidden', d !== 'touch' || Game.mode !== 'play');
  },
  hint(a) { return '[' + (HINTS[this.device][a] || a) + ']'; },
  poll() {
    // Önceki durum
    for (const a of ACTIONS) this.prev[a] = this.down[a];
    const k = this.keys, D = {};
    for (const code in KEYMAP) if (k[code]) D[KEYMAP[code]] = true;
    if (k.Mouse0) D.attack = true; if (k.Mouse2) D.heavy = true;
    for (const a in this.touchBtns) if (this.touchBtns[a]) D[a] = true;
    // Hareket
    let mx = (k.KeyD || k.ArrowRight ? 1 : 0) - (k.KeyA || k.ArrowLeft ? 1 : 0);
    let my = (k.KeyW || k.ArrowUp ? 1 : 0) - (k.KeyS || k.ArrowDown ? 1 : 0);
    let lx = this.mouse.dx * 0.0025 * Settings.sens, ly = this.mouse.dy * 0.0025 * Settings.sens;
    this.mouse.dx = this.mouse.dy = 0;
    lx += this.touchLook.x * 0.006 * Settings.sens; ly += this.touchLook.y * 0.006 * Settings.sens; this.touchLook.x = this.touchLook.y = 0;
    if (Math.abs(this.touchMove.x) + Math.abs(this.touchMove.y) > 0.05) { mx = this.touchMove.x; my = this.touchMove.y; if (Math.hypot(mx, my) > 0.92) D.sprint = true; }
    this.throttle = my > 0 ? my : 0; this.brake = my < 0 ? -my : 0;
    // Gamepad
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    const gp = pads && Array.from(pads).find(p => p && p.connected);
    if (gp) {
      const dz = (v) => Math.abs(v) < 0.15 ? 0 : v;
      const ax = dz(gp.axes[0] || 0), ay = dz(gp.axes[1] || 0), rx = dz(gp.axes[2] || 0), ry = dz(gp.axes[3] || 0);
      let any = ax || ay || rx || ry;
      gp.buttons.forEach((b, i) => { if (b.pressed) { any = true; const a = PAD[i]; if (a) D[a] = true; } });
      if (any) this.setDevice('pad');
      if (this.device === 'pad') {
        if (ax || ay) { mx = ax; my = -ay; }
        lx += rx * 0.05 * Settings.sens; ly += ry * 0.04 * Settings.sens;
        const rt = gp.buttons[7]?.value || 0, lt = gp.buttons[6]?.value || 0;
        if (Game.player?.vehicle) { this.throttle = Math.max(this.throttle, rt, my > 0.3 ? my : 0); this.brake = Math.max(this.brake, lt); if (gp.buttons[0]?.pressed) D.handbrake = true; if (gp.buttons[3]?.pressed) { D.vehicle = true; D.heavy = false; } if (gp.buttons[2]?.pressed) { D.horn = true; D.attack = false; } }
        if (gp.buttons[3]?.pressed && Game.player && !Game.player.vehicle && Vehicles.nearest(Game.player.pos, 4)) { D.vehicle = true; }
        if (gp.buttons[1]?.pressed && Game.player?.dragon) D.dragon = true;
        if (gp.buttons[11]?.pressed) D.descend = true;
      }
    }
    if (Game.player?.vehicle && k.Space) D.handbrake = true;
    if (Settings.invertY) ly = -ly;
    this.move.x = clamp(mx, -1, 1); this.move.y = clamp(my, -1, 1);
    this.look.x = lx; this.look.y = ly;
    this.down = D;
    if (this.mouse.wheel) { if (this.mouse.wheel > 0) D.next = true; else D.prev = true; this.mouse.wheel = 0; }
  },
  isDown(a) { return !!this.down[a]; },
  pressed(a) { return !!this.down[a] && !this.prev[a]; },
  released(a) { return !this.down[a] && !!this.prev[a]; },
  consume(a) { this.prev[a] = true; }
};
