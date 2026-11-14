"""商店截圖：各語言的 App 畫面（截圖模式拍的原圖）＋各語言標題、副標。
用法：python3 tool/gen_store_shots.py <原圖資料夾>
  <原圖資料夾>/<lang>/01.png … 08.png（1320×2868，tool/demo_data.py ＋ debug 版截圖模式拍的）
輸出：store/ios/<dir>/NN.png（6.9 吋）、store/ios/<dir>_6.3/NN.jpg（ASC 用的 6.3 吋）、store/play/<lang>/NN.png
標題與副標在 store/ios/captions.json（取自官網 shot1–8）
"""
import json, os, subprocess, sys
RAW = sys.argv[1]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
caps = json.load(open(f'{ROOT}/store/ios/captions.json', encoding='utf-8'))
FONT = {'zh-Hant': 'PingFang TC', 'zh-Hans': 'PingFang SC', 'ja': 'Hiragino Sans', 'ko': 'Apple SD Gothic Neo',
        'th': 'Thonburi', 'hi': 'Kohinoor Devanagari'}
DIR = {'zh-Hant': 'zh-Hant', 'en': 'en'}
PLAY = {'zh-Hant': 'zh-TW', 'en': 'en-US'}
CJK = ('zh-Hant', 'zh-Hans', 'ja', 'ko')


def page(lang, img, t, s, W, H):
    shot_h = int(H * 0.74); shot_w = int(shot_h * 1320 / 2868)
    long_t = len(t) > (14 if lang in CJK else 26)
    long_s = len(s) > (34 if lang in CJK else 70)
    fs = int(W * (0.06 if long_t else 0.072)); ss = int(W * (0.032 if long_s else 0.036))
    return f'''<html><head><meta charset="utf-8"><style>
body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;font-family:"{FONT.get(lang, 'Helvetica Neue')}","Helvetica Neue",sans-serif;
background:radial-gradient(ellipse at 50% 0%,#3a1f7a 0%,#141a4a 45%,#070B1F 100%);color:#F3F0FF;text-align:center}}
.cap{{position:absolute;left:0;right:0;top:0;height:{int(H*0.235)}px;display:flex;flex-direction:column;justify-content:center;padding:0 {int(W*0.045)}px}}
h1{{margin:0;font-size:{fs}px;line-height:1.25;font-weight:700;letter-spacing:1px;background:linear-gradient(90deg,#d9a8ff,#8fdcff);-webkit-background-clip:text;color:transparent}}
p{{margin:{int(H*0.012)}px 0 0;font-size:{ss}px;line-height:1.35;color:#B9B6D6}}
.f{{position:absolute;left:50%;bottom:-{int(H*0.02)}px;transform:translateX(-50%);width:{shot_w}px;height:{shot_h}px;
border-radius:{int(shot_w*0.12)}px;overflow:hidden;border:{max(6,int(W*0.008))}px solid #2A2F66;
box-shadow:0 0 80px rgba(180,76,255,.45),0 30px 80px rgba(0,0,0,.6)}}
.f img{{width:100%;height:100%;object-fit:cover}}</style></head><body>
<div class="cap"><h1>{t}</h1><p>{s}</p></div><div class="f"><img src="file://{img}"></div></body></html>'''


def render(html, out, W, H):
    tmp = f'{RAW}/_p.html'
    open(tmp, 'w', encoding='utf-8').write(html)
    subprocess.run([CH, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                    f'--window-size={W},{H}', f'--screenshot={out}', f'file://{tmp}'], capture_output=True)


for lang, items in caps.items():
    if not os.path.isdir(f'{RAW}/{lang}'):
        print(lang, 'no raw'); continue
    d, pd = DIR.get(lang, lang), PLAY.get(lang, lang)
    for sub in (f'store/ios/{d}', f'store/ios/{d}_6.3', f'store/play/{pd}'):
        os.makedirs(f'{ROOT}/{sub}', exist_ok=True)
    for i in range(1, 9):
        img = f'{RAW}/{lang}/{i:02d}.png'
        if not os.path.exists(img):
            print(lang, i, 'missing'); continue
        t, s = items[str(i)]
        png = f'{ROOT}/store/ios/{d}/{i:02d}.png'
        render(page(lang, img, t, s, 1320, 2868), png, 1320, 2868)
        subprocess.run(['sips', '-z', '2622', '1206', '-s', 'format', 'jpeg', '-s', 'formatOptions', '90', png,
                        '--out', f'{ROOT}/store/ios/{d}_6.3/{i:02d}.jpg'], capture_output=True)
        render(page(lang, img, t, s, 1080, 2160), f'{ROOT}/store/play/{pd}/{i:02d}.png', 1080, 2160)
    print(lang, 'ok')
