"""官網分享預覽圖（OG 圖，1200×630）：18 種語言各一張；用法 python3 tool/gen_og.py [語言…]（不給就全部重畫）。
用法：python3 tool/gen_og.py
輸出：hosting/img/og/<lang>.jpg（繁中另外沿用 hosting/img/og.jpg 給首頁 /）
畫法和原本的繁中圖一樣：左邊 App 圖示，右邊「App 名稱」＋一句副標，夜光紫背景。
"""
import os, subprocess, tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
OUT = f'{ROOT}/hosting/img/og'
ICON = f'{ROOT}/hosting/img/icon-512.png'

# (名稱前半, 副標)；名稱後面一律接 TourChip
TEXT = {
    'zh-Hant': ('旅行團', '集合、點名、公告，帶團不走散'),
    'zh-Hans': ('旅行团', '集合、点名、公告，带团不走散'),
    'en': ('', 'Meetups, roll call and notices. Nobody gets left behind.'),
    'ja': ('', '集合・点呼・お知らせで、はぐれない'),
    'ko': ('', '집합·출석·공지로 단체 여행 걱정 끝'),
    'ms': ('', 'Berkumpul, panggil nama, notis. Tiada siapa tertinggal.'),
    'id': ('', 'Kumpul, absen, pengumuman. Tak ada yang tertinggal.'),
    'vi': ('', 'Tập trung, điểm danh, thông báo. Không ai bị lạc.'),
    'th': ('', 'นัดรวม เช็กชื่อ ประกาศ ไม่มีใครหลงกลุ่ม'),
    'pt': ('', 'Encontros, chamada e avisos. Ninguém fica para trás.'),
    'es': ('', 'Encuentros, lista y avisos. Nadie se queda atrás.'),
    'hi': ('', 'इकट्ठा होना, हाज़िरी, सूचनाएँ। कोई पीछे नहीं छूटेगा।'),
    'fr': ('', 'Rassemblements, appel et annonces. Personne n’est oublié.'),
    'de': ('', 'Sammeln, Durchzählen, Mitteilungen. Niemand bleibt zurück.'),
    'it': ('', 'Ritrovi, appello e avvisi. Nessuno resta indietro.'),
    'cs': ('', 'Srazy, prezence a oznámení. Nikdo nezůstane pozadu.'),
    'pl': ('', 'Zbiórki, obecność i ogłoszenia. Nikt nie zostanie w tyle.'),
    'uk': ('', 'Збори, перекличка й оголошення. Ніхто не відстане.'),
}
FONT = {'zh-Hant': 'PingFang TC', 'zh-Hans': 'PingFang SC', 'ja': 'Hiragino Sans', 'ko': 'Apple SD Gothic Neo',
        'th': 'Thonburi', 'hi': 'Kohinoor Devanagari'}


def page(lang):
    pre, sub = TEXT[lang]
    name = f'{pre} TourChip' if pre else 'TourChip'
    cjk = lang in ('zh-Hant', 'zh-Hans', 'ja', 'ko')
    long_sub = not cjk and len(sub) > 30
    return f'''<html><head><meta charset="utf-8"><style>
html,body{{margin:0;width:1200px;height:630px;overflow:hidden}}
body{{font-family:"{FONT.get(lang, 'Helvetica Neue')}","Helvetica Neue",sans-serif;
 background:radial-gradient(ellipse 70% 90% at 78% 55%,#3a1f6e 0%,#1d1446 45%,#0b0c22 80%,#08091a 100%);
 display:flex;align-items:center}}
.icon{{margin-left:84px;width:350px;height:350px;border-radius:78px;flex:none;
 background:url("file://{ICON}") center/cover;box-shadow:0 0 70px 10px rgba(150,70,255,.45)}}
.t{{margin-left:58px;margin-right:50px}}
h1{{margin:0;font-size:{80 if pre else 104}px;font-weight:700;letter-spacing:1px;line-height:1.15;white-space:nowrap;
 background:linear-gradient(90deg,#d9a8ff,#8fdcff);-webkit-background-clip:text;color:transparent}}
p{{margin:26px 0 0;font-size:{34 if long_sub else 40}px;line-height:1.4;color:#c9c5e6;letter-spacing:{0 if long_sub else 2}px;{'white-space:nowrap;font-size:34px' if cjk else ''}}}
</style></head><body><div class="icon"></div><div class="t"><h1>{name}</h1><p>{sub}</p></div></body></html>'''


def main():
    os.makedirs(OUT, exist_ok=True)
    import sys
    for lang in (sys.argv[1:] or TEXT):
        with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False, encoding='utf-8') as f:
            f.write(page(lang))
            tmp = f.name
        png = tmp + '.png'
        subprocess.run([CH, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                        '--allow-file-access-from-files', '--window-size=1200,630', f'--screenshot={png}', f'file://{tmp}'],
                       capture_output=True)
        Image.open(png).convert('RGB').save(f'{OUT}/{lang}.jpg', quality=88, optimize=True)
        os.remove(tmp); os.remove(png)
        print(lang)


if __name__ == '__main__':
    main()
