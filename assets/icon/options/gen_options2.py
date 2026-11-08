# -*- coding: utf-8 -*-
# 第二輪圖示提案：以目前的圖示為底，換上 2 號的黃色三角旗，並加強「導遊舉旗帶團」的意象
# 用法：python3 assets/icon/options/gen_options2.py → A.svg … D.svg
import math, pathlib

W = 1024
OUT = pathlib.Path(__file__).parent
DEFS = '''<defs>
<radialGradient id="sky" cx="50%" cy="62%" r="75%"><stop offset="0" stop-color="#2A2F66"/><stop offset=".55" stop-color="#121848"/><stop offset="1" stop-color="#070B1F"/></radialGradient>
<linearGradient id="beam" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".35" stop-color="#BFEFFF"/><stop offset=".75" stop-color="#4FC3F7" stop-opacity=".85"/><stop offset="1" stop-color="#4FC3F7" stop-opacity="0"/></linearGradient>
<linearGradient id="aur" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#B44CFF"/><stop offset="1" stop-color="#4FC3F7"/></linearGradient>
<linearGradient id="warm" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFD54A"/><stop offset="1" stop-color="#FF8A3D"/></linearGradient>
<linearGradient id="guide" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#CFE9FF"/></linearGradient>
<radialGradient id="pool" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#8FDCFF" stop-opacity=".55"/><stop offset="1" stop-color="#4FC3F7" stop-opacity="0"/></radialGradient>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="18"/></filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="7"/></filter>
</defs>'''
COLS = ['#FFB547', '#4DE3A0', '#FF5FD2', '#5AB8FF', '#FFD54A', '#F3F0FF', '#FF8A5C', '#A99CFF']


def bg():
    pts = [(150, 170, 3), (260, 110, 2), (840, 150, 3.5), (905, 300, 2), (120, 380, 2), (720, 90, 2), (380, 200, 1.6), (930, 520, 1.8), (90, 560, 1.6), (640, 210, 1.4)]
    return f'<rect width="{W}" height="{W}" fill="url(#sky)"/>' + ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#F3F0FF" opacity=".8"/>' for x, y, r in pts)


def dot(x, y, c, r=24):
    return f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r*1.9:.0f}" fill="{c}" opacity=".45" filter="url(#soft)"/><circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="{c}"/>'


def ring(cx, cy, rx, ry, angles, r=24):
    out = (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#pool)"/>'
           f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" stroke="url(#aur)" stroke-width="26" opacity=".6" filter="url(#soft)"/>'
           f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" stroke="url(#aur)" stroke-width="12"/>')
    for i, a in enumerate(angles):
        out += dot(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a)), COLS[i % len(COLS)], r)
    return out


def pennant(x, y, w, h, glow=True):
    """黃色三角旗，旗桿在 x，上緣在 y"""
    p = f'M{x} {y} L{x+w} {y+h/2} L{x} {y+h} Q{x+w*0.15} {y+h/2} {x} {y} Z'
    return (f'<path d="{p}" fill="#FF8A3D" opacity=".6" filter="url(#glow)"/>' if glow else '') + f'<path d="{p}" fill="url(#warm)"/>'


def A():
    """A 目前的圖示＋黃色三角旗：光柱就是旗桿"""
    cy = 740
    return (ring(512, cy, 250, 66, [180, 232, 308, 0, 140, 40])
            + f'<path d="M468 {cy} L490 170 L534 170 L556 {cy} Z" fill="#B44CFF" opacity=".7" filter="url(#glow)"/>'
            + f'<path d="M482 {cy} L498 170 L526 170 L542 {cy} Z" fill="url(#beam)"/>'
            + pennant(524, 196, 280, 190))


def guide(x, y, s=1.0, pole_top=150):
    """導遊：頭、身體，右手高舉旗桿（白色剪影）"""
    hr = 50 * s
    body = (f'M{x-86*s:.0f} {y+210*s:.0f} Q{x-86*s:.0f} {y+70*s:.0f} {x:.0f} {y+70*s:.0f} '
            f'Q{x+86*s:.0f} {y+70*s:.0f} {x+86*s:.0f} {y+210*s:.0f} Z')
    arm = f'M{x+50*s:.0f} {y+100*s:.0f} L{x+118*s:.0f} {y-20*s:.0f}'
    px = x + 124 * s
    return (f'<g filter="url(#soft)" opacity=".55"><circle cx="{x}" cy="{y}" r="{hr*1.2:.0f}" fill="#BFEFFF"/><path d="{body}" fill="#BFEFFF"/></g>'
            f'<path d="{arm}" stroke="url(#guide)" stroke-width="{34*s:.0f}" stroke-linecap="round"/>'
            f'<rect x="{px-11*s:.0f}" y="{pole_top}" width="{22*s:.0f}" height="{y+30*s-pole_top:.0f}" rx="{11*s:.0f}" fill="#FFFFFF"/>'
            f'<circle cx="{x}" cy="{y}" r="{hr:.0f}" fill="url(#guide)"/><path d="{body}" fill="url(#guide)"/>'
            + pennant(px + 10 * s, pole_top + 6, 230 * s, 160 * s), px)


def B():
    """B 導遊舉旗：中間的導遊高舉黃旗，團員圍成一圈"""
    cy = 780
    g, _ = guide(470, 470, 1.15, pole_top=150)
    return ring(512, cy, 290, 74, [180, 220, 270, 320, 0, 140, 40], 22) + g


def C():
    """C 帶隊前進：導遊在前舉旗，後面一排團員跟著，朝光柱前進"""
    out = f'<ellipse cx="770" cy="800" rx="150" ry="42" fill="url(#pool)"/><ellipse cx="770" cy="800" rx="150" ry="42" fill="none" stroke="url(#aur)" stroke-width="10"/>'
    out += '<path d="M752 800 L762 330 L778 330 L788 800 Z" fill="url(#beam)" opacity=".9"/>'
    g, px = guide(470, 520, 0.95, pole_top=210)
    # 跟隨的團員（由遠到近）
    for i, (x, y, r) in enumerate([(330, 640, 26), (250, 700, 30), (170, 770, 34), (300, 800, 30), (120, 860, 36)]):
        out += dot(x, y, COLS[i], r)
    out += '<path d="M150 900 Q330 700 560 760" fill="none" stroke="url(#aur)" stroke-width="10" stroke-dasharray="4 30" stroke-linecap="round" opacity=".8"/>'
    return out + g


def D():
    """D 旗子立在集合光圈中央：旗桿取代光柱，團員圍繞"""
    cy = 760
    return (ring(512, cy, 260, 68, [180, 232, 308, 0, 140, 40])
            + f'<path d="M490 {cy} L496 150 L528 150 L534 {cy} Z" fill="#4FC3F7" opacity=".6" filter="url(#glow)"/>'
            + f'<rect x="494" y="150" width="36" height="{cy-150}" rx="18" fill="#FFFFFF"/>'
            + pennant(526, 160, 330, 230))


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">{DEFS}{body}</svg>'


for n, f in [('A', A), ('B', B), ('C', C), ('D', D)]:
    (OUT / f'{n}.svg').write_text(svg(bg() + f()), encoding='utf-8')
print('ok')
