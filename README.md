# NEON GÖLGELER — 3D Açık Dünya Hikayeli Aksiyon-Macera

Three.js (r160) ile yazılmış, blok oyuncak estetiğinde bir açık dünya oyunu. Oyun **tek bir dosyada** çalışır: `game/index.html`.
Bu proje eski arena projesinden bağımsızdır, o projeye dokunmaz.

```
neon-golgeler/
├─ game/index.html            ← OYUNUN KENDİSİ (tüm kod tek dosyada)
├─ game/vendor/               ← çevrimdışı Three.js (npm run vendor ile dolar)
├─ src/                       ← index.html'in modüler kaynak parçaları (tools/build.sh birleştirir)
├─ data/neon-golgeler-data.json  ← tüm görev/diyalog/sinematik/karakter verisi (Admin'den içe aktarılabilir)
├─ electron/main.js           ← Windows .exe kabuğu
├─ android/MainActivity.kt    ← Android GeckoView kabuğu + yerel sunucu (şablon)
├─ android/build.gradle.snippet
├─ tools/build.sh · tools/fetch-vendor.mjs · tools/serve.mjs
└─ package.json
```

---

## 1. Hemen oynamak (en kolay yol)

1. Bilgisayarına [Node.js](https://nodejs.org) kur (LTS sürümü).
2. Klasörde bir terminal aç ve şunu yaz: `node tools/serve.mjs`
3. Tarayıcıda **http://localhost:8080** adresini aç → **Yeni Oyun**.

> `index.html` dosyasına çift tıklamak da çoğu zaman çalışır ama bazı tarayıcılar `file://` adreslerini kısıtlar. Yerel sunucu her zaman güvenlidir.
> İnternet yoksa önce bir kez `npm run vendor` çalıştır; Three.js `game/vendor/` içine iner ve oyun tamamen çevrimdışı açılır.

**Telefonda test:** `node tools/serve.mjs` komutu, aynı Wi-Fi ağındaki telefondan açabileceğin adresi de yazar (ör. `http://192.168.1.5:8080`).

---

## 2. Windows .exe (Electron)

```bash
npm install          # electron + electron-builder
npm run vendor       # Three.js'i çevrimdışı paketle
npm start            # test penceresi
npm run dist:win     # dist/ klasörüne taşınabilir .exe + kurulum dosyası
```
- Electron, oyunu `127.0.0.1:48219` adresindeki dahili sunucudan açar. Port sabit tutulduğu için IndexedDB önbelleği ve kayıtlar açılışlar arasında korunur.
- **F11** tam ekran, **F12** geliştirici konsolu.

## 3. Android .apk (GeckoView + yerel sunucu)

1. Android Studio → *Empty Views Activity* projesi oluştur (paket adı: `com.neongolgeler.game`).
2. `android/build.gradle.snippet` içindeki Mozilla Maven deposunu, GeckoView bağımlılığını ve manifest izinlerini ekle.
3. `android/MainActivity.kt` dosyasını projedeki `MainActivity.kt` dosyasıyla değiştir.
4. `npm run vendor` çalıştır, sonra `game/` klasörünün **tüm içeriğini** `app/src/main/assets/game/` içine kopyala.
5. *Build → Build APK(s)*.

Uygulama, assets klasörünü `127.0.0.1:48219` üzerinden sunar. Bu sayede ES modülleri, IndexedDB ve Supabase istekleri sorunsuz çalışır. Mobilde kalite otomatik olarak **Düşük** seçilir; Ayarlar'dan değiştirebilirsin.

---

## 4. Kontroller (aktif cihaz otomatik algılanır, ipuçları değişir)

| Eylem | Klavye + Fare | Gamepad | Dokunmatik |
|---|---|---|---|
| Hareket / Kamera | WASD / Fare (tıkla = imleç kilidi) | Sol / Sağ çubuk | Sol joystick / sağ yarıyı sürükle |
| Koş | Shift | L3 | KOŞ (veya joystick sonuna kadar) |
| Atılma (dash) | C | Ⓑ (yakında etkileşim yoksa) | ATIL |
| Zıpla · Havada süzül (basılı) | Boşluk | Ⓐ | ZIPLA |
| Vuruş kombosu | Sol tık / J | Ⓧ / RT | VUR |
| Metal şok dalgası | Sağ tık / L | Ⓨ / LT | ŞOK |
| Metal sertleşmesi (aç/kapa) | R | RB | METAL |
| Kasırga Dönüşü | 1 | D-Yukarı | KASIRGA |
| Metal Ejderhası (çağır/in) | 2 | D-Aşağı | EJDER |
| Etkileşim / Konuş | E | Ⓑ | E |
| Araca bin / in | F | R3 (veya Ⓨ araç yanında) | ARAÇ |
| Silah tekerleği (basılı tut) · Silah değiştir | Q · Fare tekerleği | LB | 🗡 |
| Gardırop (Sivil ↔ Ninja) | O | D-Sağ | 👕 |
| Maske tak/çıkar | K | D-Sol | 😷 |
| Telefon | Tab / P | Back | 📱 |
| Ela'yı çağır | G | (telefon) | 📞 |
| Araçta: el freni · korna · radyo | Boşluk · H · N | Ⓐ · Ⓧ · — | — |
| Ejderhada: yüksel · alçal · ateş | Boşluk · Shift/C/Ctrl · Sol tık | Ⓐ · R3 · RT | — |
| Duraklat / Sinematiği atla | Esc | Start | ⏸ / "Atla" |
| Admin paneli | F10 (veya Ctrl+`) | — | Duraklat menüsü |

---

## 5. Oyun sistemleri — nerede ne var?

| Sistem | Kod modülü (`src/`) | Özet |
|---|---|---|
| Durum, kayıt, olay veriyolu | `01_core.js` | `S` = oyun durumu (`reputation`, `isRecognizedNinja`, `wanted`, `bondLevel`, `morality`…). localStorage'a otomatik kayıt (60 sn'de bir + görev sonu). |
| Veri | `02_data.js` | Karakterler, mekanlar, silahlar, araçlar, **24 ana görev**, **7 yan görev**, **5 aktivite**, **6 Easter Egg**, 45 diyalog, 13 sinematik, radyo. |
| Önbellek / Supabase / Rig | `03_cache.js` | IndexedDB sürüm+zaman damgası kontrolü; değişmeyen varlık indirilmeden anında yüklenir. Rig eklem noktaları da önbelleğe yazılır. |
| Render | `04_render.js` | ABS plastik materyaller, dünya-konumlu pencere shader'ı (gece yanan camlar), ıslak asfalt birikintileri, dalgalı su, gökyüzü (yıldızlar, 80ler neon gecesi mor-pembe ufuk), gün/gece, yağmur/fırtına/şimşek, efekt havuzu, neon ışık havuzu. |
| Dünya | `05_world.js` | ~1200×1200 m şehir: Liman, Eski Çarşı, Dağ Manastırı, Neon Bulvar, Teknoloji Merkezi (170 m kule + teraslar), Doğu Konutları, Güvenlikli Ada. Kanal köprüleri, ada köprüsü, iskeleler, ara sokaklar, dağ patikası. 160 m'lik parçalarda instancing + mesafe culling, çarpışma ızgarası. |
| Figür + iskelet | `06_figure.js` | `head/torso/arm_L/arm_R/leg_L/leg_R` pivotları, prosedürel poz animasyonu (yürü, koş, süzül, sür, otur, kasırga…), parçalar pivot başına tek geometriye birleştirilir (düşük çizim çağrısı). |
| Giriş | `07_input.js` | Tek `InputManager`: klavye/fare, gamepad, dokunmatik. |
| Aktörler | `08_actors.js` | Oyuncu güçleri, kamera, dövüş, mermiler, Ela AI, element ustaları, çete/polis AI, 3 patron, aranma sistemi, siviller (yağmurda şemsiye veya saçak altı, panik/kaçış/sinme), Metal Ejderhası. |
| Araçlar | `09_vehicles.js` | Motor, spor, sedan, kamyon, polis, van; drift ve ıslak zemin, hasar/patlama, trafik havuzu, polis takibi, yarış AI, modifiye, radyo + `Radio_NewsHost`. |
| Arayüz | `10_ui.js` | HUD, mini harita, seçimli diyalog, `CutscenePlayer`, `Phone_UI`, `Wardrobe_Menu`, silah tekerleği, dükkânlar, güvenli ev, Admin paneli. |
| Görevler | `11_missions.js` | Veri güdümlü adım motoru, başarısızlık/yeniden deneme, 3 final, Easter Egg mantığı. |

### Polis ve saygınlık kuralı
- `isRecognizedNinja = false` iken sivile veya polise saldırmak, silah kullanmak, araç gaspı ve **Güvenlikli Ada'ya izinsiz girmek** aranma seviyesini (★) artırır. Bu durumda polis seni hedef alır, ★2'den itibaren devriye araçları da kovalar.
- Maske + Ninja kostümü giyiliyken: tanık polis yoksa suç etkisi yarıya iner ve izini kaybettirmek daha hızlıdır.
- **2.6 "Gerçek Ninja"** görevinden sonra `isRecognizedNinja = true` olur. Aranma sıfırlanır, polis sana saldırmaz ve kartellerle/çetelerle savaşır. Sivile saldırmak yalnızca saygınlığı düşürür.

### Taşıma sınırı, gardırop, telefon
- Yumruğa ek olarak en fazla **3 silah** taşınır. Fazlası güvenli ev deposuna ya da silahçıdaki emanete gider.
- Gardırop her yerde açılır (çatışma sırasında açılmaz). Maske her iki kıyafette de ayrı bir tuşla takılıp çıkarılır.
- Telefon sekmeleri: Harita (dokunarak yol noktası koy), Görevler, Mesajlar, Ev/Araç (araç teslimi), **Ela** (ara, çağır, buluşma noktası ayarla), Ayarlar.

### Finaller (5.3)
| Final | Koşul |
|---|---|
| 🌅 Koruyucu | `morality ≥ 0` **ve** `bondLevel ≥ 50` |
| 👑 Suç Lordu | `morality ≤ 0` veya 4.2'de sert yol seçildiyse |
| 🕊 Fedakârlık | her zaman seçilebilir (tüm güçler sıfırlanır) |

Finalden sonra serbest dolaşım devam eder.

---

## 6. Görev listesi

**Perde 1 — Liman & Eski Çarşı:** 1.1 Gece Vardiyası · 1.2 Çay Evindeki Kıvılcım (Kasırga açılır) · 1.3 Hurda Motor & Sokak Yarışı (ilk araç + modifiye dükkânı) · 1.4 Rıhtım Depo Baskını (polis çatışması) · 1.5 İlk Güvenli Ev · 1.6 Limanın Nabzı (patron: Kanca)
**Perde 2 — Neon Bulvar & Teknoloji:** 2.1 Neon Geceleri (gece yarışı, Kor) · 2.2 Çatıdaki Ortak (Ela ile tanışma) · 2.3 Smoothie Molası & İstihbarat · 2.4 Yıldırım ve Dalga · 2.5 Kule Sızması (gizlilik) · 2.6 Gerçek Ninja (dönüm noktası)
**Perde 3 — Dağ, Gökyüzü & Ada:** 3.1 Zirveye Tırmanış · 3.2 Rüzgar ve Kanatlar (Süzülme) · 3.3 Gökyüzünün Sesi (Ejderha + halkalar) · 3.4 Ada Çıkarması · 3.5 Büyük İhanet
**Perde 4 — Yağmurlu Sıkıyönetim:** 4.1 Sıkıyönetim Gecesi · 4.2 Karanlıkta Karar (ahlak kırılması) · 4.3 Gölge Hatları · 4.4 Son Hazırlık
**Perde 5 — Kule Zirvesi:** 5.1 Kuleye Hücum · 5.2 Çekirdek Muhafızları (yola göre Kor ya kurtarılır ya da yenilir) · 5.3 Son Çekirdek (Mimar + 3 final)

**Yan görevler:** Sahte Kahramanlık 1 & 2 · Sıcak Erişte Teslimatı · Gece Vardiyası Siparişi · Gece Yarışı Bahsi · Kayıp Parça Avı · Kartel Devriye Avı (günde bir tekrarlanabilir)
**Aktiviteler (günde bir, bağ artırır):** Akşam Yemeği · Spor Salonu (kalıcı +10 can) · Manzara Anı · Garaj & Sürüş Turu · Neon Smoothie Molası (enerji + 2 dk hızlı yenilenme)
**Easter Egg'ler:** Kaçak Beyaz Tavuk · Çatı Sembolleri & Kaset (Kaset FM açılır) · Gizli Neon Arka Oda (gece) · Antika Çay Fincanı · Gece Radyo Özel Yayını (03:00–04:00, Haber 24) · Zirve Gizli Bakış Noktası

---

## 7. Admin paneli, özel modeller ve Supabase

**Açmak için:** Ana menü → Admin Paneli, oyun içinde **F10**, ya da Duraklat → Admin.

- **📂 Yükle:** Her karakter kod adına (`Hero_Main`, `Ally_Partner`, `Master_Fire`…) veya araca (`veh_motor`…) `.glb`/`.obj` model, ya da zemin/bina için doku atanır. Kostüm varyantı için `Hero_Main_ninja` / `Hero_Main_civil` gibi özel slot kullan.
- **Model kuralı:** Çok parçalı modelde node isimleri `head`, `torso`, `arm_L`, `arm_R`, `leg_L`, `leg_R` olmalı (`Arm.R`, `kol_l` gibi varyasyonlar da tanınır). Otomatik rig eklem noktalarını bulur, pivot kurar ve tüm animasyonları bağlar.
- **🔄 Tek Varlığı Yenile:** Yalnızca o varlığı kaynaktan zorla yeniden indirir.
- **♻ Önbelleği Temizle ve Yeniden Tara:** IndexedDB'yi boşaltır, Supabase'ten listeyi yeniden çeker ve her şeyi baştan yükler.
- **🏷 Görüntü isimleri:** Kod adı → ekranda görünen isim eşlemesi.
- **📦 Veri JSON:** Tüm görev/diyalog/sinematik verisini dışa aktar, düzenle, geri içe aktar.
- **🧪 Test:** Işınlanma, görev başlatma, önceki görevleri tamamlama, saat/hava, yetenek açma, `isRecognizedNinja` aç/kapa.

### Supabase kurulumu (isteğe bağlı)
Supabase SQL Editor'da çalıştır:

```sql
create table if not exists public.ng_assets (
  id text primary key,                 -- slot kimliği, ör. Hero_Main
  slot text not null,
  kind text not null default 'model',  -- model | texture
  fmt text not null default 'glb',     -- glb | obj | png | jpg | webp
  url text not null,
  version int not null default 1,      -- her yüklemede +1 (önbellek bunu karşılaştırır)
  updated_at timestamptz not null default now(),
  display_name text,
  meta jsonb default '{}'::jsonb
);
alter table public.ng_assets enable row level security;
create policy "ng_assets okuma" on public.ng_assets for select using (true);
create policy "ng_assets ekleme" on public.ng_assets for insert with check (true);
create policy "ng_assets güncelleme" on public.ng_assets for update using (true);

insert into storage.buckets (id, name, public) values ('ng-assets', 'ng-assets', true) on conflict do nothing;
create policy "ng depo okuma" on storage.objects for select using (bucket_id = 'ng-assets');
create policy "ng depo yükleme" on storage.objects for insert with check (bucket_id = 'ng-assets');
create policy "ng depo güncelleme" on storage.objects for update using (bucket_id = 'ng-assets');
```
Sonra Admin → Supabase alanına **Project URL** ve **anon key** gir → Kaydet → *Bağlantıyı test et*.

> ⚠ Yukarıdaki yazma izinleri geliştirme içindir: anon anahtarı bilen herkes yükleme yapabilir. Oyunu dağıtmadan önce ekleme ve güncelleme politikalarını yalnızca giriş yapmış admin kullanıcıya sınırla.

**Önbellek akışı:** Açılışta Supabase satırları okunur. Her varlığın `version` ve `updated_at` değeri IndexedDB kaydıyla karşılaştırılır. İkisi de aynıysa varlık **indirilmeden** IndexedDB'den gelir ve rig eklemleri de önbellekten okunur. Farklıysa yalnızca o varlık indirilir.

---

## 8. Veri şeması (data/neon-golgeler-data.json)

```jsonc
{
  "CAST": { "Hero_Main": { "name": "Kaan Demir", "element": "Metal", "looks": { "civil": {…}, "ninja": {…} }, "mask": "#8d97a3" } },
  "LOC": { "teahouse": [-360, -26] },                      // [x, z] metre
  "MISSIONS": [{
    "id": "m12", "act": 1, "num": "1.2", "title": "…", "at": "teahouse", "req": ["m11"],
    "night": false, "weather": "rain", "intro": "c_12_in", "outro": null,
    "steps": [ { "t": "fight", "text": "…", "waves": [{ "type": "gang", "n": 5, "at": "teahouse" }] },
               { "t": "talk", "d": "d12_mentor" }, { "t": "unlock", "ability": "tornado" } ],
    "reward": { "money": 80, "rep": 5, "bond": 0 }
  }],
  "SIDES": [ /* aynı yapı + kind:"side", repeat */ ],
  "ACTIVITIES": [ /* kind:"activity", needAlly, hours:[18,23.9], cost */ ],
  "DIALOGUES": { "d22_meet": [ { "who": "Kaan", "text": "…" },
                               { "choice": [ { "text": "…", "bond": 6, "moral": 1, "flag": "x", "reply": { "who": "Ela", "text": "…" } } ] } ] },
  "CUTSCENES": { "c_intro": { "at": "harborGate", "time": 21.5, "weather": "storm", "title": "…",
                 "cast": { "kaan": [dx, dz, yönDerece, "anim"] },
                 "steps": [ { "shot": "sky|wide|close|over|low|top|orbit", "on": "kaan", "dur": 4, "sub": { "who": "", "text": "…" } } ] } }
}
```
**Adım tipleri (`t`):** `cut, talk, choice, goto, drive, fight, boss, race, chase, collect, skill, stealth, hold, endure, focus, fly, escort, tp, unlock, set, func, branch, wardrobe, storage, ending`.
**Animasyonlar:** `idle, walk, run, jump, glide, spin, drive, ride, sit, cheer, kneel, hurt, cower, swim, ko, umbrella, focus`.

---

## 8.5 Sürüm 1.1 yenilikleri

**Hazır 3D modeller:** İlk açılışta açık kaynak GLB modeller indirilir (three.js örnek modelleri, raw.githubusercontent / jsDelivr / threejs.org aynalarından sırayla denenir) ve IndexedDB'ye kaydedilir. Sonraki açılışlarda yeniden indirilmez. İnsan karakterleri `Xbot` (Idle/Walk/Run klipleri), muhafız ve polisler `Soldier`, Çekirdek Muhafızları ve Mimar `RobotExpressive` (Jump/Punch/Death dahil), spor araba `ferrari.glb` (DRACO) ile gelir. Karakterler kostüm renklerine boyanır; Kaan ve Ela'nın saç ve maskesi kafa kemiğine takılır. İnternet yoksa çok parçalı, yuvarlatılmış blok figürler kullanılır. Ayarlar'da "Blok figürler" seçilerek tamamen çevrimdışı mod açılabilir.
Ağaç, sokak lambası ve bank için Admin → "Bu slota yükle / URL ata" ile `lib_tree`, `lib_lamp` ve `lib_bench` slotlarına kendi .glb modellerini (ör. Kenney/Quaternius) verebilirsin. Şehir bu modelleri instanced olarak dizer.

**Animasyon:** GLB'deki klipler `AnimationMixer` ile `crossFadeTo` geçişli oynatılır. Kombo yumruk/tekme, şok dalgası, süzülme ve kasırga pozları kemiklere katman olarak eklenir. Blok figürlerde nefes alma, koşarken öne eğilme ve kalça-omuz karşı salınımı var.

**Görsel:** Yumuşak gölgeler (PCFSoft, oyuncuyu izleyen texel hizalı geniş gölge kamerası), ACES ton eşleme, clearcoat'lu plastik, neon bloom (orta/yüksek kalite), FogExp2 derinlik sisi.

**Hareket:** Daha hızlı yürüme/koşma, anında dönüş, atılma (dash), yaylı (smooth damp) kamera, koşarken FOV açılması, darbede mikro sarsıntı.

**Aranma (WantedSystem):** Suçlar "ısı" üretir; yıldızlar 12/30/50/70/88 eşiklerinde artar. Isı yalnızca tanık varsa eklenir: polis görüş hattı varsa hemen, sivil ihbarında 3 sn sonra ve daha az. Hafif çarpmalar çok düşük ısı verir. Görüşten çıkınca ısı soğur; mini haritadaki arama çemberinin dışında daha hızlı soğur. Polis, gözden kaybettiğinde son görüldüğün yeri arar.

**NPC ve trafik:** Engelden kaçınma (önü tarayıp sağa-sola sapma), takılma kurtarma, kavşaklarda 8 sn'lik sırayla yanan ışıklarda duran trafik. Ela takılırsa ya da çok geride kalırsa yanına yetişir.

**Otomatik güncelleme (AutoUpdater):** Oyun açılışta ve menüden `game/version.json` dosyasını kontrol eder (GitHub → jsDelivr → isteğe bağlı Supabase `ng-assets/version.json` → Ayarlar'daki özel adres). Yeni sürüm varsa notlar ve ilerleme çubuğuyla dosyaları indirir, SHA-256 ile doğrular, servis çalışanı önbelleğine (`sw.js`) uygular ve oyunu yeniden başlatır (Electron: `app.relaunch()`). Yeni .exe/.apk kurulursa eski paket önbelleği kendiliğinden temizlenir. Ayarlar → "Yerleşik sürüme dön" ile geri alınabilir. Kabuk güncellemeleri: kurulumlu Windows sürümünde `electron-updater` (GitHub Releases); APK'da `minShell` yeni APK gerektirirse indirme bağlantısı açılır.
Yeni bir içerik güncellemesi yayınlamak için: `VERSION` dosyasını artır → `sh tools/build.sh` → `node tools/make-version.mjs "notlar"` → GitHub'a gönder.

## 9. Test adımları (kontrol listesi)

1. **Açılış:** Yükleme çubuğu dolar → ana menü. Yeni Oyun → giriş sinematiği ("Atla" çalışır) → 1.1 diyaloğu.
2. **Hareket ve kamera:** WASD + fare, Shift ile koşu, binalara çarpınca kayma, çatıya zıplama, kanala düşünce yüzme.
3. **1.1:** O ile Ninja kostümü, K ile maske → rıhtımda dövüş → görev tamamlandı bildirimi.
4. **Aranma:** Bir sivile vur → ★ → polis gelir. Maske takıp uzaklaş → iz kaybolur.
5. **Araç:** F ile bin, sür, Boşluk ile drift, N ile radyo istasyonu, F ile in.
6. **Hava:** Admin → Hava: rain. Siviller şemsiye açar veya saçak altına koşar, zemin parlar, neon yansımaları belirir.
7. **Gece:** Admin → Saat 22. Pencereler yanar, neon halelerle sokak ışıkları ve ışık havuzu devreye girer.
8. **Yetenekler:** Admin → Tüm yetenekler. 1 (kasırga), çatıdan atlayıp Boşluk basılı (süzülme), 2 (ejderha, uç, ateş et, in).
9. **Telefon:** Tab → sekmeler, haritaya dokunarak yol noktası, Ela'yı arama.
10. **Kayıt:** Duraklat → Kaydet → sayfayı yenile → Devam Et (konum, kıyafet, silahlar ve ilerleme korunur).
11. **Özel model:** Admin → Hero_Main → .glb yükle → karakter anında değişir. Sayfayı yenile: model yeniden indirilmez, durum "IndexedDB ✓" görünür.
12. **Görev atlama:** Admin → görev seç → *Önceki görevleri tamamla* → *Görevi başlat* (ör. 5.3 final testi).
13. **Mobil:** Telefondan aç → dokunmatik joystick ve butonlar otomatik görünür.
14. **Performans:** Sağ alttaki FPS ve çizim çağrısı sayacı. Düşükse Ayarlar → Kalite: Düşük, görüş mesafesini azalt, gölgeleri kapat.

**Konsoldan hata ayıklama:** `__NG.S` (durum), `__NG.Missions.active`, `__NG.Game.player.pos`, `__NG.Sky.setWeather('storm', true)`.

## 10. Kaynaktan yeniden derleme
`src/` altındaki dosyaları düzenledikten sonra `sh tools/build.sh` çalıştır; çıktı `game/index.html` dosyasına yazılır.
