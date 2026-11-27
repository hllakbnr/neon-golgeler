// ============================================================================
//  VERİ KATMANI — karakterler, mekanlar, silahlar, araçlar, görevler,
//  diyaloglar, sinematikler, yan içerik, radyo. (Admin panelinden JSON olarak
//  dışa/içe aktarılabilir; DATA_OVERRIDE_KEY altında saklanır.)
// ============================================================================
const DATA_OVERRIDE_KEY = 'ng_data_override_v1';

// ------------------------------------------------------------------ Karakterler
// look: blok oyuncak figür tarifi (06_figure.js okur). Admin panelinden her
// karakter kimliğine .glb/.obj model atanabilir; atanmışsa prosedürel figür yerine o kullanılır.
const CAST = {
  Hero_Main: {
    name: 'Kaan Demir', element: 'Metal', color: '#c9d3df',
    looks: {
      civil: { skin: '#f1c9a0', hair: { style: 'spiky', color: '#141418' }, eyes: '#3a2a1a', torso: '#17171d', jacket: '#59606c', arms: '#59606c', hands: '#f1c9a0', legs: '#2a3550', shoes: '#e2e2e2', belt: '#3a3a3a' },
      ninja: { skin: '#f1c9a0', hair: { style: 'spiky', color: '#141418' }, eyes: '#3a2a1a', torso: '#2b2f3a', plate: '#b9c3cf', arms: '#2b2f3a', hands: '#1b1d22', legs: '#2b2f3a', shoes: '#1b1d22', belt: '#ff8a1f', emblem: { shape: 'gear', color: '#ff8a1f' }, shoulder: '#b9c3cf' }
    },
    mask: '#8d97a3'
  },
  Ally_Partner: {
    name: 'Ela Poyraz', element: 'Rüzgar', color: '#7fffe0',
    looks: {
      civil: { skin: '#e8b48f', hair: { style: 'braid', color: '#5a2a8a' }, eyes: '#c07a10', torso: '#f2efe6', jacket: '#d9a21b', arms: '#d9a21b', hands: '#e8b48f', legs: '#5c6b3a', shoes: '#f4f4f4', belt: '#3b2a1a' },
      ninja: { skin: '#e8b48f', hair: { style: 'braid', color: '#5a2a8a' }, eyes: '#c07a10', torso: '#2fb3a5', plate: '#eafffb', arms: '#2fb3a5', hands: '#1d4d48', legs: '#1d4d48', shoes: '#eafffb', belt: '#eafffb', emblem: { shape: 'swirl', color: '#eafffb' } }
    },
    mask: '#eafffb'
  },
  Master_Lightning: { name: 'Ray', element: 'Şimşek', color: '#ffd23b', look: { skin: '#d9a77c', hair: { style: 'visor', color: '#1d2a6b' }, torso: '#ffd23b', plate: '#ffffff', arms: '#ffffff', hands: '#ffd23b', legs: '#ffffff', shoes: '#1d2a6b', belt: '#1d2a6b', emblem: { shape: 'bolt', color: '#1d2a6b' } } },
  Master_Fire: { name: 'Kor', element: 'Ateş', color: '#ff6a1f', look: { skin: '#c58a62', hair: { style: 'crest', color: '#ffb020' }, torso: '#ff6a1f', plate: '#2b2b2b', arms: '#2b2b2b', hands: '#ff6a1f', legs: '#2b2b2b', shoes: '#ffb020', belt: '#ffb020', emblem: { shape: 'flame', color: '#ffe28a' } } },
  Master_Water: { name: 'Derya', element: 'Su', color: '#38d6ff', look: { skin: '#8d5a3b', hair: { style: 'hood', color: '#7fe6ff' }, torso: '#0f6f8a', plate: '#7fe6ff', arms: '#0f6f8a', hands: '#7fe6ff', legs: '#0a4d61', shoes: '#7fe6ff', belt: '#ffffff', emblem: { shape: 'wave', color: '#ffffff' }, cape: '#38d6ff' } },
  Master_Earth: { name: 'Taşkın', element: 'Toprak', color: '#a8916a', look: { skin: '#b07a55', hair: { style: 'bald', color: '#4a3a2a' }, torso: '#7a7a6a', plate: '#a8916a', arms: '#7a7a6a', hands: '#4d5a2a', legs: '#4d5a2a', shoes: '#3a2f22', belt: '#3a2f22', emblem: { shape: 'rock', color: '#d8c79a' }, shoulder: '#a8916a', scale: 1.12 } },
  Master_Ice: { name: 'Ayaz', element: 'Buz', color: '#bff4ff', look: { skin: '#f0d7c4', hair: { style: 'crown', color: '#e8fbff' }, torso: '#bff4ff', plate: '#ffffff', arms: '#bff4ff', hands: '#2a3a6b', legs: '#2a3a6b', shoes: '#e8fbff', belt: '#2a3a6b', emblem: { shape: 'flake', color: '#2a3a6b' } } },
  Master_Green: { name: 'Filiz', element: 'Doğa', color: '#6fbf3a', look: { skin: '#e2b08a', hair: { style: 'leaf', color: '#2f7a1f' }, torso: '#6fbf3a', plate: '#c8f08a', arms: '#6fbf3a', hands: '#6b4a2a', legs: '#6b4a2a', shoes: '#3a2a1a', belt: '#c8f08a', emblem: { shape: 'leaf', color: '#2f7a1f' }, cape: '#4a9a2a' } },
  Mentor_Master: { name: 'Hikmet Usta', color: '#e8d8b0', look: { skin: '#e6c3a0', hair: { style: 'elder', color: '#f2f2f2' }, torso: '#7a1f2a', plate: '#e8d8b0', arms: '#e8d8b0', hands: '#e6c3a0', legs: '#4a3a2a', shoes: '#2a1f1a', belt: '#c9a227', beard: '#f2f2f2', cane: true, scale: 0.92 } },
  NPC_DojoGuy: { name: 'Turbo Tarık', color: '#ff2fd6', look: { skin: '#d9a77c', hair: { style: 'pompadour', color: '#2a1a0a' }, torso: '#ff2fd6', jacket: '#7a1fff', arms: '#7a1fff', hands: '#d9a77c', legs: '#7a1fff', shoes: '#ffd23b', belt: '#ffd23b', glasses: '#111111' } },
  NPC_NoodleChef: { name: 'Şef Noda', color: '#ffffff', look: { skin: '#f0c8a0', hair: { style: 'chef', color: '#ffffff' }, torso: '#ffffff', arms: '#ffffff', hands: '#f0c8a0', legs: '#2a2a2a', shoes: '#2a2a2a', belt: '#ff3b3b', apron: '#ff3b3b' } },
  Boss_Architect: { name: 'Mimar', color: '#ff2fd6', look: { skin: '#cfcfd8', hair: { style: 'crest', color: '#c9a227' }, torso: '#111118', plate: '#c9a227', arms: '#111118', hands: '#c9a227', legs: '#111118', shoes: '#c9a227', belt: '#c9a227', emblem: { shape: 'core', color: '#ff2fd6' }, shoulder: '#c9a227', cape: '#3a0a4a', scale: 1.3 } },
  Boss_Hook: { name: 'Liman Reisi Kanca', color: '#b6ff3b', look: { skin: '#c58a62', hair: { style: 'bald', color: '#000' }, torso: '#3a1f5a', jacket: '#5a2a8a', arms: '#5a2a8a', hands: '#9aa3ad', legs: '#222', shoes: '#111', belt: '#b6ff3b', beard: '#2a1a0a', scale: 1.2 } },
  Radio_NewsHost: { name: 'Selin Sinyal', color: '#ffe9a8' },
  Gang: { name: 'Kapsül Karteli', look: { skin: '#d9a77c', hair: { style: 'band', color: '#b6ff3b' }, torso: '#3a1f5a', jacket: '#5a2a8a', arms: '#5a2a8a', hands: '#d9a77c', legs: '#1f1f2a', shoes: '#111', belt: '#b6ff3b' } },
  Elite: { name: 'Çekirdek Muhafızı', look: { skin: '#888', hair: { style: 'visor', color: '#ff2fd6' }, torso: '#111118', plate: '#ff2fd6', arms: '#111118', hands: '#333', legs: '#111118', shoes: '#333', belt: '#ff2fd6', emblem: { shape: 'core', color: '#ff2fd6' }, shoulder: '#333' } },
  Police: { name: 'Devriye', look: { skin: '#d9a77c', hair: { style: 'cap', color: '#13234a' }, torso: '#1f3a7a', arms: '#1f3a7a', hands: '#d9a77c', legs: '#13234a', shoes: '#111', belt: '#ffd23b', emblem: { shape: 'badge', color: '#ffd23b' } } },
  Guard: { name: 'Ada Muhafızı', look: { skin: '#c58a62', hair: { style: 'visor', color: '#222' }, torso: '#4a4f3a', arms: '#4a4f3a', hands: '#222', legs: '#33382a', shoes: '#111', belt: '#ff3b3b', shoulder: '#33382a' } }
};
const CIV_PALETTE = {
  skins: ['#f1c9a0', '#e2b08a', '#c58a62', '#8d5a3b', '#f0d7c4', '#d9a77c'],
  tops: ['#ff3b6b', '#3bb0ff', '#ffd23b', '#7a5cff', '#2fd67a', '#ff8a1f', '#f4f4f4', '#222831', '#ff7ad9', '#20c9b0'],
  legs: ['#2a3550', '#3a3a3a', '#6b4a2a', '#d8d0b8', '#1f1f2a', '#5c6b3a'],
  hairs: ['#141418', '#5a3a1a', '#c9a227', '#8a2a1a', '#e8e8e8', '#2a1a0a'],
  styles: ['short', 'short', 'long', 'bun', 'spiky', 'bald', 'cap', 'ponytail']
};

