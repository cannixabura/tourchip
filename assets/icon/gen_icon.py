# -*- coding: utf-8 -*-
import math
W=1024
DEFS='''<defs>
<radialGradient id="sky" cx="50%" cy="62%" r="75%"><stop offset="0" stop-color="#2A2F66"/><stop offset=".55" stop-color="#121848"/><stop offset="1" stop-color="#070B1F"/></radialGradient>
<linearGradient id="beam" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".35" stop-color="#BFEFFF"/><stop offset=".75" stop-color="#4FC3F7" stop-opacity=".85"/><stop offset="1" stop-color="#4FC3F7" stop-opacity="0"/></linearGradient>
<linearGradient id="aur" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#B44CFF"/><stop offset="1" stop-color="#4FC3F7"/></linearGradient>
<linearGradient id="flag" x1="0" y1="0" x2="1" y2=".4"><stop offset="0" stop-color="#FF5FD2"/><stop offset="1" stop-color="#B44CFF"/></linearGradient>
<radialGradient id="pool" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#8FDcff" stop-opacity=".55"/><stop offset="1" stop-color="#4FC3F7" stop-opacity="0"/></radialGradient>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="18"/></filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="7"/></filter>
</defs>'''
def stars():
    pts=[(150,170,3),(260,110,2),(840,150,3.5),(905,300,2),(120,380,2),(720,90,2),(380,200,1.6),(930,520,1.8),(90,560,1.6),(640,210,1.4)]
    return ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#F3F0FF" opacity=".8"/>' for x,y,r in pts)
def bg(): return f'<rect width="{W}" height="{W}" fill="url(#sky)"/>'+stars()
def people(cx,cy,rx,ry,angles,r=24):
    cols=['#FFB547','#4DE3A0','#FF5FD2','#5AB8FF','#FFD54A','#F3F0FF']
    out=''
    for i,a in enumerate(angles):
        x=cx+rx*math.cos(math.radians(a)); y=cy+ry*math.sin(math.radians(a))
        c=cols[i%len(cols)]
        out+=f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r*1.9:.0f}" fill="{c}" opacity=".45" filter="url(#soft)"/><circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="{c}"/>'
    return out
def A():  # 光柱＋光之旗＋圍圈的團員
    cy=740
    return (f'<ellipse cx="512" cy="{cy}" rx="250" ry="66" fill="url(#pool)"/>'
     f'<ellipse cx="512" cy="{cy}" rx="250" ry="66" fill="none" stroke="url(#aur)" stroke-width="26" opacity=".6" filter="url(#soft)"/>'
     f'<ellipse cx="512" cy="{cy}" rx="250" ry="66" fill="none" stroke="url(#aur)" stroke-width="12"/>'
     f'<path d="M468 {cy} L490 170 L534 170 L556 {cy} Z" fill="#B44CFF" opacity=".7" filter="url(#glow)"/>'
     f'<path d="M482 {cy} L498 170 L526 170 L542 {cy} Z" fill="url(#beam)"/>'
     '<path d="M522 214 L782 292 L522 370 Q560 292 522 214 Z" fill="url(#flag)" opacity=".55" filter="url(#soft)"/>'
     '<path d="M522 214 L782 292 L522 370 Q560 292 522 214 Z" fill="url(#flag)"/>'
     + people(512,cy,250,66,[180,232,308,0,140,40]))
def B():  # 定位針形狀的旗子，下方光圈
    return ('<ellipse cx="512" cy="800" rx="230" ry="58" fill="url(#pool)"/>'
     '<ellipse cx="512" cy="800" rx="230" ry="58" fill="none" stroke="url(#aur)" stroke-width="12"/>'
     '<path d="M512 790 C430 640 300 560 300 410 A212 212 0 1 1 724 410 C724 560 594 640 512 790 Z" fill="url(#aur)" opacity=".6" filter="url(#glow)"/>'
     '<path d="M512 790 C430 640 300 560 300 410 A212 212 0 1 1 724 410 C724 560 594 640 512 790 Z" fill="url(#aur)"/>'
     '<path d="M450 300 L450 520" stroke="#FFFFFF" stroke-width="22" stroke-linecap="round"/>'
     '<path d="M462 300 L620 350 L462 400 Z" fill="#FFFFFF"/>'
     + people(512,800,230,58,[160,200,340,20],r=22))
def C():  # 一圈團員朝中心的光柱聚集（俯視）
    out='<circle cx="512" cy="512" r="300" fill="url(#pool)"/>'
    out+='<circle cx="512" cy="512" r="300" fill="none" stroke="url(#aur)" stroke-width="12" stroke-dasharray="4 38" stroke-linecap="round"/>'
    out+='<circle cx="512" cy="512" r="96" fill="#B44CFF" opacity=".75" filter="url(#glow)"/><circle cx="512" cy="512" r="70" fill="#FFFFFF"/><circle cx="512" cy="512" r="40" fill="#4FC3F7"/>'
    cols=['#FFB547','#4DE3A0','#FF5FD2','#5AB8FF','#FFD54A','#F3F0FF','#FF8A5C','#A99CFF']
    for i in range(8):
        a=math.radians(i*45-90); x=512+210*math.cos(a); y=512+210*math.sin(a)
        out+=f'<circle cx="{x:.0f}" cy="{y:.0f}" r="50" fill="{cols[i]}" opacity=".4" filter="url(#soft)"/><circle cx="{x:.0f}" cy="{y:.0f}" r="30" fill="{cols[i]}"/>'
    return out
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">{DEFS}{body}</svg>'
for n,f in [('A',A),('B',B),('C',C)]:
    open(f'{n}.svg','w',encoding='utf-8').write(svg(bg()+f()))
    # Android 自適應圖示：前景縮到中間 62%（安全區），背景另存
    s=1.0; o=W*(1-s)/2
    open(f'{n}_fg.svg','w',encoding='utf-8').write(svg(f'<g transform="translate({o} {o}) scale({s})">{f()}</g>'))
open('bg.svg','w',encoding='utf-8').write(svg(bg()))
