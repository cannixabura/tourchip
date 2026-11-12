# 產生 iOS 各語言的 InfoPlist.strings（App 名稱與權限說明），並登記到 Xcode 專案
# 用法：python3 tool/gen_infoplist.py
import pathlib, re, hashlib

T = {
    'zh-Hans': ('旅行团',
                '旅行团会在你使用 App 时取得位置，算出到集合点的距离与方向；你同意分享后，同一团的人（含领队）会在地图上看到你的位置，可以随时在设置关闭。',
                '扫描领队的入团二维码或团购券。',
                '从相册选一张照片当你的头像。'),
    'ja': ('TourChip',
           'TourChip はアプリの使用中に位置情報を取得し、集合場所までの距離と方向を表示します。共有に同意すると、同じグループの人（リーダーを含む）が地図上であなたの位置を見られます。設定でいつでもオフにできます。',
           'リーダーの参加用QRコードやクーポンをスキャンします。',
           'ライブラリから写真を選んでプロフィール写真にします。'),
    'ko': ('TourChip',
           'TourChip은 앱을 사용하는 동안 위치를 가져와 집합 장소까지의 거리와 방향을 보여 줘요. 공유에 동의하면 같은 그룹의 사람(리더 포함)이 지도에서 내 위치를 볼 수 있어요. 설정에서 언제든 끌 수 있어요.',
           '리더의 참가 QR 코드나 이용권을 스캔해요.',
           '사진 보관함에서 프로필 사진을 골라요.'),
    'ms': ('TourChip',
           'TourChip menggunakan lokasi anda semasa aplikasi digunakan untuk menunjukkan jarak dan arah ke tempat berkumpul. Jika anda bersetuju berkongsi, orang dalam kumpulan anda (termasuk ketua) melihat lokasi anda pada peta. Anda boleh mematikannya dalam Tetapan bila-bila masa.',
           'Imbas kod QR untuk sertai daripada ketua anda atau baucar kumpulan.',
           'Pilih foto daripada pustaka sebagai foto profil anda.'),
    'id': ('TourChip',
           'TourChip memakai lokasimu saat aplikasi digunakan untuk menampilkan jarak dan arah ke titik kumpul. Jika kamu setuju berbagi, orang di grupmu (termasuk pemimpin) melihat lokasimu di peta. Kamu bisa mematikannya di Pengaturan kapan saja.',
           'Pindai kode QR bergabung dari pemimpin atau voucher grup.',
           'Pilih foto dari galeri sebagai foto profilmu.'),
    'vi': ('TourChip',
           'TourChip dùng vị trí khi bạn mở ứng dụng để hiển thị khoảng cách và hướng đến điểm hẹn. Nếu bạn đồng ý chia sẻ, người trong đoàn (kể cả trưởng đoàn) sẽ thấy vị trí của bạn trên bản đồ. Bạn có thể tắt trong Cài đặt bất cứ lúc nào.',
           'Quét mã QR tham gia của trưởng đoàn hoặc phiếu cho đoàn.',
           'Chọn ảnh từ thư viện làm ảnh đại diện.'),
    'th': ('TourChip',
           'TourChip ใช้ตำแหน่งของคุณขณะใช้แอปเพื่อแสดงระยะทางและทิศทางไปยังจุดนัดพบ หากคุณยินยอมแชร์ คนในกลุ่มเดียวกัน (รวมถึงหัวหน้า) จะเห็นตำแหน่งของคุณบนแผนที่ ปิดได้ทุกเมื่อในการตั้งค่า',
           'สแกน QR code เข้าร่วมของหัวหน้าหรือคูปองกลุ่ม',
           'เลือกรูปจากคลังภาพเป็นรูปโปรไฟล์'),
}

# 葡萄牙、西班牙、印地：譯文在 tool/i18n/infoplist_extra.json
import json as _json
for _l, _v in _json.load(open('tool/i18n/infoplist_extra.json', encoding='utf-8')).items():
    T[_l] = ('TourChip', _v['loc'], _v['cam'], _v['photo'])

def esc(s): return s.replace('\\', '\\\\').replace('"', '\\"')

root = pathlib.Path('ios/Runner')
for lang, (name, loc, cam, photo) in T.items():
    d = root / f'{lang}.lproj'
    d.mkdir(exist_ok=True)
    if (d / 'InfoPlist.strings').exists():
        continue  # 已存在的檔案有手動改過的名稱與麥克風說明，不要覆寫
    (d / 'InfoPlist.strings').write_text(
        '/* App name and permission descriptions (Info.plist translations) */\n'
        f'"CFBundleDisplayName" = "{esc(name)}";\n'
        f'"NSLocationWhenInUseUsageDescription" = "{esc(loc)}";\n'
        f'"NSCameraUsageDescription" = "{esc(cam)}";\n'
        f'"NSPhotoLibraryUsageDescription" = "{esc(photo)}";\n', encoding='utf-8')

# Xcode 專案：variant group 加入新的語言、knownRegions 加入語言
p = pathlib.Path('ios/Runner.xcodeproj/project.pbxproj')
s = p.read_text(encoding='utf-8')
for lang in T:
    if f'path = "{lang}.lproj/InfoPlist.strings"' in s or f'path = {lang}.lproj/InfoPlist.strings' in s:
        continue
    fid = hashlib.md5(('tourchip-infoplist-' + lang).encode()).hexdigest()[:24].upper()
    q = f'"{lang}"' if '-' in lang else lang
    ref = f'\t\t{fid} /* {lang} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = text.plist.strings; name = {q}; path = "{lang}.lproj/InfoPlist.strings"; sourceTree = "<group>"; }};\n'
    s = s.replace('/* End PBXFileReference section */', ref + '/* End PBXFileReference section */', 1)
    s = re.sub(r'(BE40AAA4EEF6B392B4472F05 /\* InfoPlist.strings \*/ = \{\s*isa = PBXVariantGroup;\s*children = \(\n)', lambda m: m.group(1) + f'\t\t\t\t{fid} /* {lang} */,\n', s, count=1)
    s = re.sub(r'(knownRegions = \(\n)', lambda m: m.group(1) + f'\t\t\t\t{q},\n', s, count=1)
p.write_text(s, encoding='utf-8')

# Info.plist：CFBundleLocalizations 列出全部語言（App Store 顯示支援的語言）
ip = root / 'Info.plist'
x = ip.read_text(encoding='utf-8')
langs = ['en', 'zh-Hant', 'zh-Hans', 'ja', 'ko', 'ms', 'id', 'vi', 'th', 'pt', 'es', 'hi']
arr = '<key>CFBundleLocalizations</key>\n\t<array>\n' + ''.join(f'\t\t<string>{l}</string>\n' for l in langs) + '\t</array>'
x = re.sub(r'<key>CFBundleLocalizations</key>\s*<array>.*?</array>', arr, x, count=1, flags=re.S)
ip.write_text(x, encoding='utf-8')
print('ok')
