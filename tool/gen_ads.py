# 廣告貼文圖：讀 marketing/ads/posts.json，用 assets/images/intro_XX.webp 當底圖，
# 疊上標題、副標、App 圖示與 Apple 官方「App Store 下載」徽章，輸出兩種尺寸：
# 圖片放在官網 hosting/ads/ 底下（部署後是公開網址，給自動貼文抓圖）
#   post_XX_4x5.jpg   1080×1350（FB／IG 貼文／Threads／X）
#   post_XX_9x16.jpg  1080×1920（IG／FB 限時動態、Reels、YouTube Shorts 封面）
# 繁中讀 posts.json → hosting/ads/zh/；英文 posts_en.json → hosting/ads/en/；日文 posts_ja.json → hosting/ads/ja/；韓文 posts_ko.json → hosting/ads/ko/；越南、泰、馬來、印尼、葡萄牙、西班牙、印地文 posts_{vi,th,ms,id,pt,es,hi}.json → hosting/ads/{…}/；簡體中文 posts_zh_hans.json → hosting/ads/zh-hans/（各用該語言的徽章與底部文字）
# 執行：python3 tool/gen_ads.py（全部語言）、python3 tool/gen_ads.py ja（只產生日文）
import glob, json, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADS = os.path.join(ROOT, 'marketing/ads')
LANGS = {
    'zh': {'posts': 'posts.json', 'out': 'zh', 'badge': 'app_store_badge_zh-tw.png',
           'name': '旅行團 TourChip', 'tag': '團員永遠免費・不用註冊'},
    'en': {'posts': 'posts_en.json', 'out': 'en', 'badge': 'app_store_badge_en-us.png',
           'name': 'TourChip', 'tag': 'Always free for members · No sign-up'},
    'ja': {'posts': 'posts_ja.json', 'out': 'ja', 'badge': 'app_store_badge_ja-jp.png',
           'name': 'TourChip', 'tag': 'メンバーはずっと無料・登録不要'},
    'ko': {'posts': 'posts_ko.json', 'out': 'ko', 'badge': 'app_store_badge_ko-kr.png',
           'name': 'TourChip', 'tag': '멤버는 항상 무료 · 회원가입 필요 없음'},
    'vi': {'posts': 'posts_vi.json', 'out': 'vi', 'badge': 'app_store_badge_vi-vn.png',
           'name': 'TourChip', 'tag': 'Thành viên luôn miễn phí · Không cần đăng ký'},
    'th': {'posts': 'posts_th.json', 'out': 'th', 'badge': 'app_store_badge_th-th.png',
           'name': 'TourChip', 'tag': 'สมาชิกฟรีตลอด · ไม่ต้องสมัคร'},
    'ms': {'posts': 'posts_ms.json', 'out': 'ms', 'badge': 'app_store_badge_ms-my.png',
           'name': 'TourChip', 'tag': 'Ahli sentiasa percuma · Tanpa daftar'},
    'id': {'posts': 'posts_id.json', 'out': 'id', 'badge': 'app_store_badge_id-id.png',
           'name': 'TourChip', 'tag': 'Anggota selalu gratis · Tanpa daftar'},
    'pt': {'posts': 'posts_pt.json', 'out': 'pt', 'badge': 'app_store_badge_pt-br.png',
           'name': 'TourChip', 'tag': 'Sempre grátis para membros · Sem cadastro'},
    'es': {'posts': 'posts_es.json', 'out': 'es', 'badge': 'app_store_badge_es-mx.png',
           'name': 'TourChip', 'tag': 'Siempre gratis para miembros · Sin registro'},
    # Apple 沒有印地文徽章，用英文版
    'hi': {'posts': 'posts_hi.json', 'out': 'hi', 'badge': 'app_store_badge_en-us.png',
           'name': 'TourChip', 'tag': 'सदस्यों के लिए हमेशा मुफ़्त · साइन-अप नहीं'},
    'zh-hans': {'posts': 'posts_zh_hans.json', 'out': 'zh-hans', 'badge': 'app_store_badge_zh-cn.png',
           'name': '旅行团 TourChip', 'tag': '团员永远免费・不用注册'},
}
ICON = os.path.join(ROOT, 'assets/icon/app_icon.png')

def find_font():
    for pat in ['/System/Library/AssetsV2/com_apple_MobileAsset_Font*/*/AssetData/PingFang.ttc',
                '/System/Library/Fonts/PingFang.ttc']:
        hit = glob.glob(pat)
        if hit: return hit[0]
    raise SystemExit('找不到 PingFang 字型')

FONT = find_font()
TC = {'regular': 2, 'medium': 6, 'semibold': 10}
SC = {'regular': 3, 'medium': 7, 'semibold': 11}  # 簡體中文用 PingFang SC
# 日文用ヒラギノ角ゴシック（用 PingFang TC 的話，日文漢字會是中文字形）
JA = {'regular': '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc',
      'medium': '/System/Library/Fonts/ヒラギノ角ゴシック W5.ttc',
      'semibold': '/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc'}