// ------------------------------------------------------------------ Mekanlar
// Şehir ızgarası: yol merkezleri 80'in katlarında; bloklar 60x60.
const LOC = {
  harborGate: [-320, 488], docks: [-400, 520], pier2: [-360, 600], warehouse: [-440, 440],
  harborSafe: [-280, 368], cartelHide: [-520, 372], teahouse: [-360, -26], bazaar: [-280, 40],
  weaponShop: [-200, 136], garage: [-200, 292], noodle: [-40, 142], backroom: [-40, 97],
  smoothie: [40, 58], dojo: [120, -18], gym: [40, 302], restaurant: [120, 222],
  neonSafe: [-40, -272], policeHQ: [200, 62], neonStart: [0, -160],
  techTower: [280, -254], towerRoof: [280, -280], relay1: [200, -200], relay2: [360, -120], eastSafe: [280, 368],
  beach: [404, 500], bridgeEast: [432, 240], islandGate: [478, 240], prison: [560, 322],
  mountainBase: [-300, -172], monastery: [-345, -348], peakSecret: [-470, -470],
  hospital: [120, 382]
};
const DISTRICTS = [
  { id: 'Harbor_District', name: 'Liman', test: (x, z) => x < -150 && z > 160 },
  { id: 'Old_Bazaar', name: 'Eski Çarşı', test: (x, z) => x < -150 && z > -160 && z <= 160 },
  { id: 'Mountain', name: 'Dağ Manastırı', test: (x, z) => x < -150 && z <= -160 },
  { id: 'Neon_Boulevard', name: 'Neon Bulvar', test: (x, z) => x >= -150 && x < 160 },
  { id: 'Tech_Tower', name: 'Teknoloji Merkezi', test: (x, z) => x >= 160 && x < 420 && z <= 80 },
  { id: 'East_Res', name: 'Doğu Konutları', test: (x, z) => x >= 160 && x < 420 && z > 80 },
  { id: 'Secure_Island', name: 'Güvenlikli Ada', test: (x, z) => x >= 440 }
];
const districtAt = (x, z) => (DISTRICTS.find(d => d.test(x, z)) || { name: 'Açık Deniz', id: 'Sea' });

// ------------------------------------------------------------------ Silahlar
const WEAPONS = {
  fists: { name: 'Yumruk', icon: '👊', kind: 'melee', dmg: 9, range: 2.0, rate: 0.32, price: 0 },
  pipe: { name: 'Metal Boru', icon: '🔧', kind: 'melee', dmg: 16, range: 2.5, rate: 0.5, price: 60 },
  staff: { name: 'Bambu Sopa', icon: '🥢', kind: 'melee', dmg: 13, range: 3.0, rate: 0.38, price: 90 },
  chain: { name: 'Zincir', icon: '⛓', kind: 'melee', dmg: 14, range: 2.8, rate: 0.3, price: 140 },
  katana: { name: 'Neon Kılıç', icon: '🗡', kind: 'melee', dmg: 24, range: 2.8, rate: 0.42, price: 320 },
  shuriken: { name: 'Şuriken', icon: '✴', kind: 'ranged', dmg: 14, speed: 42, rate: 0.28, price: 120 },
  stun: { name: 'Şok Tabancası', icon: '🔫', kind: 'ranged', dmg: 20, speed: 60, rate: 0.5, price: 260 }
};

// ------------------------------------------------------------------ Araçlar
const VEHICLES = {
  motor: { name: 'Hurda Motor', kind: 'bike', max: 44, acc: 22, grip: 2.6, hp: 80, len: 2.2, wid: 0.8, h: 1.0, color: '#ff8a1f', price: 400 },
  sport: { name: 'Neon GT', kind: 'car', max: 52, acc: 20, grip: 2.2, hp: 120, len: 4.4, wid: 2.0, h: 1.1, color: '#ff2fd6', price: 1800 },
  street: { name: 'Sokak Sedanı', kind: 'car', max: 36, acc: 12, grip: 1.8, hp: 150, len: 4.6, wid: 2.1, h: 1.5, color: '#3bb0ff', price: 700 },
  heavy: { name: 'Liman Kamyonu', kind: 'truck', max: 26, acc: 7, grip: 1.3, hp: 320, len: 7.5, wid: 2.8, h: 3.0, color: '#ffd23b', price: 1200 },
  police: { name: 'Devriye Aracı', kind: 'car', max: 46, acc: 17, grip: 2.0, hp: 200, len: 4.6, wid: 2.1, h: 1.5, color: '#f4f4f4', price: 0 },
  van: { name: 'Kartel Vanı', kind: 'truck', max: 32, acc: 10, grip: 1.5, hp: 220, len: 5.4, wid: 2.4, h: 2.4, color: '#5a2a8a', price: 0 }
};
const MOD_OPTIONS = {
  colors: ['#ff2fd6', '#20f0ff', '#b6ff3b', '#ffb020', '#ff3b3b', '#f4f4f4', '#141418', '#7a5cff', '#ff8a1f'],
  speed: [0, 150, 350, 600], armor: [0, 120, 260, 450], grip: [0, 100, 220, 380]
};

// ------------------------------------------------------------------ Düşman tipleri
const ENEMY_TYPES = {
  gang: { cast: 'Gang', hp: 40, dmg: 7, speed: 4.6, team: 'gang', rep: 1, money: 12 },
  gangGun: { cast: 'Gang', hp: 35, dmg: 8, speed: 4.2, team: 'gang', ranged: true, rep: 1, money: 18 },
  guard: { cast: 'Guard', hp: 60, dmg: 9, speed: 4.4, team: 'gang', ranged: true, rep: 1, money: 20 },
  elite: { cast: 'Elite', hp: 85, dmg: 12, speed: 5.2, team: 'gang', rep: 2, money: 30 },
  drone: { cast: 'Elite', hp: 30, dmg: 6, speed: 6.5, team: 'gang', ranged: true, fly: true, rep: 1, money: 10 },
  police: { cast: 'Police', hp: 55, dmg: 8, speed: 5.0, team: 'police', rep: 0, money: 0 },
  hook: { cast: 'Boss_Hook', hp: 320, dmg: 14, speed: 4.8, team: 'gang', boss: true, rep: 8, money: 300 },
  kor: { cast: 'Master_Fire', hp: 420, dmg: 15, speed: 6.0, team: 'gang', boss: true, ranged: true, rep: 8, money: 0 },
  mimar: { cast: 'Boss_Architect', hp: 1200, dmg: 18, speed: 5.4, team: 'gang', boss: true, ranged: true, rep: 20, money: 0 }
};

