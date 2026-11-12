# 檢查廣告文案：結構和各平台字數上限
# 執行：python3 tool/check_posts.py marketing/ads/posts_vi.json [更多檔案…]
#   X：加權字數 ≤ 280（U+0000–10FF 等範圍算 1，其他字元算 2，網址固定 23）
#   Threads ≤ 500、IG ≤ 2200、YouTube 標題 ≤ 100、標題最多兩行
import json, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = 'https://apps.apple.com/app/id6832215611'
KEYS = ['id', 'image', 'theme', 'headline', 'sub', 'x', 'threads', 'ig', 'fb', 'yt_title', 'yt_desc']

def x_len(s):
    n = 0
    s = s.replace('{L}', '\0')
    for ch in s:
        if ch == '\0': n += 23; continue
        c = ord(ch)
        light = c <= 0x10FF or 0x2000 <= c <= 0x200D or 0x2010 <= c <= 0x201F or 0x2032 <= c <= 0x2037
        n += 1 if light else 2
    return n

def check(path):
    ref = json.load(open(os.path.join(ROOT, 'marketing/ads/posts_en.json')))
    posts = json.load(open(path))
    bad = []
    if len(posts) != 20: bad.append(f'應該 20 則，現在 {len(posts)} 則')
    for p, r in zip(posts, ref):
        tag = f"#{p.get('id')}"
        miss = [k for k in KEYS if k not in p]
        if miss: bad.append(f'{tag} 缺欄位 {miss}'); continue
        if p['id'] != r['id'] or p['image'] != r['image'] or p.get('crop') != r.get('crop'):
            bad.append(f'{tag} id／image／crop 要和英文版一樣')
        if p['headline'].count('\n') > 1: bad.append(f'{tag} headline 最多兩行')
        for k in ['x', 'threads', 'ig', 'fb', 'yt_desc']:
            if '{L}' not in p[k] and k != 'ig': bad.append(f'{tag} {k} 沒有 {{L}}')
        lims = [('x', x_len(p['x']), 280), ('threads', len(p['threads'].replace('{L}', L)), 500),
                ('ig', len(p['ig']), 2200), ('yt_title', len(p['yt_title']), 100)]
        for k, n, lim in lims:
            if n > lim: bad.append(f'{tag} {k} {n} > {lim}')
    return bad

ok = True
for path in sys.argv[1:]:
    bad = check(path)
    print(f'{path}: ' + ('OK' if not bad else f'{len(bad)} 個問題'))
    for b in bad: print('  ' + b)
    ok = ok and not bad
sys.exit(0 if ok else 1)