CUR_LANG = 'zh'
# 韓文用 Apple SD Gothic Neo（Regular 0、Medium 2、SemiBold 4）
KO = '/System/Library/Fonts/AppleSDGothicNeo.ttc'
KO_IDX = {'regular': 0, 'medium': 2, 'semibold': 4}
# 越南文、馬來文、印尼文、葡萄牙文用 Helvetica Neue（PingFang 沒有越南文的聲調字母）；泰文用 Sukhumvit Set
LATIN = '/System/Library/Fonts/HelveticaNeue.ttc'
LATIN_IDX = {'regular': 0, 'medium': 10, 'semibold': 1}
# 泰文用 Sukhumvit Set，但 PIL 沒有 raqm 時聲調符號位置會錯，所以交給 macOS CoreText 排（tool/render_text.swift）
THAI_PS = {'regular': 'SukhumvitSet-Text', 'medium': 'SukhumvitSet-Medium', 'semibold': 'SukhumvitSet-SemiBold'}
# 印地文（天城文）的連字和母音符號也要 CoreText 排
HINDI_PS = {'regular': 'KohinoorDevanagari-Regular', 'medium': 'KohinoorDevanagari-Medium', 'semibold': 'KohinoorDevanagari-Semibold'}
class CTFont:
    def __init__(self, name, size): self.name, self.size = name, size
RENDER = os.path.join(ROOT, 'tool/.build/render_text')
_ct = {}
def ct_render(f, s):
    key = (f.name, f.size, s)
    if key not in _ct:
        import subprocess, tempfile
        src = os.path.join(ROOT, 'tool/render_text.swift')
        if not os.path.exists(RENDER) or os.path.getmtime(RENDER) < os.path.getmtime(src):
            os.makedirs(os.path.dirname(RENDER), exist_ok=True)
            subprocess.run(['swiftc', '-O', src, '-o', RENDER], check=True)
        with tempfile.NamedTemporaryFile(suffix='.png') as tmp:
            out = subprocess.run([RENDER, f.name, str(f.size), s, tmp.name], check=True, capture_output=True, text=True).stdout.split()
            _ct[key] = (Image.open(tmp.name).convert('RGBA'), float(out[0]), int(out[1]))
    return _ct[key]

def tlen(d, s, f):
    return ct_render(f, s)[1] if isinstance(f, CTFont) else d.textlength(s, font=f)