// ------------------------------------------------------------------ Diyaloglar
// Satır: {who,text} · Seçim: {choice:[{text, bond, moral, flag, money, reply:{who,text}}]}
const DIALOGUES = {
  d11_intro: [
    { who: 'Hikmet Usta', text: 'Kaan! Rıhtımdaki vardiyan bitmeden telsizden kartel konuşmaları geldi. Konteynerleri yağmalayacaklar.' },
    { who: 'Kaan', text: 'Tamir ettiğim forkliftleri de kırarlarsa maaşımı kimden alacağım usta? Hallederim.' },
    { who: 'Hikmet Usta', text: 'Önce dinle. Üzerinde sınırlı yer var; ne taşıyacağını seç. Yüzünü de gizle — şehir seni henüz tanımıyor.' },
    { who: 'İpucu', text: 'Silah tekerleği: [Q] / LB / 🗡 · Gardırop: [O] / D-Sağ / 👕 · Maske: [K] / D-Sol / 😷' }
  ],
  d12_mentor: [
    { who: 'Hikmet Usta', text: 'Bedenin metal gibi sertleşiyor, ama kafan hâlâ yumuşak. Gücün eldivende değil, sende.' },
    { who: 'Kaan', text: 'Usta, bu metal işi yumruğa iyi geliyor ama… havada dönmek mi? Ciddi misin?' },
    { who: 'Hikmet Usta', text: 'Rüzgârın içinde dönen yaprak kırılmaz. Ağırlığını merkeze topla, sonra bırak. Kasırga ol.' },
    { who: 'İpucu', text: 'Kasırga Dönüşü açıldı: [1] / D-Yukarı / KASIRGA. Enerji harcar.' }
  ],
  d13_garage: [
    { who: 'Usta Rüstem', text: 'Motoru geri getiren sen misin? Kartelin elinden kurtulmuş tek parça bu. Garaja bırak, sana modifiye dükkanımı açayım.' },
    { who: 'Kaan', text: 'Egzozu ben kaynatmıştım zaten. Rengini de değiştirelim, kimse tanımasın.' }
  ],
  d15_safe: [
    { who: 'Kaan', text: 'Liman üstünde bir oda, eski bir dolap ve sızdıran bir çatı. Ev gibi.' },
    { who: 'Hikmet Usta', text: 'Fazla silahları depoya bırak, kostümünü gardıroba as. Yolda hafif olan hayatta kalır.' },
    { who: 'İpucu', text: 'Güvenli evde [E]: Depo, Gardırop, Kaydet ve Uyku (saati ilerletir).' }
  ],
  d16_hook: [
    { who: 'Kanca', text: 'Tamirci çocuk! Benim limanımda kahramanlık mı oynuyorsun?' },
    { who: 'Kaan', text: 'Senin liman mı? Tapusunu göster, ben de forkliftimi göstereyim.' }
  ],
  d16_choice: [
    { who: 'Kanca', text: 'Tamam, tamam! Kapsülleri kim aldı söylerim… Yeter ki bırak beni.' },
    { choice: [
      { text: 'Polise teslim et. Liman insanları rahat nefes alsın.', moral: 1, rep: 3, reply: { who: 'Kaan', text: 'Söyleyeceklerini emniyette anlatırsın Kanca.' } },
      { text: 'Bilgiyi al, sonra rıhtıma bırak — herkes görsün.', moral: -1, rep: 2, reply: { who: 'Kaan', text: 'Herkes bilsin bu liman artık kimseye ait değil.' } }
    ] },
    { who: 'Kanca', text: 'Kapsüller Neon Bulvar\'a gidiyor… Teknoloji kulesine. Mimar denen biri topluyor hepsini.' }
  ],
  d21_kor: [
    { who: 'Kor', text: 'Yarışı kazanmak için yolu yakmak gerekir, tamirci. Hızlıydın — ama yeterince değil.' },
    { who: 'Kaan', text: 'Sen kimsin, ateşli kask? Lastiklerimi eritiyorsun!' },
    { who: 'Kor', text: 'Bir gün aynı tarafta olabiliriz. Ya da olmayız. Kule\'ye bak, orada her şey başlıyor.' }
  ],
  d22_meet: [
    { who: '???', text: 'Bir adım daha atarsan seni rüzgârla çatıdan aşağı uçururum, Metal Çocuk.' },
    { who: 'Kaan', text: 'Metal Çocuk mu? Adım Kaan. Kaan Demir. Sen de bu çatıda turist değilsin galiba.' },
    { who: 'Ela', text: 'Ela. Ela Poyraz. Mimar\'ın kapsül sevkiyatını üç haftadır izliyorum ve sen gelip alarmları çaldırdın.' },
    { who: 'Kaan', text: 'Alarmı ben çaldırmadım Ela — şu ayak sesleri de benim değil.' },
    { who: 'Ela', text: 'Harika. Pusu. Kaan, sırtını bana ver ve şu yumruklarının gerçekten metal olduğunu kanıtla.' }
  ],
  d22_after: [
    { who: 'Ela', text: 'Fena değildin Kaan. Biraz gürültülü, biraz kaba… ama güvenilir.' },
    { choice: [
      { text: '"Sen de fena değildin. Rüzgârın sırtımı kolladı."', bond: 6, reply: { who: 'Ela', text: 'Alışma. Ama… teşekkürler.' } },
      { text: '"Bir dahaki sefere beni çatıdan atmakla tehdit etme."', bond: 2, reply: { who: 'Ela', text: 'Söz vermem. Ama önce uyarırım.' } }
    ] },
    { who: 'Ela', text: 'Numaramı telefonuna kaydettim. Smoothie dükkânında buluşalım — şifreleri birlikte çözeriz.' }
  ],
  d23_smoothie: [
    { who: 'Ela', text: 'Mango-ejder meyvesi. Şekersiz. Beynim böyle çalışıyor.' },
    { who: 'Kaan', text: 'Ben çift şekerli alayım, kasırga dönüşü yapınca tansiyonum düşüyor.' },
    { choice: [
      { text: '"Neden tek başına bu işe girdin Ela?"', bond: 6, reply: { who: 'Ela', text: 'Kardeşim kulede çalışıyordu. Bir gece eve dönmedi. Bu yüzden.' } },
      { text: '"Şifreleri çözelim, laf kalabalığına gerek yok."', bond: 2, reply: { who: 'Ela', text: 'Pratik. Bunu sevdim.' } }
    ] },
    { who: 'Ela', text: 'Bu şifreler enerji aktarıcılarına ait. Şehirde iki tane var. Ray ve Derya da onları izliyor.' }
  ],
  d24_masters: [
    { who: 'Ray', text: 'Ben Ray. Şimşek benim işim. Aktarıcı bobinlerini ben aşırı yüklerim, siz muhafızları dağıtın.' },
    { who: 'Derya', text: 'Derya. Su soğutma hatlarını keserim. Ela, Kaan — bize zaman kazandırın.' }
  ],
  d25_core: [
    { who: 'Ela', text: 'Veri çekirdeği burada… Mimar sadece kapsül toplamıyor Kaan. Altı elementin enerjisini tek çekirdekte birleştiriyor.' },
    { who: 'Kaan', text: 'Ve bunu şehre yaparsa ne olur?' },
    { who: 'Ela', text: 'Şehir bir pil olur. Biz de içindeki toz.' }
  ],
  d26_recognized: [
    { who: 'Komiser Aras', text: 'Maskeli tamirci… ve rüzgâr kızı. Bugün bu şehri siz kurtardınız.' },
    { who: 'Komiser Aras', text: 'Teşkilat artık sizi tanıyor. Bundan sonra peşinizde değiliz — yanınızdayız. Suçlular sizin, kanun bizim.' },
    { who: 'Kaan', text: 'Duydun mu Ela? Artık gerçek ninjayız.' },
    { who: 'Ela', text: 'Gerçek ninjalar bunu yüksek sesle söylemez Kaan.' }
  ],
  d31_earth: [
    { who: 'Taşkın', text: 'Dağ sabırsızları sevmez. Benim taşlarım üzerine yağarken dimdik durabilirsen geçersin.' },
    { who: 'Kaan', text: 'Metal sertleşmesi taşa karşı. Bu adil bir dövüş bile değil.' }
  ],
  d32_glide: [
    { who: 'Ayaz', text: 'Soğuk hava ağırdır, sıcak hava hafiftir. Sen ikisinin arasında süzüleceksin.' },
    { who: 'Filiz', text: 'Kanatların yok ama yaprakların da yok. Yine de düşüyorlar mı? Hayır, süzülüyorlar.' },
    { who: 'Ela', text: 'Ben de rüzgârımla alttan iterim. Atla Kaan — bana güven.' },
    { who: 'İpucu', text: 'Havada Süzülme açıldı: havadayken [Boşluk]/A/ZIPLA basılı tut.' }
  ],
  d33_dragon: [
    { who: 'Hikmet Usta', text: 'Metal soğuktur, ama ruhun sıcak. İkisini birleştirdiğinde ejderha uyanır.' },
    { who: 'Kaan', text: 'Bir ejderha mı? Usta, ben forklift kullanmayı bile zor öğrendim.' },
    { who: 'İpucu', text: 'Metal Ejderhası: [2] / D-Aşağı / EJDER. Uçarken [Boşluk] yüksel, [Shift] alçal, [Sol tık] metal parça fırlat, [2] in.' }
  ],
  d34_rescue: [
    { who: 'Hikmet Usta', text: 'Kaan… Ela… Bu yaşlı adam için adaya mı çıktınız? Deli çocuklar.' },
    { who: 'Ela', text: 'Usta, Mimar ne istiyordu senden?' },
    { who: 'Hikmet Usta', text: 'Çay evinin altındaki eski haritaları. Üssün yerini. Çabuk dönmeliyiz.' }
  ],
  d35_betray: [
    { who: 'Kor', text: 'Üzgünüm. Mimar bana ateşin sonsuz olacağını söyledi. Söndürülmeyen bir ateş…' },
    { who: 'Ela', text: 'Kor! Ray ve Derya sana güveniyordu!' },
    { who: 'Mimar', text: 'Güven, kırılmak için yapılmış bir yapıdır. Ben mimarım; yapıları bilirim.' },
    { who: 'Kaan', text: 'Bırak onları! Benimle uğraş!' },
    { who: 'Mimar', text: 'Seninle uğraşmak mı? Sen sadece metalsin, tamirci. Ben ise çekirdeğim.' }
  ],
  d41_curfew: [
    { who: 'Radyo', text: 'SIKIYÖNETİM: Saat 22:00 sonrası sokağa çıkmak yasaktır. Çekirdek Muhafızları devriyede.' },
    { who: 'Ela', text: 'Bize kalan tek şey yeraltı ağı. Üç bağlantı noktası, üç güvenilir insan. Görünmeden gideceğiz.' }
  ],
  d42_choice: [
    { who: 'Ela', text: 'Depoda Mimar\'ın kapsül stoğu var… ve içeride zorla çalıştırılan liman işçileri.' },
    { who: 'Taşkın', text: 'Depoyu havaya uçurursak Mimar\'ın üçte bir gücü gider. Bugün. Şimdi.' },
    { who: 'Hikmet Usta', text: 'Ya da önce insanları çıkarırsınız. Daha yavaş, daha riskli. Ama doğru olan.' },
    { choice: [
      { text: 'SERT YOL: Depoyu hemen uçur. Mimar bedelini ödesin.', moral: -3, flag: 'vengeful', reply: { who: 'Kaan', text: 'Yeterince bekledik. Şimdi o kaybedecek.' } },
      { text: 'KORUYUCU YOL: Önce işçileri tahliye et, sonra kapsülleri etkisiz bırak.', moral: 3, flag: 'protective', bond: 5, reply: { who: 'Kaan', text: 'Kimseyi geride bırakmıyoruz. Bu yüzden bizi tanıyorlar.' } }
    ] }
  ],
  d43_found: [
    { who: 'Ray', text: 'Kaan! Biliyordum geleceğini. Kafes bobinleri kısa devre yaptı — teşekkürler.' },
    { who: 'Derya', text: 'Ayaz ve Filiz kulenin alt katlarında. Hepimizi çekirdeğe bağlayacaklardı.' }
  ],
  d44_plan: [
    { who: 'Ela', text: 'Plan basit: Ray ve Derya alt katlar, Taşkın, Ayaz ve Filiz teraslar. Kaan ve ben zirve.' },
    { who: 'Kaan', text: 'Basit planlar hep bir yerde patlar.' },
    { who: 'Ela', text: 'O zaman patladığı yerde ben olayım. Yanında.' },
    { choice: [
      { text: '"Bu bitince seninle gün doğumunu izlemek istiyorum Ela."', bond: 8, reply: { who: 'Ela', text: 'O zaman hayatta kal, Kaan Demir. Bu bir emir.' } },
      { text: '"Ne olursa olsun, şehri kurtaracağız."', bond: 3, reply: { who: 'Ela', text: 'Şehri. Ve birbirimizi.' } },
      { text: '"Mimar\'ın gücünü ben alırsam, kimse bir daha bize dokunamaz."', bond: -4, moral: -2, reply: { who: 'Ela', text: '…Bunu duymamış olayım Kaan.' } }
    ] }
  ],
  d52_kor_good: [
    { who: 'Kor', text: 'Kaan… Mimar\'ın ateşi sönmez dediği şey beni yakıyor. Bitir şunu.' },
    { who: 'Kaan', text: 'Seni bitirmeye gelmedim Kor. Çıkarmaya geldim. Tut elimi.' },
    { who: 'Kor', text: '…Arkanı kollayacağım. Bu sefer gerçekten.' }
  ],
  d52_kor_dark: [
    { who: 'Kor', text: 'İntikam mı istiyorsun tamirci? Benim gibi oldun.' },
    { who: 'Kaan', text: 'Hayır Kor. Ben kazanıyorum.' }
  ],
  d53_boss: [
    { who: 'Mimar', text: 'Altı element, bir çekirdek, tek bir irade. Şehir bana ait olacak, tamirci.' },
    { who: 'Kaan', text: 'Şehir kimsenin değil. Ama bu çatı… bu çatı benim.' },
    { who: 'Ela', text: 'Kaan, çekirdeği koruyan kalkan dönerken açılıyor. Kasırganı kullan!' }
  ],
  d53_final: [
    { who: 'Mimar', text: 'Yapamazsın… çekirdek… artık senin…' },
    { who: 'Ela', text: 'Kaan, çekirdek kararsız! Ne yapacaksan şimdi yap!' }
  ],
  // ---- Yan görev & aktivite diyalogları
  s_tarik1: [
    { who: 'Turbo Tarık', text: 'Sen! Kaslı tamirci! Bana bir kahraman sahnesi lazım. Öğrencilerim "kötü adam" olacak, ben onları yeneceğim, sen de alkışlayacaksın!' },
    { who: 'Kaan', text: 'Bu… acayip derecede utanç verici.' },
    { who: 'Turbo Tarık', text: 'İki yüz lira.' },
    { who: 'Kaan', text: 'Alkışlarım çok profesyoneldir.' }
  ],
  s_tarik1_end: [
    { who: 'Turbo Tarık', text: 'Gerçek kartelciler mi?! Ben… ben stratejik olarak geri çekiliyordum! Yine de çekim harika oldu!' }
  ],
  s_tarik2: [
    { who: 'Turbo Tarık', text: 'Haberlere çıktım! "Kasırga Tarık şehri kurtardı!" Ama şampiyonluk kemerim çalındı. Benim adıma geri alır mısın?' },
    { who: 'Kaan', text: 'Senin adına mı? Kemer de mi senin adına kazanılmıştı?' }
  ],
  s_tarik2_end: [
    { who: 'Turbo Tarık', text: 'Kemerim! Peki… bu sefer kameralara gerçeği söyleyeceğim. Belki. Bir kısmını.' }
  ],
  s_noodle1: [
    { who: 'Şef Noda', text: 'Erişte soğursa ruhu kaçar! Üç adres, tek motor, sıcak teslimat! Koş!' }
  ],
  s_noodle2: [
    { who: 'Şef Noda', text: 'Gece vardiyası rıhtımda büyük sipariş. Ama dikkat… sipariş veren ses biraz fazla kartel gibiydi.' }
  ],
  s_racebet: [
    { who: 'Yarışçı Neon Nil', text: 'Gece yarısı, Neon Bulvar, yüz lira bahis. Kazanırsan üç yüz. Kaybedersen motorunu yıkarsın.' }
  ],
  s_parts: [
    { who: 'Usta Rüstem', text: 'Kartel kaçarken altı motor parçasını şehre saçmış. Toplarsan motoruna turbo takarım.' }
  ],
  s_patrol: [
    { who: 'Komiser Aras', text: 'Kartel devriyeleri hâlâ sokaklarda. Üç grubu dağıtırsan ödül benden.' }
  ],
  a_dinner: [
    { who: 'Ela', text: 'Bir restoranda, masada, silahsız oturuyoruz. Bu tuhaf.' },
    { choice: [
      { text: '"Tuhaf ama güzel. Bunu daha sık yapalım."', bond: 10, reply: { who: 'Ela', text: 'Tamam. Ama hesap senden.' } },
      { text: '"Menüde metal yok mu? Diş sertleştirmeye ihtiyacım var."', bond: 5, reply: { who: 'Ela', text: 'Gülmeyeceğim. …Tamam, güldüm.' } },
      { text: 'Telefona bak, görev haberlerini oku.', bond: 1, reply: { who: 'Ela', text: 'Ben de buradayım, haberin olsun.' } }
    ] }
  ],
  a_smoothie: [
    { who: 'Ela', text: 'Bu dükkânın çatısındaki dev ananasın her gece neden döndüğünü biliyor musun?' },
    { choice: [
      { text: '"Çünkü şehirdeki en mutlu şey o."', bond: 8, reply: { who: 'Ela', text: 'Sen yanındayken ikinci olabilir.' } },
      { text: '"Motoru bozuk, dönmeyi bırakamıyor. Tamir edeyim mi?"', bond: 5, reply: { who: 'Ela', text: 'Dokunma. Mükemmel bozuk.' } }
    ] }
  ],
  a_view: [
    { who: 'Ela', text: 'Buradan bakınca şehir gerçekten neon bir okyanus gibi.' },
    { who: 'Kaan', text: 'Ve biz o okyanusta yüzen iki inatçı balık.' },
    { choice: [
      { text: 'Sessizce omzuna yaslan.', bond: 6, reply: { who: 'Ela', text: '…Bir dakika daha kalalım.' } },
      { text: '"Rüzgâr senin için mi esiyor, yoksa sen mi estiriyorsun?"', bond: 5, reply: { who: 'Ela', text: 'Bazen ikisi de. Şu an… sana doğru esiyor.' } }
    ] }
  ],
  a_gym: [
    { who: 'Antrenör Demet', text: 'Torbaya 25 darbe, 20 saniye. Metal sertleşmesi yasak — dürüst kas!' }
  ],
  a_garage: [
    { who: 'Ela', text: 'Bana yeni modifiyeni göstereceksin, değil mi? Neon Bulvar, sahil yolu, ve geri. Hız sınırına uyacak mısın?' },
    { who: 'Kaan', text: 'Hız sınırı bir öneridir.' }
  ],
  e_chicken: [{ who: 'Teyze Saadet', text: 'Pamuk! Tavuğum Pamuk kaçtı! Kim yakalarsa ona en güzel börekleri yapacağım!' }],
  e_chicken_end: [{ who: 'Teyze Saadet', text: 'Pamuğum! Al evladım, börek de para da senin. Bir de dua!' }],
  e_teacup: [
    { who: 'Hikmet Usta', text: 'Bu fincan… ustamın ustasınındı. Dağ manastırına bırakmıştım; unuttum sanıyordum.' },
    { who: 'Hikmet Usta', text: 'Bir fincan çay, bir ömür sabır. Bunu hatırla Kaan.' }
  ],
  e_backroom: [{ who: 'Gizemli Ses', text: 'Neon Arka Oda\'ya hoş geldin. Şifreyi bilen az kişi vardır. Arcade makineleri bedava, kazandığın senin.' }],
  e_tape: [{ who: 'Kaset', text: '"…bu şehrin çatıları sırlarla dolu. Sembolleri bulan, frekansı bulur…" (Kaset FM açıldı)' }]
};

