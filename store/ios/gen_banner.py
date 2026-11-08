# -*- coding: utf-8 -*-
# App Store 產品頁面「標題」與「搜尋結果」素材：夜光 3D 城市、集合光柱、團員大頭貼與氣泡（不含文字，所有語言共用）
# 用法：python3 store/ios/gen_banner.py → header.svg（3840×1646）、search.svg（3840×2560），再用 Chrome 轉 PNG
import math, random, pathlib

OUT = pathlib.Path(__file__).parent
COLS = ['#FFB547', '#4DE3A0', '#FF5FD2', '#5AB8FF', '#FFD54A', '#A99CFF', '#FF8A5C']


def scene(W, H, seed=7):
    rnd = random.Random(seed)
    hor = H * 0.46            # 地平線
    cx, gy = W * 0.5, H * 0.78  # 光柱底部
    s = H / 1646              # 比例
    d = f'''<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#070B1F"/><stop offset=".55" stop-color="#151B52"/><stop offset="1" stop-color="#241A55"/></linearGradient>
<radialGradient id="halo" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#B44CFF" stop-opacity=".55"/><stop offset="1" stop-color="#B44CFF" stop-opacity="0"/></radialGradient>
<linearGradient id="beam" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".3" stop-color="#BFEFFF"/><stop offset=".75" stop-color="#4FC3F7" stop-opacity=".8"/><stop offset="1" stop-color="#4FC3F7" stop-opacity="0"/></linearGradient>
<linearGradient id="aur" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#B44CFF"/><stop offset="1" stop-color="#4FC3F7"/></linearGradient>
<radialGradient id="pool" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#8FDCFF" stop-opacity=".7"/><stop offset="1" stop-color="#4FC3F7" stop-opacity="0"/></radialGradient>
<linearGradient id="bld" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2B3380"/><stop offset="1" stop-color="#121848"/></linearGradient>
<linearGradient id="bldS" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1D2463"/><stop offset="1" stop-color="#0C1036"/></linearGradient>
<filter id="glow" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="{40*s:.0f}"/></filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{14*s:.0f}"/></filter>
</defs>'''
    g = f'<rect width="{W}" height="{H}" fill="url(#sky)"/>'
    for _ in range(int(W / 25)):
        g += f'<circle cx="{rnd.uniform(0, W):.0f}" cy="{rnd.uniform(0, hor*0.9):.0f}" r="{rnd.uniform(1.5, 4)*s:.1f}" fill="#F3F0FF" opacity="{rnd.uniform(.3, .9):.2f}"/>'
    # 地面格線（透視）
    for i in range(-30, 31):
        g += f'<line x1="{cx}" y1="{hor}" x2="{cx + i*W*0.06:.0f}" y2="{H}" stroke="#5A63C8" stroke-width="{2.5*s:.1f}" opacity=".28"/>'
    for k in range(1, 14):
        y = hor + (H - hor) * (k / 13) ** 1.9
        g += f'<line x1="0" y1="{y:.0f}" x2="{W}" y2="{y:.0f}" stroke="#5A63C8" stroke-width="{2.5*s:.1f}" opacity=".28"/>'
    # 建築：遠到近，簡單的立面＋側面，窗戶亮點
    blds = []
    for row in range(4):
        depth = row / 3                      # 0 遠 → 1 近
        base = hor + (gy - hor) * (0.08 + depth * 0.55)
        scale = 0.35 + depth * 0.9
        x = -rnd.uniform(0, 200)
        while x < W:
            w = rnd.uniform(110, 230) * scale * s
            h = rnd.uniform(180, 620) * scale * s
            gap = rnd.uniform(20, 90) * scale * s
            if abs(x + w / 2 - cx) > W * 0.09 + row * 40 * s:  # 中間留給光柱
                blds.append((row, x, base, w, h, scale))
            x += w + gap
    for row, x, base, w, h, scale in sorted(blds, key=lambda b: b[0]):
        side = w * 0.28 * (1 if x + w / 2 < cx else -1)
        top = base - h
        sx = x + w if side > 0 else x
        g += f'<path d="M{sx:.0f} {base:.0f} L{sx+side:.0f} {base - 12*scale*s:.0f} L{sx+side:.0f} {top - 12*scale*s:.0f} L{sx:.0f} {top:.0f} Z" fill="url(#bldS)"/>'
        g += f'<rect x="{x:.0f}" y="{top:.0f}" width="{w:.0f}" height="{h:.0f}" fill="url(#bld)" stroke="#4A54B8" stroke-opacity=".35" stroke-width="{2*s:.1f}"/>'
        cols_n, rows_n = max(2, int(w / (34 * scale * s))), max(3, int(h / (40 * scale * s)))
        for c in range(cols_n):
            for r in range(rows_n):
                if rnd.random() < 0.22:
                    wx = x + (c + 0.5) * w / cols_n
                    wy = top + (r + 0.6) * h / rows_n
                    col = rnd.choice(['#FFD27A', '#BFEFFF', '#FFB547', '#A99CFF'])
                    g += f'<rect x="{wx - 6*scale*s:.0f}" y="{wy - 7*scale*s:.0f}" width="{12*scale*s:.0f}" height="{14*scale*s:.0f}" fill="{col}" opacity="{rnd.uniform(.5, .95):.2f}"/>'
    # 光柱
    rx, ry = 330 * s, 80 * s
    g += f'<ellipse cx="{cx}" cy="{gy}" rx="{rx*2.2:.0f}" ry="{ry*2.6:.0f}" fill="url(#halo)"/>'
    g += f'<ellipse cx="{cx}" cy="{gy}" rx="{rx:.0f}" ry="{ry:.0f}" fill="url(#pool)"/>'
    g += f'<ellipse cx="{cx}" cy="{gy}" rx="{rx:.0f}" ry="{ry:.0f}" fill="none" stroke="url(#aur)" stroke-width="{16*s:.0f}"/>'
    bw = 58 * s
    g += f'<path d="M{cx-bw*1.7:.0f} {gy} L{cx-bw*0.9:.0f} 0 L{cx+bw*0.9:.0f} 0 L{cx+bw*1.7:.0f} {gy} Z" fill="#B44CFF" opacity=".7" filter="url(#glow)"/>'
    g += f'<path d="M{cx-bw:.0f} {gy} L{cx-bw*0.45:.0f} 0 L{cx+bw*0.45:.0f} 0 L{cx+bw:.0f} {gy} Z" fill="url(#beam)"/>'
    # 團員：大頭貼（彩色圓）＋白色氣泡（不放字，用三個點）
    spots = [(-0.30, 0.93, 1.0, True), (-0.17, 0.86, 0.85, False), (0.15, 0.88, 0.9, True), (0.29, 0.95, 1.05, False),
             (-0.40, 0.99, 1.15, False), (0.40, 1.0, 1.15, True), (-0.08, 0.97, 0.95, False)]
    for i, (fx, fy, k, bubble) in enumerate(spots):
        x, y, r = cx + fx * W, gy * fy, 46 * s * k
        c = COLS[i % len(COLS)]
        g += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r*1.9:.0f}" fill="{c}" opacity=".45" filter="url(#soft)"/>'
        g += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r:.0f}" fill="{c}" stroke="#FFFFFF" stroke-width="{7*s*k:.0f}"/>'
        g += f'<circle cx="{x:.0f}" cy="{y - r*0.2:.0f}" r="{r*0.32:.0f}" fill="#FFFFFF" opacity=".85"/>'
        g += f'<path d="M{x - r*0.55:.0f} {y + r*0.62:.0f} Q{x:.0f} {y + r*0.05:.0f} {x + r*0.55:.0f} {y + r*0.62:.0f} Z" fill="#FFFFFF" opacity=".85"/>'
        if bubble:
            bw2, bh2 = r * 2.6, r * 1.15
            bx, by = x - bw2 / 2, y - r - bh2 - 26 * s * k
            g += f'<rect x="{bx:.0f}" y="{by:.0f}" width="{bw2:.0f}" height="{bh2:.0f}" rx="{bh2/2:.0f}" fill="#FFFFFF" opacity=".95"/>'
            g += f'<path d="M{x - 14*s*k:.0f} {by + bh2 - 2:.0f} L{x:.0f} {by + bh2 + 20*s*k:.0f} L{x + 14*s*k:.0f} {by + bh2 - 2:.0f} Z" fill="#FFFFFF" opacity=".95"/>'
            for j in (-1, 0, 1):
                g += f'<circle cx="{x + j*r*0.6:.0f}" cy="{by + bh2/2:.0f}" r="{r*0.17:.0f}" fill="#6A5BD8"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{d}{g}</svg>'


(OUT / 'header.svg').write_text(scene(3840, 1646), encoding='utf-8')
(OUT / 'search.svg').write_text(scene(3840, 2560, seed=11), encoding='utf-8')
print('ok')
