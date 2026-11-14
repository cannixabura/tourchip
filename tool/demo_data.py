"""商店截圖模式的範例資料：12 種語言 × 8 個畫面的 demo.json，加上大頭貼與菜單圖。
用法：python3 tool/demo_data.py <輸出資料夾>
  <輸出資料夾>/<lang>/<1-8>.json   → 截圖時複製到 App 的 Documents/demo.json
  hosting/img/demo/<lang>/<a-d>.png → 大頭貼（部署到官網，App 用網址讀）
"""
import json, os, subprocess, sys

OUT = sys.argv[1]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
SITE = 'https://tourchip.web.app/img/demo'

# 每種語言：團名、集合點、領隊與三位團員、氣泡、私訊、景點
TOKYO = dict(tz='Asia/Tokyo', meet=(35.71110, 139.79640), me=(35.71240, 139.79560),
             spot=dict(lat=35.71475, lng=139.79665), menu='menu_ja.jpg')
TAIPEI = dict(tz='Asia/Taipei', meet=(25.04210, 121.50680), me=(25.04330, 121.50590),
              spot=dict(lat=25.03720, lng=121.49990), menu='menu_tw.jpg')
L = {
    'zh-Hant': dict(TOKYO, group='東京三日遊', place='雷門', spotName='淺草寺', names=['阿導', '小美', '阿明', '佳佳'],
                    bubbles=['買到人形燒了', '在找廁所'], chat=['我在雷門大燈籠下面', '馬上到！']),
    'zh-Hans': dict(TOKYO, group='东京三日游', place='雷门', spotName='浅草寺', names=['阿导', '小美', '阿明', '佳佳'],
                    bubbles=['买到人形烧了', '在找厕所'], chat=['我在雷门大灯笼下面', '马上到！']),
    'en': dict(TOKYO, group='Tokyo 3-Day Trip', place='Kaminarimon Gate', spotName='Senso-ji', names=['Alex', 'Mia', 'Ben', 'Chloe'],
               bubbles=['Got ningyo-yaki!', 'Finding a restroom'], chat=["I'm under the big lantern", 'On my way!']),
    'ja': dict(TAIPEI, group='台北3日間ツアー', place='西門紅楼', spotName='龍山寺', names=['ケン', 'ミキ', 'ユウタ', 'ハナ'],
               bubbles=['タピオカ買えた！', 'トイレ探し中'], chat=['紅楼の入口にいます', 'すぐ行きます！']),
    'ko': dict(TOKYO, group='도쿄 3일 여행', place='가미나리몬', spotName='센소지', names=['민준', '지아', '서연', '도윤'],
               bubbles=['닌교야키 샀어요!', '화장실 찾는 중'], chat=['큰 등불 아래에 있어요', '금방 갈게요!']),
    'ms': dict(TOKYO, group='Lawatan Tokyo 3 Hari', place='Pintu Kaminarimon', spotName='Senso-ji', names=['Amir', 'Aisyah', 'Farid', 'Nurul'],
               bubbles=['Dah beli ningyo-yaki!', 'Cari tandas'], chat=['Saya di bawah tanglung besar', 'Saya datang!']),
    'id': dict(TOKYO, group='Tur Tokyo 3 Hari', place='Gerbang Kaminarimon', spotName='Senso-ji', names=['Budi', 'Sari', 'Dimas', 'Putri'],
               bubbles=['Dapat ningyo-yaki!', 'Cari toilet'], chat=['Aku di bawah lampion besar', 'Segera ke sana!']),
    'vi': dict(TOKYO, group='Tokyo 3 ngày', place='Cổng Kaminarimon', spotName='Chùa Senso-ji', names=['Minh', 'Lan', 'Huy', 'Mai'],
               bubbles=['Mua được bánh rồi!', 'Đang tìm nhà vệ sinh'], chat=['Mình ở dưới lồng đèn lớn', 'Tới liền!']),
    'th': dict(TOKYO, group='ทัวร์โตเกียว 3 วัน', place='ประตูคามินาริมง', spotName='วัดเซ็นโซจิ', names=['ต้น', 'มายด์', 'บีม', 'ฝน'],
               bubbles=['ได้นินเงียวยากิแล้ว', 'กำลังหาห้องน้ำ'], chat=['อยู่ใต้โคมใหญ่นะ', 'กำลังไป!']),
    'pt': dict(TOKYO, group='Tóquio em 3 dias', place='Portão Kaminarimon', spotName='Senso-ji', names=['Rafael', 'Ana', 'Lucas', 'Júlia'],
               bubbles=['Comprei ningyo-yaki!', 'Procurando banheiro'], chat=['Estou embaixo da lanterna', 'Já estou indo!']),
    'es': dict(TOKYO, group='Tokio en 3 días', place='Puerta Kaminarimon', spotName='Senso-ji', names=['Diego', 'Sofía', 'Mateo', 'Valentina'],
               bubbles=['¡Compré ningyo-yaki!', 'Buscando un baño'], chat=['Estoy bajo la gran linterna', '¡Ya voy!']),
    'hi': dict(TOKYO, group='टोक्यो 3 दिन', place='कामिनारिमोन गेट', spotName='सेंसो-जी', names=['राहुल', 'प्रिया', 'अमन', 'नेहा'],
               bubbles=['निंग्यो-याकी मिल गई!', 'वॉशरूम ढूँढ रही हूँ'], chat=['मैं बड़ी लालटेन के नीचे हूँ', 'बस आ रहा हूँ!']),
}
FONT = {'zh-Hant': 'PingFang TC', 'zh-Hans': 'PingFang SC', 'ja': 'Hiragino Sans', 'ko': 'Apple SD Gothic Neo',
        'th': 'Thonburi', 'hi': 'Kohinoor Devanagari'}