// ------------------------------------------------------------------ Sinematikler
// shot: wide | close | over | orbit | low | top | sky — on: oyuncu/aktör adı
// cast: {aktörAdı:[dx,dz,yönDerece,anim]} çapaya (at) göre konum
const CUTSCENES = {
  c_intro: { at: 'harborGate', title: 'NEON GÖLGELER', time: 21.5, cast: { kaan: [0, 0, 180, 'idle'] }, steps: [
    { shot: 'sky', dur: 4, sub: { who: '', text: 'Neon Şehir. Gece hiç bitmez, ışıklar hiç sönmez.' } },
    { shot: 'orbit', on: 'kaan', dur: 4, sub: { who: 'Kaan', text: 'Rıhtımda gece vardiyası. Forklift tamiri, kahve, sessizlik… normalde.' } },
    { shot: 'close', on: 'kaan', dur: 3, sub: { who: 'Kaan', text: 'Bu gece pek normal görünmüyor.' } }
  ] },
  c_12_in: { at: 'teahouse', time: 22, cast: { kaan: [0, 8, 180, 'idle'], hikmet: [0, -1, 0, 'hurt'] }, steps: [
    { shot: 'wide', on: 'hikmet', dur: 3, sub: { who: 'Hikmet Usta', text: 'Kaan! Çay evimi kırıyorlar!' } },
    { shot: 'low', on: 'kaan', dur: 3, sub: { who: 'Kaan', text: 'Usta\'nın semaverine dokunan… metalle tanışır.' } }
  ] },
  c_22_in: { at: 'techTower', time: 23, cast: { kaan: [0, 0, 180, 'idle'] }, steps: [
    { shot: 'sky', dur: 3, sub: { who: '', text: 'Teknoloji Kulesi. 170 metre neon ve sır.' } },
    { shot: 'low', on: 'kaan', dur: 3, sub: { who: 'Kaan', text: 'Asansör çatıya çıkıyor. Kanca\'nın dediği yer burası.' } }
  ] },
  c_26_out: { at: 'policeHQ', time: 8, cast: { kaan: [0, 0, 180, 'cheer'], ela: [2, 0, 180, 'cheer'] }, steps: [
    { shot: 'orbit', on: 'kaan', dur: 4, sub: { who: 'Selin Sinyal (Radyo)', text: 'Son dakika: Maskeli ikili şehri kurtardı! Emniyet: "Onlar artık bizden."' } },
    { shot: 'close', on: 'ela', dur: 3, sub: { who: 'Ela', text: 'Gerçek Ninja, ha? Buna alışma.' } }
  ] },
  c_33_out: { at: 'monastery', time: 6, cast: { kaan: [0, 0, 0, 'cheer'], hikmet: [-3, 2, 90, 'idle'], ela: [3, 2, 270, 'idle'] }, steps: [
    { shot: 'sky', dur: 3, sub: { who: 'Hikmet Usta', text: 'Ejderha uyandı. Ve şimdi… şimdi Mimar da uyanık.' } },
    { shot: 'close', on: 'hikmet', dur: 3, sub: { who: 'Haber', text: 'Bağlantı koptu — Hikmet Usta\'nın çay evi basıldı! (Usta adaya kaçırıldı)' } }
  ] },
  c_35_in: { at: 'teahouse', time: 23, weather: 'storm', cast: { kaan: [0, 12, 180, 'idle'], ela: [2, 12, 180, 'idle'], kor: [0, 5, 0, 'idle'], mimar: [0, 1, 0, 'idle'], ray: [-4, 3, 0, 'ko'], derya: [4, 3, 0, 'ko'] }, steps: [
    { shot: 'wide', on: 'kor', dur: 3, sub: { who: '', text: 'Üs. Gece yarısı. Kapı içeriden açılmış.' } },
    { shot: 'close', on: 'kor', dur: 3, sub: { who: 'Kor', text: 'Üzgünüm.' } },
    { shot: 'low', on: 'mimar', dur: 4, sub: { who: 'Mimar', text: 'Altı elementten ikisi elimde. Gerisi zaman meselesi.' } }
  ] },
  c_35_out: { at: 'teahouse', time: 1, weather: 'storm', cast: { kaan: [0, 4, 180, 'kneel'], ela: [2, 5, 200, 'idle'] }, steps: [
    { shot: 'top', on: 'kaan', dur: 4, sub: { who: '', text: 'Üs yıkıldı. Ray, Derya, Ayaz ve Filiz götürüldü.' } },
    { shot: 'close', on: 'ela', dur: 3, sub: { who: 'Ela', text: 'Kalk Kaan. Yas sonra. Önce onları geri alacağız.' } }
  ] },
  c_53_in: { at: 'towerRoof', y: 172, time: 4.5, weather: 'storm', cast: { kaan: [0, 8, 180, 'idle'], ela: [3, 8, 180, 'idle'], mimar: [0, -6, 0, 'idle'] }, steps: [
    { shot: 'sky', dur: 3, sub: { who: '', text: 'Kule zirvesi. Altı element bir çekirdekte uğulduyor.' } },
    { shot: 'low', on: 'mimar', dur: 3, sub: { who: 'Mimar', text: 'Hoş geldin tamirci. Gösteri başlıyor.' } }
  ] },
  end_good: { at: 'beach', time: 5.8, weather: 'clear', title: 'KORUYUCU FİNAL', cast: { kaan: [0, 0, 90, 'sit'], ela: [1.2, 0, 90, 'sit'] }, steps: [
    { shot: 'sky', dur: 4, sub: { who: '', text: 'Çekirdek parçalandı. Altı elementin gücü rüzgâra, toprağa, suya geri döndü.' } },
    { shot: 'orbit', on: 'kaan', dur: 4, sub: { who: 'Ela', text: 'Gün doğumu. Söz vermiştin, Kaan Demir.' } },
    { shot: 'close', on: 'kaan', dur: 4, sub: { who: 'Kaan', text: 'Ben sözümü tutarım, Ela Poyraz. Forklift garantisiyle.' } },
    { shot: 'wide', on: 'ela', dur: 5, sub: { who: '', text: 'Şehir uyanıyor. Bu sefer, korkmadan.' } }
  ] },
  end_dark: { at: 'towerRoof', y: 172, time: 0.5, weather: 'storm', title: 'SUÇ LORDU FİNALİ', cast: { kaan: [0, 0, 180, 'cheer'] }, steps: [
    { shot: 'low', on: 'kaan', dur: 4, sub: { who: '', text: 'Kaan çekirdeği kendi göğsüne mühürledi. Metal, ateş, rüzgâr — hepsi onun.' } },
    { shot: 'orbit', on: 'kaan', dur: 4, sub: { who: 'Kaan', text: 'Kartel, polis, Mimar… Artık hepsi bana rapor verecek.' } },
    { shot: 'sky', dur: 5, sub: { who: 'Selin Sinyal (Radyo)', text: 'Şehrin yeni efendisi: kimse adını yüksek sesle söylemiyor. Ela Poyraz\'dan haber alınamıyor.' } }
  ] },
  end_sacrifice: { at: 'bazaar', time: 9, weather: 'cloudy', title: 'FEDAKÂRLIK FİNALİ', cast: { kaan: [0, 8, 180, 'idle'], ela: [3, 12, 200, 'idle'] }, steps: [
    { shot: 'sky', dur: 4, sub: { who: '', text: 'Kaan, çekirdeği kendi gücüyle söndürdü. Metal, kasırga, ejderha — hepsi gitti.' } },
    { shot: 'close', on: 'kaan', dur: 4, sub: { who: 'Kaan', text: 'Ellerim artık sadece eller. Tamir için yeter.' } },
    { shot: 'wide', on: 'kaan', dur: 5, sub: { who: '', text: 'Çarşı kalabalığında sıradan bir tamirci. Ama arkasında bir rüzgâr hep esiyor.' } }
  ] },
  c_view: { at: 'towerRoof', y: 172, time: 20, cast: { kaan: [0, 10, 0, 'sit'], ela: [1.2, 10, 0, 'sit'] }, steps: [
    { shot: 'sky', dur: 4, sub: { who: '', text: 'Şehrin üstünde, neon bir sessizlik.' } },
    { shot: 'orbit', on: 'ela', dur: 4, sub: { who: '', text: '' } }
  ] },
  c_peak: { at: 'peakSecret', time: 6, cast: { kaan: [0, 0, 45, 'idle'] }, steps: [
    { shot: 'sky', dur: 5, sub: { who: '', text: 'Zirve Gizli Bakış Noktası. Bütün şehir, tek bakışta.' } },
    { shot: 'orbit', on: 'kaan', dur: 4, sub: { who: 'Kaan', text: 'Buradan bakınca her şey… tamir edilebilir görünüyor.' } }
  ] }
};

