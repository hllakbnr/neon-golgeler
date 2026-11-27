#!/usr/bin/env python3
"""Diyalog satırlarını Türkçe metin-okuma ile seslendirir (CI'da derlemeden önce).
Önce XTTS v2 (Coqui, çok dilli, doğal insan sesi; kadın/erkek hazır konuşmacılar) denenir;
kurulamazsa Piper (MIT) + rhasspy/piper-voices Türkçe modeline düşülür.
Not: XTTS v2 modeli Coqui Public Model License ile gelir (ticari olmayan kullanım).
Ela için ses perdesi yükseltilir, Kaan için hafif kalınlaştırılır. Çıktı: assets/voice/<id>.ogg
"""
import json, os, subprocess, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
OUT = os.path.join(ROOT, 'assets', 'voice')
MODELS = os.path.join('/tmp', 'piper_models')
HF = 'https://huggingface.co/rhasspy/piper-voices/resolve/main/tr/tr_TR/'
VOICES = {'dfki': 'dfki/medium/tr_TR-dfki-medium', 'fahrettin': 'fahrettin/medium/tr_TR-fahrettin-medium', 'fettah': 'fettah/medium/tr_TR-fettah-medium'}
# karakter → (ses modeli, perde çarpanı)
CAST = {'kaan': ('fahrettin', 0.97), 'ela': ('dfki', 1.24), 'polis': ('fettah', 1.0)}
# XTTS hazır konuşmacıları: Kaan genç erkek, Ela genç kadın, polis tok erkek sesi
XCAST = {'kaan': 'Damien Black', 'ela': 'Ana Florence', 'polis': 'Viktor Menelaos'}


def xtts_all(lines):
    """XTTS ile bütün satırları wav'a çevirir; başaranların id'lerini döndürür."""
    done = {}
    try:
        os.environ.setdefault('COQUI_TOS_AGREED', '1')
        from TTS.api import TTS
        tts = TTS('tts_models/multilingual/multi-dataset/xtts_v2').to('cpu')
    except Exception as e:
        print('XTTS kullanılamadı:', repr(e)[:400])
        return done
    for l in lines:
        who = l.get('who', 'kaan')
        wav = os.path.join('/tmp', 'x_' + l['id'] + '.wav')
        try:
            tts.tts_to_file(text=l['text'], speaker=XCAST.get(who, 'Damien Black'), language='tr', file_path=wav)
            if os.path.getsize(wav) > 1000:
                done[l['id']] = wav
                print('  ✓ XTTS', l['id'], who)
        except Exception as e:
            print('  ✗ XTTS', l['id'], repr(e)[:300])
    return done


def dl(name):
    os.makedirs(MODELS, exist_ok=True)
    base = os.path.join(MODELS, name)
    for ext in ('.onnx', '.onnx.json'):
        p = base + ext
        if not os.path.exists(p):
            try:
                urllib.request.urlretrieve(HF + VOICES[name] + ext, p)
            except Exception as e:
                print('  ✗ ses modeli', name, e)
                return None
    return base + '.onnx'


def synth(model, text, wav):
    tries = [
        [sys.executable, '-m', 'piper', '-m', model, '-f', wav, '--', text],
        ['piper', '--model', model, '--output_file', wav],
    ]
    for cmd in tries:
        try:
            if cmd[-1] == wav:
                r = subprocess.run(cmd, input=text.encode('utf-8'), capture_output=True, timeout=120)
            else:
                r = subprocess.run(cmd, capture_output=True, timeout=120)
            if r.returncode == 0 and os.path.exists(wav) and os.path.getsize(wav) > 1000:
                return True
            print('   piper:', r.stderr.decode('utf-8', 'ignore')[-300:])
        except Exception as e:
            print('   piper hata:', e)
    return False


def main():
    with open(os.path.join(ROOT, 'data', 'dialogs.json'), encoding='utf-8') as f:
        data = json.load(f)
    os.makedirs(OUT, exist_ok=True)
    n = 0
    all_lines = [l for lines in data.values() for l in lines]
    xt = xtts_all(all_lines) if os.environ.get('NG_TTS', 'xtts') == 'xtts' else {}
    for l in all_lines:
            who = l.get('who', 'kaan')
            name, pitch = CAST.get(who, ('dfki', 1.0))
            if l['id'] in xt:
                wav = xt[l['id']]
                pitch = 1.0
            else:
                model = dl(name) or dl('dfki')
                if not model:
                    continue
                wav = os.path.join('/tmp', l['id'] + '.wav')
                if not synth(model, l['text'], wav):
                    print('  ✗', l['id'])
                    continue
            af = 'silenceremove=start_periods=1:start_threshold=-50dB,loudnorm=I=-16:TP=-1.5'
            if abs(pitch - 1.0) > 0.01:
                af = 'asetrate=22050*%.3f,aresample=22050,atempo=%.3f,%s' % (pitch, 1.0 / pitch, af)
            out = os.path.join(OUT, l['id'] + '.ogg')
            try:
                r = subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-af', af, '-c:a', 'libvorbis', '-q:a', '5', out])
                ok = r.returncode == 0
            except FileNotFoundError:
                ok = False
            if not ok:
                # ffmpeg yoksa ham wav (perde değişmeden) kullanılır
                import shutil
                shutil.copy(wav, out[:-4] + '.wav')
                ok = True
            if ok:
                n += 1
                print('  ✓', l['id'], who)
    print('Seslendirilen satır:', n)


if __name__ == '__main__':
    main()
