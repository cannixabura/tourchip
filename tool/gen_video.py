"""展示影片合成：python3 tool/gen_video.py <錄影資料夾> [語言…]
<錄影資料夾>/<lang>/raw.mov、timeline.json（scratchpad/record.py 用 debug 版展示模式錄的）
輸出 store/video/<lang>/tourchip_<lang>_vertical.mp4（1080×1920）與 _horizontal.mp4（1920×1080）
文字：場景標題 store/ios/captions.json；開頭、結尾 store/video_text.json（取自官網）
"""
import json, os, re, subprocess, sys
VID = sys.argv[1]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
caps = json.load(open(f'{ROOT}/store/ios/captions.json', encoding='utf-8'))
web = json.load(open(f'{ROOT}/store/video_text.json', encoding='utf-8'))
FONT = {'zh-Hant': 'PingFang TC', 'zh-Hans': 'PingFang SC', 'ja': 'Hiragino Sans', 'ko': 'Apple SD Gothic Neo',
        'th': 'Thonburi', 'hi': 'Kohinoor Devanagari'}
# 場景：(timeline 開始, timeline 結束, captions.json 編號, 最長秒數)
# (timeline 開始, timeline 結束, captions.json 編號, 最長秒數, 開始往後延幾秒：集合卡滑進來要約 4 秒)
SCENES = [('map', 'call', '3', 6, 0), ('call', 'chat', '2', 6, 3.5), ('chat', 'aiya', '4', 5, 0), ('aiya', 'spot', '7', 26, 0), ('spot', 'end', '8', 8, 0)]
FPS = 30
LAYOUT = {
    'vertical': dict(W=1080, H=1920, ph=1480, px=None, py=380),
    'horizontal': dict(W=1920, H=1080, ph=1000, px=1300, py=40),
}
BG = 'radial-gradient(ellipse at 50% 0%,#3a1f7a 0%,#141a4a 45%,#070B1F 100%)'


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(' '.join(cmd[:6]) + '\n' + r.stderr[-1500:])


def shot(html, out, W, H, transparent=False):
    tmp = f'{VID}/_v.html'
    open(tmp, 'w', encoding='utf-8').write(html)
    cmd = [CH, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
           f'--window-size={W},{H}', f'--screenshot={out}']
    if transparent:
        cmd.append('--default-background-color=00000000')
    run(cmd + [f'file://{tmp}'])


def phone_box(L):
    ph = L['ph']; pw = int(ph * 1320 / 2868) // 2 * 2
    px = L['px'] if L['px'] is not None else (L['W'] - pw) // 2 // 2 * 2
    return px, L['py'], pw, ph


def overlay_png(lang, kind, title, sub, out):
    """背景＋標題，手機位置挖一個圓角透明洞（洞外有光暈邊框）"""
    L = LAYOUT[kind]; W, H = L['W'], L['H']
    px, py, pw, ph = phone_box(L)
    r = int(pw * 0.11)
    font = FONT.get(lang, 'Helvetica Neue')
    if kind == 'vertical':
        cap = f'left:60px;right:60px;top:0;height:{py - 20}px;align-items:center;text-align:center'
        fs, ss = (66, 34) if len(title) <= (14 if lang in ('zh-Hant', 'zh-Hans', 'ja', 'ko') else 24) else (56, 32)
    else:
        cap = f'left:120px;width:{px - 220}px;top:0;bottom:0;align-items:flex-start;text-align:left'
        fs, ss = 72, 36
    return shot(f'''<html><head><meta charset="utf-8"><style>
body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;background:transparent;font-family:"{font}","Helvetica Neue",sans-serif}}
.bg{{position:absolute;inset:0;background:{BG};
-webkit-mask:linear-gradient(#000 0 0),linear-gradient(#000 0 0);-webkit-mask-composite:xor;
-webkit-mask-size:100% 100%,{pw}px {ph}px;-webkit-mask-position:0 0,{px}px {py}px;-webkit-mask-repeat:no-repeat}}
.hole{{position:absolute;left:{px - 6}px;top:{py - 6}px;width:{pw}px;height:{ph}px;border:6px solid #2A2F66;border-radius:{r}px;
box-shadow:0 0 70px rgba(180,76,255,.5)}}
.corner{{position:absolute;left:{px}px;top:{py}px;width:{pw}px;height:{ph}px;border-radius:{r}px;box-shadow:0 0 0 {r}px #0d1236}}
.cap{{position:absolute;{cap};display:flex;flex-direction:column;justify-content:center;color:#F3F0FF}}
h1{{margin:0;font-size:{fs}px;line-height:1.25;font-weight:700;background:linear-gradient(90deg,#d9a8ff,#8fdcff);-webkit-background-clip:text;color:transparent}}
p{{margin:18px 0 0;font-size:{ss}px;line-height:1.4;color:#B9B6D6}}
.brand{{position:absolute;{'right:40px;bottom:30px' if kind == 'vertical' else 'left:120px;bottom:60px'};font:600 26px "Helvetica Neue";color:#8f8cb8;letter-spacing:2px}}
</style></head><body><div class="bg"></div><div class="hole"></div>
<div class="cap"><h1>{title}</h1><p>{sub}</p></div><div class="brand">TourChip · tourchip.web.app</div></body></html>''', out, W, H, transparent=True)