// ------------------------------------------------------------------ Ana görevler (24)
// Adım tipleri: cut, talk, choice, goto, fight, boss, race, chase, collect, skill,
// stealth, hold, drive, endure, focus, fly, escort, tp, unlock, set, func, ending
const MISSIONS = [
  // ===== PERDE 1 — Liman & Eski Çarşı
  { id: 'm11', act: 1, num: '1.1', title: 'Gece Vardiyası', at: 'harborGate', req: [], intro: 'c_intro', steps: [
    { t: 'talk', d: 'd11_intro' },
    { t: 'func', fn: 'giveWeapon', arg: 'pipe' },
    { t: 'wardrobe', text: 'Gardırobu aç ve Ninja Kostümüne geç, sonra maskeni tak.' },
    { t: 'goto', at: 'docks', r: 12, text: 'Rıhtıma git.' },
    { t: 'fight', text: 'Kartel baskınını püskürt!', waves: [{ type: 'gang', n: 4, at: 'docks' }, { type: 'gangGun', n: 2, at: 'docks' }] }
  ], reward: { money: 120, rep: 5 } },
  { id: 'm12', act: 1, num: '1.2', title: 'Çay Evindeki Kıvılcım', at: 'teahouse', req: ['m11'], intro: 'c_12_in', steps: [
    { t: 'fight', text: 'Çay evindeki saldırganları dağıt, Hikmet Usta\'yı kurtar.', waves: [{ type: 'gang', n: 5, at: 'teahouse' }] },
    { t: 'talk', d: 'd12_mentor' },
    { t: 'unlock', ability: 'tornado' },
    { t: 'skill', ability: 'tornado', count: 3, text: 'Kasırga Dönüşünü 3 kez kullan (antrenman kuklaları).', dummies: 4 }
  ], reward: { money: 80, rep: 5 } },
  { id: 'm13', act: 1, num: '1.3', title: 'Hurda Motor & Sokak Yarışı', at: 'garage', req: ['m12'], steps: [
    { t: 'func', fn: 'spawnVehicle', arg: { type: 'street', at: 'garage', dx: 8 } },
    { t: 'chase', text: 'Çalınan modifiye motoru kovala ve yakala!', target: 'motor', path: [[-160, 300], [-160, 160], [-80, 160], [-80, 0], [0, 0], [0, 160], [-80, 240], [-160, 240]], time: 120 },
    { t: 'drive', text: 'Motoru Hurda Garaj\'a geri getir.', to: 'garage', r: 10, needVehicle: 'motor' },
    { t: 'func', fn: 'ownVehicle', arg: 'motor' },
    { t: 'talk', d: 'd13_garage' },
    { t: 'set', flag: 'modShop' }
  ], reward: { money: 100, rep: 4 } },
  { id: 'm14', act: 1, num: '1.4', title: 'Rıhtım Depo Baskını', at: 'docks', req: ['m13'], steps: [
    { t: 'goto', at: 'warehouse', r: 14, text: 'Kartel deposuna sız.' },
    { t: 'fight', text: 'Konvoy muhafızlarını etkisiz bırak.', waves: [{ type: 'gang', n: 4, at: 'warehouse' }, { type: 'gangGun', n: 3, at: 'warehouse' }] },
    { t: 'func', fn: 'policeRaid', arg: 2 },
    { t: 'collect', text: 'Kaçak element kapsüllerini topla (polis geliyor!).', items: [[-452, 436], [-436, 450], [-462, 448], [-445, 446]], label: 'Kapsül' },
    { t: 'func', fn: 'clearWanted' }
  ], reward: { money: 200, rep: 6 } },
  { id: 'm15', act: 1, num: '1.5', title: 'İlk Güvenli Ev', at: 'harborSafe', req: ['m14'], steps: [
    { t: 'func', fn: 'unlockSafehouse', arg: 'harborSafe' },
    { t: 'talk', d: 'd15_safe' },
    { t: 'storage', text: 'Güvenli evde [E] ile Depoyu aç ve bir silahı depoya bırak.' }
  ], reward: { money: 50, rep: 2 } },
  { id: 'm16', act: 1, num: '1.6', title: 'Limanın Nabzı', at: 'cartelHide', req: ['m15'], steps: [
    { t: 'fight', text: 'Kanca\'nın adamlarını temizle.', waves: [{ type: 'gang', n: 5, at: 'cartelHide' }, { type: 'gangGun', n: 3, at: 'cartelHide' }] },
    { t: 'talk', d: 'd16_hook' },
    { t: 'boss', type: 'hook', at: 'cartelHide', text: 'Liman Reisi Kanca\'yı yen!' },
    { t: 'choice', d: 'd16_choice' },
    { t: 'func', fn: 'repLevel', arg: 20 }
  ], reward: { money: 300, rep: 8 } },
  // ===== PERDE 2 — Neon Bulvar & Teknoloji Merkezi
  { id: 'm21', act: 2, num: '2.1', title: 'Neon Geceleri', at: 'neonStart', req: ['m16'], night: true, steps: [
    { t: 'func', fn: 'spawnVehicle', arg: { type: 'sport', at: 'neonStart', dx: 6 } },
    { t: 'race', text: 'Neon Bulvar gece yarışı! Önce bitir.', vehicle: true, rivals: 2, rivalCast: 'Master_Fire', cps: [[0, -80], [0, 80], [0, 240], [80, 320], [160, 240], [160, 80], [80, 0], [0, -160]], time: 140 },
    { t: 'talk', d: 'd21_kor' }
  ], reward: { money: 250, rep: 6 } },
  { id: 'm22', act: 2, num: '2.2', title: 'Çatıdaki Ortak', at: 'techTower', req: ['m21'], night: true, intro: 'c_22_in', steps: [
    { t: 'tp', pos: [280, 172, -268] },
    { t: 'func', fn: 'spawnAllyAt', arg: [280, 172, -292] },
    { t: 'talk', d: 'd22_meet' },
    { t: 'func', fn: 'allyJoin' },
    { t: 'fight', text: 'Pusu! Ela ile sırt sırta savaş.', waves: [{ type: 'elite', n: 3, at: [280, -280], y: 172 }, { type: 'drone', n: 3, at: [280, -280], y: 172 }] },
    { t: 'tp', pos: [280, 0.2, -246] },
    { t: 'fight', text: 'Kule kapısından kaç — takipçileri durdur.', waves: [{ type: 'elite', n: 3, at: [280, -236] }] },
    { t: 'talk', d: 'd22_after' }
  ], reward: { money: 150, rep: 6, bond: 10 } },
  { id: 'm23', act: 2, num: '2.3', title: 'Smoothie Molası & İstihbarat', at: 'smoothie', req: ['m22'], steps: [
    { t: 'func', fn: 'allyJoin' },
    { t: 'talk', d: 'd23_smoothie' },
    { t: 'collect', text: 'Şifre çipleri: smoothie dükkânı çevresindeki kartel kuryelerinden düşenleri topla.', items: [[60, 100], [10, 20], [80, 30]], label: 'Şifre Çipi', guards: 'gang' }
  ], reward: { money: 120, rep: 4, bond: 8 } },
  { id: 'm24', act: 2, num: '2.4', title: 'Yıldırım ve Dalga', at: 'relay1', req: ['m23'], steps: [
    { t: 'talk', d: 'd24_masters' },
    { t: 'func', fn: 'spawnFriend', arg: ['ray', 'relay1'] },
    { t: 'hold', text: 'Ray aktarıcıyı aşırı yüklerken onu koru! (Aktarıcı 1)', at: 'relay1', time: 35, waves: [{ type: 'elite', n: 2 }, { type: 'gangGun', n: 3 }] },
    { t: 'func', fn: 'spawnFriend', arg: ['derya', 'relay2'] },
    { t: 'goto', at: 'relay2', r: 12, text: 'Aktarıcı 2\'ye git — Derya bekliyor.' },
    { t: 'hold', text: 'Derya soğutma hatlarını keserken muhafızları uzak tut!', at: 'relay2', time: 35, waves: [{ type: 'elite', n: 3 }, { type: 'drone', n: 2 }] }
  ], reward: { money: 220, rep: 7 } },
  { id: 'm25', act: 2, num: '2.5', title: 'Kule Sızması', at: 'techTower', req: ['m24'], night: true, steps: [
    { t: 'stealth', text: 'Gizlen: kameraların ışık konilerine girme, terminale ulaş. (Alarm = takviye)', at: [280, -222], goal: [300, -232], cams: [[262, -232, 0], [298, -214, 180], [280, -238, 90]], alarm: [{ type: 'elite', n: 3 }] },
    { t: 'talk', d: 'd25_core' },
    { t: 'goto', at: [200, -200], r: 10, text: 'Alarmlar çalıyor — kuleden uzaklaş!', time: 50 }
  ], reward: { money: 200, rep: 6, bond: 4 } },
  { id: 'm26', act: 2, num: '2.6', title: 'Gerçek Ninja', at: 'policeHQ', req: ['m25'], steps: [
    { t: 'func', fn: 'setWeather', arg: 'cloudy' },
    { t: 'hold', text: 'Mimar\'ın dronları Neon Bulvar\'a saldırıyor! Sivilleri koru.', at: [40, 60], time: 45, waves: [{ type: 'drone', n: 4 }, { type: 'elite', n: 3 }] },
    { t: 'boss', type: 'elite', bossName: 'Muhafız Komutanı', hp: 380, at: [40, 60], text: 'Muhafız Komutanını yen!' },
    { t: 'talk', d: 'd26_recognized' },
    { t: 'func', fn: 'recognizeNinja' }
  ], outro: 'c_26_out', reward: { money: 400, rep: 15, bond: 6 } },
  // ===== PERDE 3 — Dağ Manastırı, Gökyüzü & Güvenlikli Ada
  { id: 'm31', act: 3, num: '3.1', title: 'Zirveye Tırmanış', at: 'mountainBase', req: ['m26'], steps: [
    { t: 'goto', at: [-330, -260], r: 10, text: 'Dağ patikasından tırman.', time: 120 },
    { t: 'func', fn: 'spawnFriend', arg: ['taskin', [-330, -270]] },
    { t: 'talk', d: 'd31_earth' },
    { t: 'endure', text: 'Metal sertleşmesini aç ([R]/RB/METAL) ve taş yağmuruna 15 sn dayan!', at: [-330, -270], time: 15 },
    { t: 'goto', at: 'monastery', r: 14, text: 'Manastıra ulaş.' }
  ], reward: { money: 150, rep: 6 } },
  { id: 'm32', act: 3, num: '3.2', title: 'Rüzgar ve Kanatlar', at: 'monastery', req: ['m31'], steps: [
    { t: 'func', fn: 'spawnFriend', arg: ['ayaz', 'monastery', -4] },
    { t: 'func', fn: 'spawnFriend', arg: ['filiz', 'monastery', 4] },
    { t: 'talk', d: 'd32_glide' },
    { t: 'unlock', ability: 'glide' },
    { t: 'tp', pos: null, near: 'monastery', up: 0, dx: 0, dz: 8 },
    { t: 'goto', at: [-300, -200], r: 14, text: 'Uçurumdan atla ve aşağıdaki işarete süzül!', glideHint: true }
  ], reward: { money: 150, rep: 6, bond: 3 } },
  { id: 'm33', act: 3, num: '3.3', title: 'Gökyüzünün Sesi', at: 'monastery', req: ['m32'], steps: [
    { t: 'focus', text: 'Odaklanma ritüeli: dairenin içinde kıpırdamadan dur.', at: 'monastery', time: 8 },
    { t: 'talk', d: 'd33_dragon' },
    { t: 'unlock', ability: 'dragon' },
    { t: 'fly', text: 'Metal Ejderhası ile gökyüzü halkalarından geç!', rings: [[-300, 60, -300], [-200, 80, -180], [-60, 90, -100], [60, 70, 0], [180, 90, -120], [260, 120, -260]] },
    { t: 'fight', text: 'Uçuş testi: dronları ejderhadan düşür!', waves: [{ type: 'drone', n: 5, at: [260, -200], y: 60 }] }
  ], outro: 'c_33_out', reward: { money: 200, rep: 8 } },
  { id: 'm34', act: 3, num: '3.4', title: 'Ada Çıkarması', at: 'bridgeEast', req: ['m33'], night: true, steps: [
    { t: 'func', fn: 'allyJoin' },
    { t: 'fight', text: 'Ada kapısındaki muhafızları geç.', waves: [{ type: 'guard', n: 4, at: 'islandGate' }] },
    { t: 'goto', at: 'prison', r: 12, text: 'Hapishane bloğuna ulaş.' },
    { t: 'fight', text: 'Hücre muhafızlarını temizle.', waves: [{ type: 'guard', n: 4, at: 'prison' }, { type: 'elite', n: 2, at: 'prison' }] },
    { t: 'talk', d: 'd34_rescue' },
    { t: 'escort', text: 'Hikmet Usta\'yı köprüden geçirip kıyıya götür.', npc: 'hikmet', to: [392, 240], r: 10 }
  ], reward: { money: 300, rep: 8, bond: 4 } },
  { id: 'm35', act: 3, num: '3.5', title: 'Büyük İhanet', at: 'teahouse', req: ['m34'], intro: 'c_35_in', steps: [
    { t: 'talk', d: 'd35_betray' },
    { t: 'fight', text: 'Üs baskını! Muhafızlara karşı dayan.', waves: [{ type: 'elite', n: 5, at: 'teahouse' }] },
    { t: 'boss', type: 'kor', at: 'teahouse', text: 'Hain Kor ile yüzleş!', escapeAt: 0.35 },
    { t: 'func', fn: 'captureAllies' }
  ], outro: 'c_35_out', reward: { money: 0, rep: 4 } },
  // ===== PERDE 4 — Yağmurlu Sıkıyönetim & Kırılma
  { id: 'm41', act: 4, num: '4.1', title: 'Sıkıyönetim Gecesi', at: 'bazaar', req: ['m35'], night: true, weather: 'rain', steps: [
    { t: 'talk', d: 'd41_curfew' },
    { t: 'func', fn: 'setCurfew', arg: true },
    { t: 'stealth', text: 'Yeraltı bağlantısı 1: projektörlere görünmeden ulaş.', at: [-200, 60], goal: [-200, 60], cams: [[-240, 40, 90], [-220, 90, 200]], alarm: [{ type: 'elite', n: 2 }] },
    { t: 'stealth', text: 'Yeraltı bağlantısı 2: Neon Bulvar arka sokağı.', at: [-40, 160], goal: [-40, 160], cams: [[-70, 150, 0], [-10, 170, 180]], alarm: [{ type: 'elite', n: 2 }] },
    { t: 'stealth', text: 'Yeraltı bağlantısı 3: Dojo çatı geçidi.', at: [120, -60], goal: [120, -60], cams: [[100, -40, 300], [140, -80, 120]], alarm: [{ type: 'elite', n: 3 }] },
    { t: 'func', fn: 'setCurfew', arg: false }
  ], reward: { money: 150, rep: 6 } },
  { id: 'm42', act: 4, num: '4.2', title: 'Karanlıkta Karar', at: 'warehouse', req: ['m41'], weather: 'rain', steps: [
    { t: 'func', fn: 'allyJoin' },
    { t: 'func', fn: 'spawnFriend', arg: ['taskin', 'warehouse', 5] },
    { t: 'choice', d: 'd42_choice' },
    { t: 'branch', flag: 'vengeful',
      yes: [{ t: 'fight', text: 'Depoyu kuşat — muhafızları yok et!', waves: [{ type: 'elite', n: 4, at: 'warehouse' }, { type: 'gangGun', n: 3, at: 'warehouse' }] }, { t: 'func', fn: 'explode', arg: 'warehouse' }],
      no: [{ t: 'collect', text: 'Zorla çalıştırılan işçileri çıkar (yanlarına git).', items: [[-452, 436], [-436, 450], [-458, 447]], label: 'İşçi', guards: 'elite' }, { t: 'fight', text: 'Kapsülleri etkisiz bırakırken muhafızları durdur!', waves: [{ type: 'elite', n: 4, at: 'warehouse' }] }] }
  ], reward: { money: 200, rep: 6 } },
  { id: 'm43', act: 4, num: '4.3', title: 'Gölge Hatları', at: 'garage', req: ['m42'], night: true, steps: [
    { t: 'func', fn: 'spawnVehicle', arg: { type: 'sport', at: 'garage', dx: 8 } },
    { t: 'drive', text: 'Modifiye araçla birinci esir konvoyuna yetiş.', to: [-80, -80], r: 14, needVehicle: true, time: 80 },
    { t: 'fight', text: 'Konvoy muhafızlarını dağıt, Ray\'i kurtar.', waves: [{ type: 'elite', n: 4, at: [-80, -80] }] },
    { t: 'drive', text: 'İkinci baskın: Teknoloji bölgesi depo hattı.', to: [200, -120], r: 14, needVehicle: true, time: 90 },
    { t: 'fight', text: 'Derya\'yı tutan muhafızları yen.', waves: [{ type: 'elite', n: 4, at: [200, -120] }, { type: 'drone', n: 3, at: [200, -120] }] },
    { t: 'talk', d: 'd43_found' },
    { t: 'func', fn: 'freeAllies', arg: ['ray', 'derya'] }
  ], reward: { money: 300, rep: 8 } },
  { id: 'm44', act: 4, num: '4.4', title: 'Son Hazırlık', at: 'eastSafe', req: ['m43'], steps: [
    { t: 'func', fn: 'unlockSafehouse', arg: 'eastSafe' },
    { t: 'func', fn: 'setWeather', arg: 'clear' },
    { t: 'func', fn: 'allyJoin' },
    { t: 'choice', d: 'd44_plan' },
    { t: 'func', fn: 'finalPathInfo' }
  ], reward: { money: 100, rep: 4 } },
  // ===== PERDE 5 — Kule Zirvesi Finali
  { id: 'm51', act: 5, num: '5.1', title: 'Kuleye Hücum', at: 'techTower', req: ['m44'], night: true, weather: 'storm', steps: [
    { t: 'func', fn: 'allyJoin' },
    { t: 'func', fn: 'spawnFriend', arg: ['ray', [262, -236]] },
    { t: 'func', fn: 'spawnFriend', arg: ['derya', [298, -236]] },
    { t: 'fight', text: 'Kule meydanındaki savunmayı kır!', waves: [{ type: 'elite', n: 5, at: [280, -232] }, { type: 'drone', n: 4, at: [280, -232] }] },
    { t: 'tp', pos: [280, 90.2, -248] },
    { t: 'fight', text: 'Gökyüzü terası 90. kat — ilerle!', waves: [{ type: 'elite', n: 5, at: [280, -244], y: 90 }] }
  ], reward: { money: 200, rep: 8 } },
  { id: 'm52', act: 5, num: '5.2', title: 'Çekirdek Muhafızları', at: 'techTower', req: ['m51'], night: true, weather: 'storm', steps: [
    { t: 'tp', pos: [280, 140.2, -248] },
    { t: 'func', fn: 'allyJoin' },
    { t: 'branch', flag: 'protective',
      yes: [{ t: 'talk', d: 'd52_kor_good' }, { t: 'func', fn: 'korRedeemed' }, { t: 'fight', text: 'Kor ile birlikte muhafızları yen!', waves: [{ type: 'elite', n: 6, at: [280, -244], y: 140 }] }],
      no: [{ t: 'talk', d: 'd52_kor_dark' }, { t: 'boss', type: 'kor', at: [280, -244], y: 140, text: 'Kor\'u durdur!' }] },
    { t: 'skill', ability: 'any', count: 3, text: 'Tüm güçleri birleştir: çekirdek kilitlerine Şok/Kasırga ile vur (3 kilit).', dummies: 3, y: 140, at: [280, -248], dummyName: 'Çekirdek Kilidi' }
  ], reward: { money: 200, rep: 8 } },
  { id: 'm53', act: 5, num: '5.3', title: 'Son Çekirdek', at: 'techTower', req: ['m52'], night: true, weather: 'storm', intro: 'c_53_in', steps: [
    { t: 'tp', pos: [280, 172.2, -270] },
    { t: 'func', fn: 'allyJoin' },
    { t: 'talk', d: 'd53_boss' },
    { t: 'boss', type: 'mimar', at: [280, -284], y: 172, text: 'MİMAR ile son hesaplaşma!' },
    { t: 'talk', d: 'd53_final' },
    { t: 'ending' }
  ], reward: { money: 1000, rep: 30 } }
];

