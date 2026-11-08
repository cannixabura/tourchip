# -*- coding: utf-8 -*-
# 旅行團 TourChip 圖示提案：5 款（夜光設計系統配色）
# 用法：python3 assets/icon/options/gen_options.py → 產生 1.svg … 5.svg，再用 render.sh 轉 PNG
import math, pathlib

W = 1024
OUT = pathlib.Path(__file__).parent

DEFS = '''<defs>
<radialGradient id="sky" cx="50%" cy="65%" r="80%"><stop offset="0" stop-color="#2A2F66"/><stop offset=".55" stop-color="#121848"/><stop offset="1" stop-color="#070B1F"/></radialGradient>
<linearGradient id="deep" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6A1FD8"/><stop offset=".55" stop-color="#3A2DB8"/><stop offset="1" stop-color="#1E5FD4"/></linearGradient>
<linearGradient id="beam" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".35" stop-color="#BFEFFF"/><stop offset=".75" stop-color="#4FC3F7" stop-opacity=".85"/><stop offset="1" stop-color="#4FC3F7" stop-opacity="0"/></linearGradient>
<linearGradient id="aur" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#B44CFF"/><stop offset="1" stop-color="#4FC3F7"/></linearGradient>
<linearGradient id="flag" x1="0" y1="0" x2="1" y2=".4"><stop offset="0" stop-color="#FF5FD2"/><stop offset="1" stop-color="#B44CFF"/></linearGradient>
<linearGradient id="warm" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFD54A"/><stop offset="1" stop-color="#FF8A3D"/></linearGradient>
<radialGradient id="pool" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#8FDCFF" stop-opacity=".6"/><stop offset="1" stop-color="#4FC3F7" stop-opacity="0"/></radialGradient>
<radialGradient id="core" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".4" stop-color="#BFEFFF"/><stop offset="1" stop-color="#4FC3F7" stop-opacity="0"/></radialGradient>
<filter id="glow" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="22"/></filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>
</defs>'''

COLS = ['#FFB547', '#4DE3A0', '#FF5FD2', '#5AB8FF', '#FFD54A', '#F3F0FF', '#FF8A5C', '#A99CFF']


def stars(n=1.0):
    pts = [(150, 170, 3), (260, 110, 2), (840, 150, 3.5), (905, 300, 2), (120, 380, 2), (720, 90, 2), (380, 200, 1.6), (640, 210, 1.4)]
    return ''.join(f'<circle cx="{x}" cy="{y}" r="{r*n}" fill="#F3F0FF" opacity=".75"/>' for x, y, r in pts)


