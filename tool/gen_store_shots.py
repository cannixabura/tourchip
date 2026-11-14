"""各語言 App Store 截圖：沿用繁中版下半部（手機畫面），上方標題與副標換成各語言（文案取自官網 shot1–8）"""
import json, os, subprocess
S = os.path.dirname(os.path.abspath(__file__))
O = '/Users/cannix/tourchip/store/ios'
CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
caps = json.load(open(os.path.join(os.path.dirname(S), 'caps.json'), encoding='utf-8'))
FONT = {
    'zh-Hant': '"PingFang TC"', 'zh-Hans': '"PingFang SC"', 'ja': '"Hiragino Sans"', 'ko': '"Apple SD Gothic Neo"',
    'th': '"Thonburi"', 'hi': '"Kohinoor Devanagari"', 'en': '"Helvetica Neue"', 'ms': '"Helvetica Neue"',
    'id': '"Helvetica Neue"', 'vi': '"Helvetica Neue"', 'pt': '"Helvetica Neue"', 'es': '"Helvetica Neue"',
}
DIR = {'zh-Hant': 'zh-Hant', 'en': 'en'}  # 其他語言放 store/ios/<lang>
W, H = 1320, 2868
CUT = int(H * 0.235)  # 這條線以下沿用原圖（手機與光暈）


def page(lang, base, t, s):
    cjk = lang in ('zh-Hant', 'zh-Hans', 'ja', 'ko')
    fs = W * 0.072 if (len(t) <= 14 if cjk else len(t) <= 26) else W * 0.06
    ss = W * 0.036 if (len(s) <= 34 if cjk else len(s) <= 70) else W * 0.032
    return f'''<html><head><meta charset="utf-8"><style>
body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;font-family:{FONT[lang]},"Helvetica Neue",sans-serif;
background:radial-gradient(ellipse at 50% 0%,#3a1f7a 0%,#141a4a 45%,#070B1F 100%);color:#F3F0FF;text-align:center;position:relative}}
.cap{{position:absolute;left:0;right:0;top:0;height:{CUT}px;display:flex;flex-direction:column;justify-content:center;padding:0 60px;box-sizing:border-box}}
h1{{margin:0;font-size:{int(fs)}px;line-height:1.25;font-weight:700;letter-spacing:1px;
background:linear-gradient(90deg,#d9a8ff,#8fdcff);-webkit-background-clip:text;color:transparent}}
p{{margin:{int(H*0.012)}px 0 0;font-size:{int(ss)}px;line-height:1.35;color:#B9B6D6}}
.base{{position:absolute;left:0;top:{CUT}px;width:{W}px;height:{H-CUT}px;background:url("file://{base}") 0 -{CUT}px / {W}px {H}px no-repeat}}
</style></head><body><div class="cap"><h1>{t}</h1><p>{s}</p></div><div class="base"></div></body></html>'''


def render(html, out):
    tmp = f'{S}/_loc.html'
    open(tmp, 'w', encoding='utf-8').write(html)
    subprocess.run([CH, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                    f'--window-size={W},{H}', f'--screenshot={out}', f'file://{tmp}'], capture_output=True)


for lang, items in caps.items():
    d = DIR.get(lang, lang)
    os.makedirs(f'{O}/{d}', exist_ok=True)
    os.makedirs(f'{O}/{d}_6.3', exist_ok=True)
    for i in range(1, 9):
        t, s = items[str(i)]
        png = f'{O}/{d}/{i:02d}.png'
        render(page(lang, f'{S}/base_zh/{i:02d}.png', t, s), png)
        subprocess.run(['sips', '-z', '2622', '1206', '-s', 'format', 'jpeg', '-s', 'formatOptions', '90', png,
                        '--out', f'{O}/{d}_6.3/{i:02d}.jpg'], capture_output=True)
    print(lang, 'ok')