// ------------------------------------------------------------------ Yan görevler (7)
const SIDES = [
  { id: 's_fake1', kind: 'side', title: 'Sahte Kahramanlık 1', at: 'dojo', req: ['m16'], giver: 'NPC_DojoGuy', steps: [
    { t: 'talk', d: 's_tarik1' },
    { t: 'func', fn: 'spawnFriend', arg: ['tarik', 'dojo', 3] },
    { t: 'skill', ability: 'any', count: 3, text: '"Sahne" kuklalarını Tarık için devir (3).', dummies: 3, at: [120, -4], dummyName: 'Öğrenci Kuklası' },
    { t: 'fight', text: 'Gerçek kartelciler geldi! Tarık saklanırken sen savaş.', waves: [{ type: 'gang', n: 4, at: [120, 0] }] },
    { t: 'talk', d: 's_tarik1_end' }
  ], reward: { money: 200, rep: 2 } },
  { id: 's_fake2', kind: 'side', title: 'Sahte Kahramanlık 2', at: 'dojo', req: ['s_fake1', 'm22'], giver: 'NPC_DojoGuy', steps: [
    { t: 'talk', d: 's_tarik2' },
    { t: 'goto', at: [200, 120], r: 12, text: 'Kemeri çalan çeteyi bul (Polis merkezi arkası).' },
    { t: 'fight', text: 'Kemer hırsızlarını yen.', waves: [{ type: 'gang', n: 3, at: [200, 120] }, { type: 'gangGun', n: 2, at: [200, 120] }] },
    { t: 'collect', text: 'Şampiyonluk kemerini al.', items: [[204, 124]], label: 'Kemer' },
    { t: 'goto', at: 'dojo', r: 8, text: 'Kemeri Tarık\'a götür.' },
    { t: 'talk', d: 's_tarik2_end' }
  ], reward: { money: 260, rep: 3 } },
  { id: 's_noodle1', kind: 'side', title: 'Sıcak Erişte Teslimatı', at: 'noodle', req: ['m13'], giver: 'NPC_NoodleChef', steps: [
    { t: 'talk', d: 's_noodle1' },
    { t: 'func', fn: 'spawnVehicle', arg: { type: 'motor', at: 'noodle', dx: 6, temp: true } },
    { t: 'drive', text: 'Teslimat 1: Polis merkezi.', to: 'policeHQ', r: 10, needVehicle: true, time: 50 },
    { t: 'drive', text: 'Teslimat 2: Spor salonu.', to: 'gym', r: 10, needVehicle: true, time: 45 },
    { t: 'drive', text: 'Teslimat 3: Restoran mutfağı.', to: 'restaurant', r: 10, needVehicle: true, time: 40 }
  ], reward: { money: 180, rep: 2 } },
  { id: 's_noodle2', kind: 'side', title: 'Gece Vardiyası Siparişi', at: 'noodle', req: ['s_noodle1'], night: true, giver: 'NPC_NoodleChef', steps: [
    { t: 'talk', d: 's_noodle2' },
    { t: 'func', fn: 'spawnVehicle', arg: { type: 'motor', at: 'noodle', dx: 6, temp: true } },
    { t: 'drive', text: 'Siparişi rıhtıma yetiştir!', to: 'docks', r: 12, needVehicle: true, time: 90 },
    { t: 'fight', text: 'Pusu! Sahte müşterileri temizle.', waves: [{ type: 'gang', n: 4, at: 'docks' }, { type: 'gangGun', n: 2, at: 'docks' }] }
  ], reward: { money: 260, rep: 3 } },
  { id: 's_racebet', kind: 'side', title: 'Gece Yarışı Bahsi', at: [0, 80], req: ['m21'], night: true, cost: 100, steps: [
    { t: 'talk', d: 's_racebet' },
    { t: 'func', fn: 'spawnVehicle', arg: { type: 'sport', at: [0, 80], dx: 6, temp: true } },
    { t: 'race', text: 'Bahis yarışı! Birinci bitir.', vehicle: true, rivals: 3, cps: [[0, 160], [80, 240], [160, 160], [160, -80], [80, -160], [0, -80], [0, 80]], time: 120 }
  ], reward: { money: 300, rep: 2 } },
  { id: 's_parts', kind: 'side', title: 'Kayıp Parça Avı', at: 'garage', req: ['m13'], steps: [
    { t: 'talk', d: 's_parts' },
    { t: 'collect', text: 'Şehre saçılmış 6 motor parçasını bul.', items: [[-280, 200], [-120, 480], [40, 420], [220, -40], [320, 160], [-40, -400]], label: 'Motor Parçası' },
    { t: 'goto', at: 'garage', r: 10, text: 'Parçaları garaja götür.' },
    { t: 'func', fn: 'modFree', arg: 'speed' }
  ], reward: { money: 150, rep: 2 } },
  { id: 's_patrol', kind: 'side', title: 'Kartel Devriye Avı', at: 'policeHQ', req: ['m16'], repeat: true, steps: [
    { t: 'talk', d: 's_patrol' },
    { t: 'fight', text: 'Devriye 1 (Eski Çarşı).', waves: [{ type: 'gang', n: 3, at: [-240, -80] }] },
    { t: 'fight', text: 'Devriye 2 (Neon Bulvar).', waves: [{ type: 'gang', n: 3, at: [80, 160] }, { type: 'gangGun', n: 1, at: [80, 160] }] },
    { t: 'fight', text: 'Devriye 3 (Doğu Konutları).', waves: [{ type: 'gang', n: 3, at: [240, 240] }, { type: 'gangGun', n: 2, at: [240, 240] }] }
  ], reward: { money: 220, rep: 4 } }
];

