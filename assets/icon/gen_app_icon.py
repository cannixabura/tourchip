# -*- coding: utf-8 -*-
# 正式 App 圖示：C 款「帶隊前進」，導遊與黃旗等比例放大（2026-11-09）
# 用法：python3 assets/icon/gen_app_icon.py → app_icon.svg、app_icon_foreground.svg、app_icon_background.svg
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent / 'options'))
import gen_options2 as g  # noqa: E402  （匯入時會順便重產 A–D 提案，不影響）

OUT = pathlib.Path(__file__).parent
GUIDE_SCALE = 1.2   # 原本 0.95


def body():
    out = '<ellipse cx="770" cy="800" rx="150" ry="42" fill="url(#pool)"/><ellipse cx="770" cy="800" rx="150" ry="42" fill="none" stroke="url(#aur)" stroke-width="10"/>'
    out += '<path d="M752 800 L762 330 L778 330 L788 800 Z" fill="url(#beam)" opacity=".9"/>'
    s = GUIDE_SCALE
    y = 720 - 210 * s                       # 身體底部維持在 720
    pole_top = y + 30 * s - 356 * s         # 旗桿長度跟著等比例
    guide, _ = g.guide(460, round(y), s, pole_top=round(pole_top))
    for i, (x, yy, r) in enumerate([(330, 640, 26), (250, 700, 30), (170, 770, 34), (300, 800, 30), (120, 860, 36)]):
        out += g.dot(x, yy, g.COLS[i], r)
    out += '<path d="M150 900 Q330 700 560 760" fill="none" stroke="url(#aur)" stroke-width="10" stroke-dasharray="4 30" stroke-linecap="round" opacity=".8"/>'
    return out + guide


FG = 0.68  # Android 自適應圖示前景縮到安全區
o = g.W * (1 - FG) / 2
(OUT / 'app_icon.svg').write_text(g.svg(g.bg() + body()), encoding='utf-8')
(OUT / 'app_icon_foreground.svg').write_text(g.svg(f'<g transform="translate({o} {o}) scale({FG})">{body()}</g>'), encoding='utf-8')
(OUT / 'app_icon_background.svg').write_text(g.svg(g.bg()), encoding='utf-8')
print('ok')