def dot(x, y, c, r=26):
    return f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r*1.9:.0f}" fill="{c}" opacity=".45" filter="url(#soft)"/><circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="{c}"/>'


def one():
    """1 光柱：透視的夜光地圖格線上，一道光柱從光圈升起，團員圍在旁邊"""
    g = '<rect width="1024" height="1024" fill="url(#sky)"/>' + stars()
    # 透視格線（地面）
    hor = 560
    for i in range(-8, 9):
        x2 = 512 + i * 150
        g += f'<line x1="512" y1="{hor}" x2="{x2}" y2="1024" stroke="#5A63C8" stroke-width="3" opacity=".35"/>'
    y = hor
    for k in range(1, 9):
        y = hor + (1024 - hor) * (k / 8) ** 1.8
        g += f'<line x1="0" y1="{y:.0f}" x2="1024" y2="{y:.0f}" stroke="#5A63C8" stroke-width="3" opacity=".35"/>'
    g += f'<rect width="1024" height="{hor+40}" fill="url(#sky)" opacity=".0"/>'
    cy = 760
    g += f'<ellipse cx="512" cy="{cy}" rx="240" ry="70" fill="url(#pool)"/>'
    g += f'<ellipse cx="512" cy="{cy}" rx="240" ry="70" fill="none" stroke="url(#aur)" stroke-width="14"/>'
    g += f'<path d="M462 {cy} L486 120 L538 120 L562 {cy} Z" fill="#B44CFF" opacity=".75" filter="url(#glow)"/>'
    g += f'<path d="M480 {cy} L498 120 L526 120 L544 {cy} Z" fill="url(#beam)"/>'
    for i, a in enumerate([200, 250, 290, 340]):
        g += dot(512 + 240 * math.cos(math.radians(a + 180)), cy + 70 * math.sin(math.radians(a + 180)) * -1, COLS[i], 24)
    return g


def two():
    """2 光之旗：導遊的三角旗，白色旗桿，深色漸層底，最簡潔、小尺寸也清楚"""
    g = '<rect width="1024" height="1024" fill="url(#deep)"/>'
    g += '<circle cx="380" cy="300" r="380" fill="#B44CFF" opacity=".35" filter="url(#glow)"/>'
    g += '<path d="M392 210 L812 360 L392 510 Z" fill="#FF5FD2" opacity=".6" filter="url(#glow)"/>'
    g += '<path d="M392 210 L812 360 L392 510 Q452 360 392 210 Z" fill="url(#warm)"/>'
    g += '<rect x="352" y="180" width="44" height="680" rx="22" fill="#FFFFFF"/>'
    g += '<ellipse cx="374" cy="860" rx="170" ry="38" fill="#FFFFFF" opacity=".25"/>'
    return g


def three():
    """3 集合：俯視，一圈不同顏色的團員朝中心的光點聚集（箭頭軌跡）"""
    g = '<rect width="1024" height="1024" fill="url(#sky)"/>' + stars(.8)
    g += '<circle cx="512" cy="512" r="330" fill="url(#pool)" opacity=".7"/>'
    g += '<circle cx="512" cy="512" r="150" fill="#B44CFF" opacity=".7" filter="url(#glow)"/>'
    g += '<circle cx="512" cy="512" r="110" fill="url(#core)"/>'
    g += '<circle cx="512" cy="512" r="46" fill="#FFFFFF"/>'
    for i in range(8):
        a = math.radians(i * 45 - 90)
        x0, y0 = 512 + 340 * math.cos(a), 512 + 340 * math.sin(a)
        x1, y1 = 512 + 180 * math.cos(a), 512 + 180 * math.sin(a)
        g += f'<line x1="{x0:.0f}" y1="{y0:.0f}" x2="{x1:.0f}" y2="{y1:.0f}" stroke="{COLS[i]}" stroke-width="10" stroke-linecap="round" stroke-dasharray="2 26" opacity=".8"/>'
        g += dot(x0, y0, COLS[i], 34)
    return g


def four():
    """4 晶片（TourChip）：圓角晶片外框與腳位，中間一道光柱與光圈"""
    g = '<rect width="1024" height="1024" fill="url(#sky)"/>'
    g += '<rect x="232" y="232" width="560" height="560" rx="96" fill="#B44CFF" opacity=".45" filter="url(#glow)"/>'
    # 腳位
    for k in range(4):
        p = 330 + k * 120
        for (x, y, w, h) in [(p - 18, 150, 36, 90), (p - 18, 784, 36, 90), (150, p - 18, 90, 36), (784, p - 18, 90, 36)]:
            g += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="url(#aur)"/>'
    g += '<rect x="232" y="232" width="560" height="560" rx="96" fill="#121848" stroke="url(#aur)" stroke-width="24"/>'
    g += '<ellipse cx="512" cy="660" rx="170" ry="46" fill="url(#pool)"/>'
    g += '<ellipse cx="512" cy="660" rx="170" ry="46" fill="none" stroke="url(#aur)" stroke-width="12"/>'
    g += '<path d="M476 660 L494 290 L530 290 L548 660 Z" fill="#B44CFF" opacity=".8" filter="url(#soft)"/>'
    g += '<path d="M486 660 L500 290 L524 290 L538 660 Z" fill="url(#beam)"/>'
    return g


def five():
    """5 呼叫：定位針上方一圈圈的聲波，代表「集合時每支手機都會響」"""
    g = '<rect width="1024" height="1024" fill="url(#sky)"/>' + stars(.8)
    cx, cy = 512, 430
    for i, r in enumerate([200, 290, 380]):
        g += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="url(#aur)" stroke-width="{22 - i*5}" opacity="{.9 - i*.25}"/>'
    pin = f'M{cx} 860 C{cx-80} 720 {cx-170} 640 {cx-170} {cy} A170 170 0 1 1 {cx+170} {cy} C{cx+170} 640 {cx+80} 720 {cx} 860 Z'
    g += f'<path d="{pin}" fill="#FF5FD2" opacity=".55" filter="url(#glow)"/>'
    g += f'<path d="{pin}" fill="url(#flag)"/>'
    g += f'<circle cx="{cx}" cy="{cy}" r="74" fill="#FFFFFF"/>'
    g += f'<circle cx="{cx}" cy="{cy}" r="36" fill="#4FC3F7"/>'
    return g


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">{DEFS}{body}</svg>'


for i, f in enumerate([one, two, three, four, five], 1):
    (OUT / f'{i}.svg').write_text(svg(f()), encoding='utf-8')
print('ok')