// ------------------------------------------------------------------ Aktiviteler (5)
const ACTIVITIES = [
  { id: 'a_dinner', kind: 'activity', title: 'Akşam Yemeği Buluşması', at: 'restaurant', req: ['m22'], needAlly: true, hours: [18, 23.9], cost: 60, steps: [
    { t: 'func', fn: 'fadeSit', arg: 'restaurant' }, { t: 'choice', d: 'a_dinner' }, { t: 'func', fn: 'heal' }
  ], reward: { bond: 4 } },
  { id: 'a_gym', kind: 'activity', title: 'Spor Salonu Antrenmanı', at: 'gym', req: ['m11'], cost: 20, steps: [
    { t: 'talk', d: 'a_gym' }, { t: 'skill', ability: 'punch', count: 25, text: 'Torbaya 25 darbe! (20 sn)', dummies: 1, time: 20, at: [40, 296], dummyName: 'Kum Torbası', static: true }, { t: 'func', fn: 'gymBonus' }
  ], reward: { money: 0 } },
  { id: 'a_view', kind: 'activity', title: 'Çatı/Sahil Manzara Anı', at: 'beach', req: ['m22'], needAlly: true, hours: [17, 23.9], steps: [
    { t: 'func', fn: 'fadeSit', arg: 'beach' }, { t: 'choice', d: 'a_view' }
  ], reward: { bond: 4 } },
  { id: 'a_garage', kind: 'activity', title: 'Garaj & Sürüş Turu', at: 'garage', req: ['m22', 'm13'], needAlly: true, steps: [
    { t: 'talk', d: 'a_garage' }, { t: 'func', fn: 'spawnVehicle', arg: { type: 'sport', at: 'garage', dx: 8, temp: true } },
    { t: 'race', text: 'Ela ile manzaralı tur: işaretlerden geç.', vehicle: true, rivals: 0, cps: [[-160, 160], [0, 160], [160, 320], [320, 480], [400, 400], [240, 160], [0, 240], [-160, 300]], time: 200 }
  ], reward: { bond: 5, money: 0 } },
  { id: 'a_smoothie', kind: 'activity', title: 'Neon Smoothie Molası', at: 'smoothie', req: ['m23'], needAlly: true, cost: 15, steps: [
    { t: 'func', fn: 'fadeSit', arg: 'smoothie' }, { t: 'choice', d: 'a_smoothie' }, { t: 'func', fn: 'energyBoost' }
  ], reward: { bond: 3 } }
];

