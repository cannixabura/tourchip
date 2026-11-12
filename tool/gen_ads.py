# 廣告貼文圖：讀 marketing/ads/posts.json，用 assets/images/intro_XX.webp 當底圖，
# 疊上標題、副標、App 圖示與 Apple 官方「App Store 下載」徽章，輸出兩種尺寸：
#   post_XX_4x5.jpg   1080×1350（FB／IG 貼文／Threads／X）
#   post_XX_9x16.jpg  1080×1920（IG／FB 限時動態、Reels、YouTube Shorts 封面）
# 繁中讀 posts.json → images/；英文讀 posts_en.json → images_en/（英文徽章、底部英文字）
# 執行：python3 tool/gen_ads.py（兩種都產生）、python3 tool/gen_ads.py en（只產生英文）
import glob, json, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADS = os.path.join(ROOT, 'marketing/ads')
LANGS = {
    'zh': {'posts': 'posts.json', 'out': 'images', 'badge': 'app_store_badge_zh-tw.png',
           'name': '旅行團 TourChip', 'tag': '團員永遠免費・不用註冊'},
    'en': {'posts': 'posts_en.json', 'out': 'images_en', 'badge': 'app_store_badge_en-us.png',
           'name': 'TourChip', 'tag': 'Always free for members · No sign-up'},
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
def font(size, weight='regular'): return ImageFont.truetype(FONT, size, index=TC[weight])

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
        w = draw.textlength(line, font=f)
        x = cx - w / 2
        if glow is not None:
            ImageDraw.Draw(glow).text((x, y), line, font=f, fill=VIOLET + (255,))
        draw.text((x + 2, y + 3), line, font=f, fill=(0, 0, 0, 120))
        draw.text((x, y), line, font=f, fill=fill)
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
    lines = [l.rstrip('，、') for l in post['headline'].split('\n')]  # 行尾標點會讓置中看起來偏左
    hs = 92 if tall else 84
    longest = max(d.textlength(l, font=font(hs, 'semibold')) for l in lines)
    if longest > w - 120: hs = int(hs * (w - 120) / longest)
    y = text_block(d, layer, lines, font(hs, 'semibold'), w / 2, int(h * (0.135 if tall else 0.06)), INK + (255,), glow)
    y += 16
    ss = 40 if tall else 36
    while ss > 26 and d.textlength(post['sub'], font=font(ss, 'medium')) > w - 100: ss -= 2
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
    d.text((tx, by + 8), L['name'], font=font(44 if tall else 40, 'semibold'), fill=INK)
    d.text((tx, by + icon_s - 46), L['tag'], font=font(30 if tall else 28), fill=MUTED)
    badge = Image.open(os.path.join(ADS, 'assets', L['badge'])).convert('RGBA')
    bh = 104 if tall else 92
    badge = badge.resize((round(badge.width * bh / badge.height), bh), Image.LANCZOS)
    if tall:  # 直式：徽章放在名稱下方置中，比較好點
        img.alpha_composite(badge, ((w - badge.width) // 2, by - bh - 44))
    else:
        img.alpha_composite(badge, (w - pad - badge.width, by + (icon_s - bh) // 2))
    img.convert('RGB').save(path, quality=90, optimize=True, progressive=True)

def main():
    for lang in sys.argv[1:] or list(LANGS):
        L = LANGS[lang]
        out = os.path.join(ADS, L['out'])
        os.makedirs(out, exist_ok=True)
        posts = json.load(open(os.path.join(ADS, L['posts']), encoding='utf-8'))
        for p in posts:
            n = f"{p['id']:02d}"
            make(p, 1080, 1350, os.path.join(out, f'post_{n}_4x5.jpg'), L)
            make(p, 1080, 1920, os.path.join(out, f'post_{n}_9x16.jpg'), L)
        print(lang, len(posts), 'posts →', out)

if __name__ == '__main__':
    main()