GRAD = [('#ff8a3d', '#ff4fb4'), ('#b44cff', '#5b8cff'), ('#2fd3c6', '#3d7bff'), ('#ffd166', '#ff7a59')]


HI_INITIAL = {'राहुल': 'रा', 'प्रिया': 'प्रि', 'अमन': 'अ', 'नेहा': 'ने'}


def first(name):
    if name in HI_INITIAL:
        return HI_INITIAL[name]
    return name[:2] if name and 'ऀ' <= name[0] <= '๿' else name[:1]


def avatars(lang, names):
    d = f'{ROOT}/hosting/img/demo/{lang}'
    os.makedirs(d, exist_ok=True)
    for k, (n, (a, b)) in enumerate(zip(names, GRAD)):
        html = f'''<html><head><meta charset="utf-8"><style>body{{margin:0;width:256px;height:256px;background:linear-gradient(135deg,{a},{b});
display:flex;align-items:center;justify-content:center;font:700 128px "{FONT.get(lang, 'Helvetica Neue')}",sans-serif;color:#fff}}</style></head>
<body>{first(n)}</body></html>'''
        if os.path.exists(f'{d}/{"abcd"[k]}.png'):
            continue
        tmp = f'{OUT}/_av.html'
        open(tmp, 'w', encoding='utf-8').write(html)
        subprocess.run([CH, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                        '--window-size=256,256', f'--screenshot={d}/{"abcd"[k]}.png', f'file://{tmp}'], capture_output=True)


def group(lang, c, shot):
    n = c['names']
    av = [f'{SITE}/{lang}/{x}.png' for x in 'abcd']
    staff = shot in (5, 6)
    me = 'L' if staff else 'A'  # 截圖 5、6 是領隊，其他是團員小美
    uid = {'L': 'u_leader', 'A': 'u_mia', 'B': 'u_ben', 'C': 'u_chloe'}
    uid[me] = '$ME'
    who = [('L', 0, 'host'), ('A', 1, 'member'), ('B', 2, 'member'), ('C', 3, 'member')]
    mlat, mlng = c['meet']
    off = {'L': (0.00030, -0.00020), 'A': c['me'], 'B': (0.00150, 0.00110), 'C': (0.00280, -0.00190)}
    people = []
    for key, i, role in who:
        if key == me:
            continue  # 自己由地圖上的「我」顯示
        lat, lng = off[key] if key == 'A' else (mlat + off[key][0], mlng + off[key][1])
        bubble = c['bubbles'][0] if key == 'A' else (c['bubbles'][1] if key == 'C' else '')
        people.append(dict(uid=uid[key], no=i, name=n[i], avatar=av[i], role=role, bubble=bubble, lat=lat, lng=lng, atIn=-20, online=True))
    names = {uid[k]: dict(no=i, name=n[i], avatar=av[i], role=r) for k, i, r in who}
    members = [dict(uid=uid[k], no=i, name=n[i], avatar=av[i]) for k, i, r in who if r == 'member']
    g = dict(code='DEMO2026', name=c['group'], color='violet', role='host' if staff else 'member', hostName=n[0], tz=c['tz'],
             startDate='2026-11-14', endDate='2026-11-16', days=3, allowedDays=3, limit=20, count=4,
             myNo=0 if staff else 1, staff=[dict(uid=uid['L'], no=0, name=n[0], role='host', avatar=av[0])],
             members=members, names=names, people=people, share=dict(consent=True, on=True),
             myBubble=c['bubbles'][0] if me == 'A' else '',
             qr='https://tourchip.web.app/g/DEMO2026K7', invite='48217365', endsAtIn=2 * 86400 + 30000)
    call = dict(id='c1', atIn=1800, tz=c['tz'], place=c['place'], lat=mlat, lng=mlng)
    if shot == 1:
        g['call'] = dict(call, mine='ack')
    elif shot == 2:
        g['call'] = dict(call)
    elif shot == 4:
        g['messages'] = [dict(id='m1', **{'from': uid['C']}, to='$ME', text=c['chat'][0], atIn=-120, mine=False),
                         dict(id='m2', **{'from': '$ME'}, to=uid['C'], text=c['chat'][1], atIn=-60, mine=True)]
    elif shot == 6:
        g['call'] = dict(call, mine=None)
        rows = [dict(uid=uid[k], no=i, name=n[i], avatar=av[i], state=s) for (k, i, r), s in zip(who[1:], ['ack', 'ack', 'seen'])]
        g['callRoster'] = dict(rows=rows, acked=2, total=3)
    return g


for lang, c in L.items():
    avatars(lang, c['names'])
    d = f'{OUT}/{lang}'
    os.makedirs(d, exist_ok=True)
    for shot in range(1, 9):
        cfg = dict(lang=lang, shot=shot, group=group(lang, c, shot),
                   profile=dict(name=c['names'][0 if shot in (5, 6) else 1],
                                avatar=f'{SITE}/{lang}/{"a" if shot in (5, 6) else "b"}.png'))
        if shot == 4:
            cfg['chatWith'] = 'u_chloe'
        if shot == 7:
            cfg['aiyaImage'] = c['menu']
        if shot == 8:
            cfg['spot'] = dict(place=c['spotName'], **c['spot'])
        json.dump(cfg, open(f'{d}/{shot}.json', 'w', encoding='utf-8'), ensure_ascii=False)
    print(lang, 'ok')