def tdraw(target, xy, s, f, fill):
    if not isinstance(f, CTFont):
        ImageDraw.Draw(target).text(xy, s, font=f, fill=fill); return
    img, _, pad = ct_render(f, s)
    color = Image.new('RGBA', img.size, tuple(fill[:3]) + (0,))
    a = fill[3] if len(fill) > 3 else 255
    color.putalpha(img.getchannel('A').point(lambda v: v * a // 255))
    target.alpha_composite(color, (max(0, round(xy[0] - pad)), max(0, round(xy[1] - pad))))
def font(size, weight='regular'):
    if CUR_LANG in ('vi', 'ms', 'id', 'pt', 'es'): return ImageFont.truetype(LATIN, size, index=LATIN_IDX[weight])
    if CUR_LANG == 'th': return CTFont(THAI_PS[weight], size)
    if CUR_LANG == 'hi': return CTFont(HINDI_PS[weight], size)
    if CUR_LANG == 'zh-hans': return ImageFont.truetype(FONT, size, index=SC[weight])
    if CUR_LANG == 'ja': return ImageFont.truetype(JA[weight], size, index=0)
    if CUR_LANG == 'ko': return ImageFont.truetype(KO, size, index=KO_IDX[weight])
    return ImageFont.truetype(FONT, size, index=TC[weight])

INK = (243, 240, 255)
MUTED = (215, 210, 240)
NIGHT = (7, 11, 31)
VIOLET = (180, 76, 255)

def cover(img, w, h, anchor):
    s = max(w / img.width, h / img.height)
    img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    x = (img.width - w) // 2
    y = {'top': 0, 'center': (img.height - h) // 2, 'bottom': img.height - h}[anchor]
    return img.crop((x, y, x + w, y + h))

def gradient(w, h, top_h, bottom_h):
    g = Image.new('L', (1, h), 0)
    for y in range(h):
        a = 0
        if y < top_h: a = int(225 * (1 - y / top_h) ** 1.2)
        if y > h - bottom_h: a = max(a, int(235 * ((y - (h - bottom_h)) / bottom_h) ** 1.2))
        g.putpixel((0, y), a)
    return g.resize((w, h))

def text_block(draw, layer, lines, f, cx, y, fill, glow=None, gap=1.25):
    for line in lines:
        w = tlen(draw, line, f)
        x = cx - w / 2
        if glow is not None:
            tdraw(glow, (x, y), line, f, VIOLET + (255,))
        tdraw(layer, (x + 2, y + 3), line, f, (0, 0, 0, 120))
        tdraw(layer, (x, y), line, f, fill)
        y += f.size * gap
    return y

def rounded(img, r):
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, img.width - 1, img.height - 1), r, fill=255)
    img = img.convert('RGBA'); img.putalpha(m); return img

def make(post, w, h, path, L):
    base = Image.open(os.path.join(ROOT, 'assets/images', post['image'] + '.webp')).convert('RGB')
    tall = h / w > 1.6
    anchor = post.get('crop', 'top')
    if tall and anchor == 'bottom':
        # 直式和原圖同比例，同一張圖第二次用時放大 1.25 倍取下半部，畫面才不會一樣
        z = base.resize((round(base.width * 1.25), round(base.height * 1.25)), Image.LANCZOS)
        img = cover(z, w, h, 'bottom').convert('RGBA')
    else:
        img = cover(base, w, h, 'center' if tall else anchor).convert('RGBA')
    top_h, bottom_h = int(h * (0.42 if tall else 0.42)), int(h * (0.42 if tall else 0.34))
    shade = Image.new('RGBA', (w, h), NIGHT + (0,))
    shade.putalpha(gradient(w, h, top_h, bottom_h))
    img = Image.alpha_composite(img, shade)

    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    lines = [l.rstrip('，、,') for l in post['headline'].split('\n')]  # 行尾標點會讓置中看起來偏左
    hs = 92 if tall else 84
    longest = max(tlen(d, l, font(hs, 'semibold')) for l in lines)
    if longest > w - 120: hs = int(hs * (w - 120) / longest)
    y = text_block(d, layer, lines, font(hs, 'semibold'), w / 2, int(h * (0.135 if tall else 0.06)), INK + (255,), glow)
    y += 16
    ss = 40 if tall else 36
    while ss > 26 and tlen(d, post['sub'], font(ss, 'medium')) > w - 100: ss -= 2
    sf = font(ss, 'medium')
    text_block(d, layer, [post['sub']], sf, w / 2, y, MUTED + (255,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(18)))
    img = Image.alpha_composite(img, layer)

    # 底部：App 圖示＋名稱＋免費說明（左），App Store 徽章（右）
    pad = 56
    icon_s = 132 if tall else 120
    by = h - pad - icon_s - (280 if tall else 0)  # 直式避開 Reels／限時動態下方的按鈕與回覆列
    icon = rounded(Image.open(ICON).convert('RGB').resize((icon_s, icon_s), Image.LANCZOS), int(icon_s * 0.225))
    img.alpha_composite(icon, (pad, by))
    d = ImageDraw.Draw(img)
    tx = pad + icon_s + 26
    badge = Image.open(os.path.join(ADS, 'assets', L['badge'])).convert('RGBA')
    bh = 104 if tall else 92
    badge = badge.resize((round(badge.width * bh / badge.height), bh), Image.LANCZOS)
    tdraw(img, (tx, by + 8), L['name'], font(44 if tall else 40, 'semibold'), INK)
    room = (w - pad if tall else w - pad - badge.width - 24) - tx  # 說明文字太長就縮小，不要壓到徽章
    ts = 30 if tall else 28
    while ts > 20 and tlen(d, L['tag'], font(ts)) > room: ts -= 1
    tdraw(img, (tx, by + icon_s - 18 - ts), L['tag'], font(ts), MUTED)
    if tall:  # 直式：徽章放在名稱下方置中，比較好點
        img.alpha_composite(badge, ((w - badge.width) // 2, by - bh - 44))
    else:
        img.alpha_composite(badge, (w - pad - badge.width, by + (icon_s - bh) // 2))
    img.convert('RGB').save(path, quality=90, optimize=True, progressive=True)

def main():
    global CUR_LANG
    for lang in sys.argv[1:] or list(LANGS):
        L = LANGS[lang]
        CUR_LANG = lang
        out = os.path.join(ROOT, 'hosting/ads', L['out'])  # 放在官網，自動貼文用 https://tourchip.web.app/ads/<語言>/post_XX_4x5.jpg
        os.makedirs(out, exist_ok=True)
        posts = json.load(open(os.path.join(ADS, L['posts']), encoding='utf-8'))
        for p in posts:
            n = f"{p['id']:02d}"
            make(p, 1080, 1350, os.path.join(out, f'post_{n}_4x5.jpg'), L)
            make(p, 1080, 1920, os.path.join(out, f'post_{n}_9x16.jpg'), L)
        print(lang, len(posts), 'posts →', out)

if __name__ == '__main__':
    main()
