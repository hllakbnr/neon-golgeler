#!/usr/bin/env python3
"""CI: parçalı güncelleme paketi hazırlar.
Önceki taban (base.json: taban sürüm + dosya parmak izleri) indirilir; şimdiki tam paketle karşılaştırılır.
Değişen dosyalar yama.pck'ye konur. Başlangıçta yüklenen kritik dosyalar (proje ayarları, sınıf
listesi, kimlik önbelleği, yükleyici betiği) değiştiyse ya da yama çok büyüdüyse yeni taban seçilir
(oyuncu tam exe indirir).  Kullanım: patch_build.py <full.pck> <sürüm> <çıktı klasörü> <exe adı>
"""
import json, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pck

full, ver, out, exe = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
URL = 'https://github.com/hllakbnr/neon-golgeler/releases/download/godot-guncel/base.json'
# uid_cache.bin kritik değil: yeni varlıklar yola göre de yüklenir (Godot uid bulamazsa yola düşer)
CRIT = ('res://project.binary', 'res://.godot/global_script_class_cache.cfg',
        'res://scripts/patcher.gd', 'res://scripts/patcher.gdc', 'res://scripts/patcher.gd.remap')


def fp(e):
    # Godot 4.3 .gdc (ikili betik) her dışa aktarmada farklı bayt üretir → kaynağın parmak izi kullanılır
    path = e['path']
    if path.endswith('.gdc'):
        src = path[len('res://'):-1]
        if os.path.exists(src):
            return 'src:' + pck.hashlib.md5(open(src, 'rb').read()).hexdigest()
    return pck.hashlib.md5(e['data']).hexdigest()


p = pck.read(full)
cur = {e['path']: fp(e) for e in p['entries']}
total = sum(len(e['data']) for e in p['entries'])
base = None
try:
    if os.environ.get('NG_BASE_FILE'):
        base = json.load(open(os.environ['NG_BASE_FILE']))
    else:
        base = json.loads(urllib.request.urlopen(URL, timeout=20).read().decode())
except Exception as ex:
    print('taban yok:', ex)

new_base = True
changed = []
if base and base.get('engine') == list(p['ver']) and base.get('fmt') == 2:
    old = base.get('files', {})
    crit = [k for k in CRIT if old.get(k) != cur.get(k)]
    changed = [k for k, v in cur.items() if old.get(k) != v]
    size = sum(len(e['data']) for e in p['entries'] if e['path'] in changed)
    print('değişen dosya:', len(changed), 'boyut MB %.2f' % (size / 1e6), 'kritik:', crit)
    for k in changed[:80]:
        print('  ~', k)
    if not crit and size < total * 0.6 and ver - int(base['base']) < 60:
        new_base = False

info = {'version': ver, 'file': exe, 'notes': 'Neon Gölgeler sürüm %d' % ver}
if new_base:
    base = {'base': ver, 'engine': list(p['ver']), 'fmt': 2, 'files': cur}
    info['base'] = ver
    print('yeni taban:', ver)
else:
    want = set(changed) | {'res://version.txt'}
    pck.write(os.path.join(out, 'yama.pck'), p['ver'], [e for e in p['entries'] if e['path'] in want])
    info['base'] = int(base['base'])
    info['patch'] = 'yama.pck'
    info['patch_size'] = os.path.getsize(os.path.join(out, 'yama.pck'))
    print('yama:', info['patch_size'], 'bayt, taban', info['base'])
json.dump(base, open(os.path.join(out, 'base.json'), 'w'))
json.dump(info, open(os.path.join(out, 'version.json'), 'w'), ensure_ascii=False)
print(json.dumps(info, ensure_ascii=False))