// ------------------------------------------------------------------ Easter Egg'ler (6)
const EGGS = [
  { id: 'e_chicken', title: 'Kaçak Beyaz Tavuk', hint: 'Eski Çarşı\'da bir tavuk sesi…', at: 'bazaar' },
  { id: 'e_tape', title: 'Çatıdaki Gizli Kaset & Semboller', hint: 'Neon Bulvar çatılarında 3 parlayan sembol.', symbols: [[-40, -200], [40, -120], [120, -200]] },
  { id: 'e_backroom', title: 'Gizli Neon Arka Oda', hint: 'Erişte dükkânının arka kapısı gece açılır.', at: 'backroom' },
  { id: 'e_teacup', title: 'Antika Çay Fincanı', hint: 'Dağ patikasında unutulmuş bir fincan.', at: [-410, -300] },
  { id: 'e_radio', title: 'Gece Radyo Özel Yayını', hint: 'Saat 03:00–04:00 arası araç radyosu.' },
  { id: 'e_peak', title: 'Zirve Gizli Bakış Noktası', hint: 'Manastırın ardındaki çıkıntı.', at: 'peakSecret' }
];

// ------------------------------------------------------------------ Radyo
const RADIO = {
  stations: [
    { id: 'neon', name: 'Neon FM 99.9', kind: 'music' },
    { id: 'news', name: 'Haber 24 — Selin Sinyal', kind: 'news' },
    { id: 'tape', name: 'Kaset FM ∞', kind: 'tape', locked: 'e_tape' }
  ],
  music: ['♪ Synthwave: "Islak Asfalt"', '♪ Retrowave: "Pembe Ufuk"', '♪ City Pop: "Gece Otobüsü"', '♪ Darksynth: "Kule 170"', '♪ Chillwave: "Ananas Işığı"'],
  tape: ['📼 Hışırtı… "çatılarda üç sembol, bir frekans…"', '📼 Lo-fi ritim, uzak bir martı sesi.', '📼 "Kim dinliyorsa: şehir seni izliyor."'],
  news: {
    start: 'Neon Şehir\'de yağmurlu bir gece daha. Limanda kartel hareketliliği bildiriliyor.',
    m11: 'Rıhtımda kartel baskını püskürtüldü! Tanıklar maskeli bir tamirciden bahsediyor.',
    m12: 'Eski Çarşı\'daki çay evine saldırı: Hikmet Usta yaralı ama iyi.',
    m14: 'Polis rıhtım deposunda element kapsülü buldu. Şüpheliler kaçtı.',
    m16: 'Liman Reisi Kanca etkisiz! Liman esnafı kutluyor.',
    m21: 'Neon Bulvar\'da yasadışı gece yarışı: ateş saçan bir motorcu görüldü.',
    m22: 'Teknoloji Kulesi çatısında patlama sesleri. Yetkililer açıklama yapmadı.',
    m24: 'Şehrin iki enerji aktarıcısı devre dışı. Elektrik kesintisi bekleniyor.',
    m26: 'Emniyet açıkladı: maskeli ikili artık resmi olarak "şehrin ninjaları"!',
    m33: 'Dağ üzerinde metal bir ejderha görüldüğü iddia ediliyor. Uzmanlar şaşkın.',
    m34: 'Güvenlikli Ada\'da kaçış! Hikmet Usta serbest.',
    m35: 'Eski Çarşı\'da yangın. Element ustalarından haber alınamıyor.',
    m41: 'SIKIYÖNETİM sürüyor. Sokağa çıkma yasağına uyun.',
    m42v: 'Rıhtım deposu havaya uçtu! Mimar\'ın kapsül stoğu yok edildi.',
    m42p: 'Rıhtım deposundan onlarca işçi kurtarıldı. Kapsüller güvende.',
    m43: 'Gece baskınları: esir element ustaları kurtarılıyor.',
    m53: 'Kule zirvesinde dev bir ışık. Şehir nefesini tuttu.',
    wanted: 'Polis maskeli bir şüpheliyi arıyor. Vatandaşlar dikkatli olsun.',
    rain: 'Meteoroloji uyarıyor: yağmur gece boyunca sürecek, yollar kaygan.',
    clear: 'Açık ve neon bir gece. Sürüş için harika hava.',
    special: '🌙 ÖZEL YAYIN — Saat 3\'te, şehrin uyumayanlarına: "Gölgeler hep ışığın yanında durur." (Gece Radyo Easter Egg\'i bulundu!)'
  }
};

// Admin JSON geçersiz kılma (override) — Admin paneli tarafından yazılır
(function applyDataOverride() {
  try {
    const o = JSON.parse(localStorage.getItem(DATA_OVERRIDE_KEY) || 'null');
    if (!o) return;
    if (o.CAST) for (const k in o.CAST) CAST[k] = Object.assign(CAST[k] || {}, o.CAST[k]);
    if (o.DIALOGUES) Object.assign(DIALOGUES, o.DIALOGUES);
    if (o.CUTSCENES) Object.assign(CUTSCENES, o.CUTSCENES);
    if (o.MISSIONS) for (const m of o.MISSIONS) { const i = MISSIONS.findIndex(x => x.id === m.id); if (i >= 0) MISSIONS[i] = m; else MISSIONS.push(m); }
    if (o.SIDES) for (const m of o.SIDES) { const i = SIDES.findIndex(x => x.id === m.id); if (i >= 0) SIDES[i] = m; else SIDES.push(m); }
    if (o.ACTIVITIES) for (const m of o.ACTIVITIES) { const i = ACTIVITIES.findIndex(x => x.id === m.id); if (i >= 0) ACTIVITIES[i] = m; else ACTIVITIES.push(m); }
    if (o.WEAPONS) Object.assign(WEAPONS, o.WEAPONS);
    if (o.VEHICLES) Object.assign(VEHICLES, o.VEHICLES);
  } catch (e) { console.warn('Veri override okunamadı', e); }
})();
const locXZ = (l) => Array.isArray(l) ? l : (LOC[l] || [0, 0]);