def card_png(lang, kind, which, out):
    L = LAYOUT[kind]; W, H = L['W'], L['H']
    t = web[lang]; font = FONT.get(lang, 'Helvetica Neue')
    if which == 'open':
        h = re.sub(r'</?em>', '', t['hero_h']).replace('<br>', '<br>')
        body = f'''<div class="img"></div><div class="shade"></div>
<div class="txt"><h1>{h}</h1><p>{t['hero_free']}</p></div>'''
    else:
        body = f'''<div class="end"><img src="file://{ROOT}/assets/icon/app_icon.png"><h1>{t['cta_h']}</h1>
<p>{t['hero_free']}</p><div class="url">tourchip.web.app</div></div>'''
    big = 84 if kind == 'vertical' else 76
    shot(f'''<html><head><meta charset="utf-8"><style>
body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;background:{BG};font-family:"{font}","Helvetica Neue",sans-serif;color:#F3F0FF}}
.img{{position:absolute;inset:0;background:url("file://{ROOT}/assets/images/intro_01.webp") center/cover}}
.shade{{position:absolute;inset:0;background:linear-gradient(180deg,rgba(7,11,31,0) 35%,rgba(7,11,31,.92) 85%)}}
.txt{{position:absolute;left:70px;right:70px;bottom:{'260' if kind == 'vertical' else '110'}px;text-align:center}}
h1{{margin:0;font-size:{big}px;line-height:1.25;font-weight:800}}
p{{margin:24px 0 0;font-size:{36 if kind == 'vertical' else 32}px;color:#cfcaf0}}
.end{{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 80px}}
.end img{{width:{260 if kind == 'vertical' else 200}px;border-radius:22%;box-shadow:0 0 90px rgba(180,76,255,.6);margin-bottom:56px}}
.end h1{{background:linear-gradient(90deg,#d9a8ff,#8fdcff);-webkit-background-clip:text;color:transparent}}
.url{{margin-top:48px;font:600 44px "Helvetica Neue";letter-spacing:2px;color:#8fdcff}}
</style></head><body>{body}</body></html>''', out, W, H)


def still(png, secs, out, fade_in=False, fade_out=True):
    vf = 'format=yuv420p'
    if fade_in:
        vf = f'fade=t=in:st=0:d=0.5,{vf}'
    if fade_out:
        vf = f'fade=t=out:st={secs - 0.5}:d=0.5,{vf}'
    run(['ffmpeg', '-y', '-v', 'error', '-loop', '1', '-framerate', str(FPS), '-i', png, '-t', str(secs),
         '-vf', vf, '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p', '-r', str(FPS), out])


def segment(raw, a, b, png, kind, out, max_secs):
    L = LAYOUT[kind]; px, py, pw, ph = phone_box(L)
    dur = b - a
    speed = max(1.0, dur / max_secs)
    outdur = dur / speed
    fc = (f'[0:v]setpts=(PTS-STARTPTS)/{speed:.4f},fps={FPS},scale={pw}:{ph}[v];'
          f'color=c=#0d1236:s={L["W"]}x{L["H"]}:r={FPS}[bg];[bg][v]overlay={px}:{py}:shortest=1[t];'
          f'[t][1:v]overlay=0:0,format=yuv420p')
    run(['ffmpeg', '-y', '-v', 'error', '-ss', f'{a:.2f}', '-t', f'{dur:.2f}', '-i', raw, '-loop', '1', '-i', png,
         '-filter_complex', fc, '-t', f'{outdur:.2f}', '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-r', str(FPS), out])


langs = sys.argv[2:] or [d for d in sorted(os.listdir(VID)) if os.path.exists(f'{VID}/{d}/timeline.json')]
for lang in langs:
    src = f'{VID}/{lang}'
    tl = json.load(open(f'{src}/timeline.json'))
    if not all(k in tl for k in ('map', 'call', 'chat', 'aiya', 'spot', 'end')):
        print(lang, 'timeline incomplete', tl); continue
    outdir = f'{ROOT}/store/video/{lang}'
    os.makedirs(outdir, exist_ok=True)
    for kind in LAYOUT:
        work = f'{src}/{kind}'
        os.makedirs(work, exist_ok=True)
        parts = []
        card_png(lang, kind, 'open', f'{work}/open.png')
        still(f'{work}/open.png', 3.0, f'{work}/p0.mp4', fade_in=True)
        parts.append('p0.mp4')
        for i, (k0, k1, cap, mx, delay) in enumerate(SCENES, 1):
            t, s = caps[lang][cap]
            overlay_png(lang, kind, t, s, f'{work}/c{i}.png')
            a = tl[k0] + delay - (0.2 if i > 1 and not delay else 0)
            b = tl[k1] + (0.6 if k1 == 'end' else 0)
            segment(f'{src}/raw.mov', a, b, f'{work}/c{i}.png', kind, f'{work}/p{i}.mp4', mx)
            parts.append(f'p{i}.mp4')
        card_png(lang, kind, 'end', f'{work}/end.png')
        still(f'{work}/end.png', 4.0, f'{work}/p9.mp4', fade_in=True)
        parts.append('p9.mp4')
        open(f'{work}/list.txt', 'w').write(''.join(f"file '{p}'\n" for p in parts))
        out = f'{outdir}/tourchip_{lang}_{kind}.mp4'
        run(['ffmpeg', '-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', f'{work}/list.txt', '-c', 'copy',
             '-movflags', '+faststart', out])
        d = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', out], capture_output=True, text=True).stdout.strip()
        print(lang, kind, f'{float(d):.1f}s')
