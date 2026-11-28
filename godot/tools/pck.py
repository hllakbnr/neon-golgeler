#!/usr/bin/env python3
"""Godot 4 .pck okuyucu / yazıcı (paket biçimi 2) — parçalı güncelleme için.
  python3 pck.py list <pck>                    → yol, boyut, md5
  python3 pck.py subset <pck> <çıktı> <liste>   → listedeki dosyalardan yeni pck
"""
import hashlib, json, struct, sys

MAGIC = 0x43504447
ALIGN = 32


def read(path):
    f = open(path, 'rb')
    data = f.read()
    off = 0
    # gömülü pck (exe sonu) desteği: sondan 'GDPC' + boyut
    if struct.unpack_from('<I', data, 0)[0] != MAGIC:
        assert struct.unpack_from('<I', data, len(data) - 4)[0] == MAGIC, 'pck bulunamadı'
        size = struct.unpack_from('<Q', data, len(data) - 12)[0]
        off = len(data) - 12 - size
    p = off
    magic, ver, vmaj, vmin, vpat, flags, file_base = struct.unpack_from('<IIIIIIQ', data, p)
    assert magic == MAGIC and ver == 2, (magic, ver)
    p += 4 * 6 + 8 + 16 * 4
    count = struct.unpack_from('<I', data, p)[0]
    p += 4
    rel = flags & 2
    entries = []
    for _ in range(count):
        ln = struct.unpack_from('<I', data, p)[0]
        p += 4
        name = data[p:p + ln].rstrip(b'\0').decode('utf-8')
        p += ln
        fo, sz = struct.unpack_from('<QQ', data, p)
        p += 16
        md5 = data[p:p + 16]
        p += 16
        fl = struct.unpack_from('<I', data, p)[0]
        p += 4
        start = (off + file_base + fo) if rel else (off + fo)
        entries.append({'path': name, 'size': sz, 'md5': md5.hex(), 'flags': fl, 'data': data[start:start + sz]})
    return {'ver': (vmaj, vmin, vpat), 'flags': flags, 'entries': entries}


def write(path, ver, entries):
    names = [e['path'].encode('utf-8') for e in entries]
    hdr = 4 * 6 + 8 + 16 * 4 + 4
    dirsize = 0
    for n in names:
        ln = len(n) + (4 - len(n) % 4) % 4
        dirsize += 4 + ln + 16 + 16 + 4
    base = hdr + dirsize
    base += (ALIGN - base % ALIGN) % ALIGN
    out = bytearray()
    out += struct.pack('<IIIIIIQ', MAGIC, 2, ver[0], ver[1], ver[2], 2, base)
    out += b'\0' * 64
    out += struct.pack('<I', len(entries))
    pos = 0
    offs = []
    for e in entries:
        offs.append(pos)
        pos += len(e['data'])
        pos += (ALIGN - pos % ALIGN) % ALIGN
    for e, n, o in zip(entries, names, offs):
        ln = len(n) + (4 - len(n) % 4) % 4
        out += struct.pack('<I', ln) + n + b'\0' * (ln - len(n))
        out += struct.pack('<QQ', o, len(e['data']))
        out += hashlib.md5(e['data']).digest()
        out += struct.pack('<I', 0)
    out += b'\0' * (base - len(out))
    for e in entries:
        out += e['data']
        out += b'\0' * ((ALIGN - len(out) % ALIGN) % ALIGN)
    open(path, 'wb').write(out)


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'list':
        p = read(sys.argv[2])
        print(json.dumps({e['path']: e['md5'] for e in p['entries']}))
    elif cmd == 'subset':
        p = read(sys.argv[2])
        want = set(json.load(open(sys.argv[4])))
        write(sys.argv[3], p['ver'], [e for e in p['entries'] if e['path'] in want])
