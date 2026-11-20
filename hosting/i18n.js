// 官網頁面的多語言：依瀏覽器語言顯示（繁中、簡中、英、日、韓、馬來、印尼、越南、泰、葡萄牙、西班牙、印地、法、德、義大利、捷克、波蘭、烏克蘭），其他語言用英文。
// 頁面上 data-t="key" 的元素會換成對應文字；data-t-html 允許 HTML 標記；data-ta 翻譯屬性；
// select[data-lang] 是手動切換語言的選單（記在 localStorage）；網址 ?lang=xx 也可以指定語言。
(function () {
  var T = {
    'zh-Hant': {
      home_title: '旅行團 TourChip · 帶團集合點名',
      home_h: '<b>旅行</b>團',
      home_1: '掃一下入團，集合時每個人都收得到。',
      home_2: '給領隊、導遊的帶團工具：集合呼叫、點名、3D 集合點光柱、同團互相看得到、我迷路了。',
      home_3: '20 人以內免費 · 團員永遠免費',
      privacy: '隱私權政策', terms: '使用條款',
      ios: 'App Store 下載', android: 'Google Play 下載',
      g_title: '加入旅行團 · TourChip',
      g_h: '加入<b>旅行</b>團',
      g_1: '這是一個私人的團，只有拿到領隊分享的人才能加入。',
      g_open: '打開旅行團加入',
      g_2: '已經安裝 App：用手機相機掃 QR code 會直接打開；也可以在 App 裡按「掃碼入團」或「輸入邀請碼入團」。',
      g_inv: '邀請碼', g_3: '還沒裝 App：按上面的下載按鈕，裝好打開就會自動入團（iPhone 詢問時請按「允許貼上」）。沒有自動加入的話，再掃一次這個 QR code，或按「輸入邀請碼入團」輸入上面的數字。',
      l_title: '領隊名片 · TourChip', l_kicker: '旅行團 TourChip · 領隊名片', l_flowers: '團員送的花', l_empty: '領隊還沒有公開感謝。', l_missing: '找不到這張名片，或領隊已經關閉公開。', l_more: '認識旅行團 App',
      v_title: '旅行團 團購券 · TourChip',
      v_h: '<b>團購</b>券',
      v_1: '旅行社發給領隊的團購券（人數券或天數券）。領隊開團後，在 App 的「人數券、天數券 → 掃描團購券」使用。',
      v_open: '打開旅行團使用'
    },
    'zh-Hans': {
      home_title: '旅行团 TourChip · 带团集合点名',
      home_h: '<b>旅行</b>团',
      home_1: '扫一下入团，集合时每个人都收得到。',
      home_2: '给领队、导游的带团工具：集合呼叫、点名、3D 集合点光柱、同团互相看得到、我迷路了。',
      home_3: '20 人以内免费 · 团员永远免费',
      privacy: '隐私政策', terms: '使用条款',
      ios: 'App Store 下载', android: 'Google Play 下载',
      g_title: '加入旅行团 · TourChip',
      g_h: '加入<b>旅行</b>团',
      g_1: '这是一个私人的团，只有拿到领队分享的人才能加入。',
      g_open: '打开旅行团加入',
      g_2: '已经安装 App：用手机相机扫二维码会直接打开；也可以在 App 里按“扫码入团”或“输入邀请码入团”。',
      g_inv: '邀请码', g_3: '还没装 App：按上面的下载按钮，装好打开就会自动入团（iPhone 询问时请按“允许粘贴”）。没有自动加入的话，再扫一次这个二维码，或按“输入邀请码入团”输入上面的数字。',
      l_title: '领队名片 · TourChip', l_kicker: '旅行团 TourChip · 领队名片', l_flowers: '团员送的花', l_empty: '领队还没有公开感谢。', l_missing: '找不到这张名片，或领队已经关闭公开。', l_more: '认识旅行团 App',
      v_title: '旅行团 团购券 · TourChip',
      v_h: '<b>团购</b>券',
      v_1: '旅行社发给领队的团购券（人数券或天数券）。领队开团后，在 App 的“人数券、天数券 → 扫描团购券”使用。',
      v_open: '打开旅行团使用'
    },
    en: {
      home_title: 'TourChip · Meetups and roll calls for group trips',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Scan to join. Everyone hears the meetup call.',
      home_2: 'A group tool for tour leaders and guides: meetup calls, roll call, a 3D light pillar at the meeting point, see your group on the map, and "I\'m lost".',
      home_3: 'Free up to 20 people · Always free for members',
      privacy: 'Privacy', terms: 'Terms',
      ios: 'Download on the App Store', android: 'Get it on Google Play',
      g_title: 'Join a group · TourChip',
      g_h: 'Join a <b>Tour</b>Chip group',
      g_1: 'This is a private group. Only people with the leader\'s link can join.',
      g_open: 'Open TourChip to join',
      g_2: 'Already installed? Scanning the QR code with your camera opens the app. You can also tap "Scan to join" or "Join with invite code" in the app.',
      g_inv: 'Invite code', g_3: 'No app yet? Tap a download button above. Open the app after installing and you\'ll join automatically (on iPhone, tap "Allow Paste"). If it doesn\'t, scan this QR code again, or tap "Join with invite code" and enter the number above.',
      l_title: 'Tour leader · TourChip', l_kicker: 'TourChip · Tour leader card', l_flowers: 'flowers from members', l_empty: 'No public thank-you notes yet.', l_missing: 'This card was not found, or the leader made it private.', l_more: 'About the TourChip app',
      v_title: 'TourChip voucher',
      v_h: '<b>Tour</b>Chip voucher',
      v_1: 'A voucher from your agency (group-size pass or day pass). After starting a group, the leader scans it under "Passes → Scan voucher".',
      v_open: 'Open TourChip to use it'
    },
    ja: {
      home_title: 'TourChip · 団体旅行の集合と点呼',
      home_h: '<b>Tour</b>Chip',
      home_1: 'スキャンで参加、集合は全員に届く。',
      home_2: 'ツアーリーダーとガイドのためのアプリ：集合の呼びかけ、点呼、集合場所の3D光の柱、グループのメンバーが地図で見える、「迷子になった」。',
      home_3: '20人まで無料 · メンバーはずっと無料',
      privacy: 'プライバシーポリシー', terms: '利用規約',
      ios: 'App Store でダウンロード', android: 'Google Play で手に入れよう',
      g_title: 'グループに参加 · TourChip',
      g_h: '<b>Tour</b>Chip グループに参加',
      g_1: 'これは非公開のグループです。リーダーからリンクを受け取った人だけが参加できます。',
      g_open: 'TourChip を開いて参加',
      g_2: 'インストール済みなら、カメラでQRコードをスキャンするとアプリが開きます。アプリ内の「スキャンして参加」や「招待コードで参加」でも参加できます。',
      g_inv: '招待コード', g_3: 'アプリをまだ入れていない方：上のボタンからダウンロードして開くと、自動で参加します（iPhone では「ペーストを許可」をタップ）。参加できなかった場合は、もう一度この QR コードをスキャンするか、「招待コードで参加」から上の数字を入力してください。',
      l_title: 'ツアーリーダー · TourChip', l_kicker: 'TourChip · リーダーの名刺', l_flowers: 'メンバーから届いた花', l_empty: '公開された感謝のことばはまだありません。', l_missing: 'この名刺は見つからないか、非公開になっています。', l_more: 'TourChip アプリについて',
      v_title: 'TourChip クーポン',
      v_h: '<b>Tour</b>Chip クーポン',
      v_1: '旅行会社からリーダーに渡されるクーポン（人数パスまたは日数パス）です。グループ作成後、「人数パス・日数パス → クーポンをスキャン」から使います。',
      v_open: 'TourChip を開いて使う'
    },
    ko: {
      home_title: 'TourChip · 단체 여행 집합과 출석 확인',
      home_h: '<b>Tour</b>Chip',
      home_1: '스캔으로 참가, 집합 알림은 모두에게.',
      home_2: '인솔자와 가이드를 위한 앱: 집합 호출, 출석 확인, 집합 장소의 3D 빛기둥, 지도에서 그룹 보기, "길을 잃었어요".',
      home_3: '20명까지 무료 · 멤버는 항상 무료',
      privacy: '개인정보 처리방침', terms: '이용약관',
      ios: 'App Store에서 다운로드', android: 'Google Play에서 받기',
      g_title: '그룹 참가 · TourChip',
      g_h: '<b>Tour</b>Chip 그룹 참가',
      g_1: '비공개 그룹이에요. 리더에게 링크를 받은 사람만 참가할 수 있어요.',
      g_open: 'TourChip 열고 참가',
      g_2: '이미 설치했다면 카메라로 QR 코드를 스캔하면 앱이 열려요. 앱에서 "스캔해서 참가"나 "초대 코드로 참가"를 눌러도 돼요.',
      g_inv: '초대 코드', g_3: '아직 앱이 없나요? 위의 다운로드 버튼을 누르고 설치한 앱을 열면 자동으로 참가돼요(iPhone에서는 "붙여넣기 허용"을 눌러 주세요). 참가되지 않으면 이 QR 코드를 다시 스캔하거나 "초대 코드로 참가"를 눌러 위의 숫자를 입력하세요.',
      l_title: '투어 리더 · TourChip', l_kicker: 'TourChip · 리더 명함', l_flowers: '멤버가 보낸 꽃', l_empty: '아직 공개된 감사 인사가 없어요.', l_missing: '명함을 찾을 수 없거나 리더가 비공개로 바꿨어요.', l_more: 'TourChip 앱 알아보기',
      v_title: 'TourChip 이용권',
      v_h: '<b>Tour</b>Chip 이용권',
      v_1: '여행사가 리더에게 주는 이용권(인원 이용권 또는 일수 이용권)이에요. 그룹을 만든 뒤 "인원·일수 이용권 → 이용권 스캔"에서 사용하세요.',
      v_open: 'TourChip 열고 사용'
    },
    ms: {
      home_title: 'TourChip · Berkumpul dan panggilan nama untuk lawatan berkumpulan',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Imbas untuk sertai. Semua orang dengar panggilan berkumpul.',
      home_2: 'Alat untuk ketua rombongan dan pemandu pelancong: panggilan berkumpul, panggilan nama, tiang cahaya 3D di tempat berkumpul, lihat kumpulan pada peta, dan "Saya sesat".',
      home_3: 'Percuma sehingga 20 orang · Ahli sentiasa percuma',
      privacy: 'Dasar privasi', terms: 'Terma',
      ios: 'Muat turun di App Store', android: 'Dapatkan di Google Play',
      g_title: 'Sertai kumpulan · TourChip',
      g_h: 'Sertai kumpulan <b>Tour</b>Chip',
      g_1: 'Ini kumpulan peribadi. Hanya orang yang menerima pautan ketua boleh sertai.',
      g_open: 'Buka TourChip untuk sertai',
      g_2: 'Sudah dipasang? Imbas kod QR dengan kamera untuk membuka aplikasi, atau ketik "Imbas untuk sertai" atau "Sertai dengan kod jemputan" dalam aplikasi.',
      g_inv: 'Kod jemputan', g_3: 'Belum ada aplikasi? Ketik butang muat turun di atas. Buka aplikasi selepas dipasang dan anda akan menyertai secara automatik (di iPhone, ketik "Benarkan Tampal"). Jika tidak, imbas kod QR ini sekali lagi, atau ketik "Sertai dengan kod jemputan" dan masukkan nombor di atas.',
      l_title: 'Ketua rombongan · TourChip', l_kicker: 'TourChip · Kad ketua rombongan', l_flowers: 'bunga daripada ahli', l_empty: 'Belum ada ucapan terima kasih awam.', l_missing: 'Kad ini tidak dijumpai, atau ketua telah menjadikannya peribadi.', l_more: 'Tentang aplikasi TourChip',
      v_title: 'Baucar TourChip',
      v_h: 'Baucar <b>Tour</b>Chip',
      v_1: 'Baucar daripada agensi anda (pas saiz kumpulan atau pas hari). Selepas memulakan kumpulan, ketua mengimbasnya di "Pas → Imbas baucar".',
      v_open: 'Buka TourChip untuk guna'
    },
    id: {
      home_title: 'TourChip · Kumpul dan absen untuk perjalanan grup',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Pindai untuk bergabung. Semua dengar panggilan kumpul.',
      home_2: 'Aplikasi untuk tour leader dan pemandu: panggilan kumpul, absen, pilar cahaya 3D di titik kumpul, lihat grup di peta, dan "Saya tersesat".',
      home_3: 'Gratis hingga 20 orang · Anggota selalu gratis',
      privacy: 'Kebijakan privasi', terms: 'Ketentuan',
      ios: 'Unduh di App Store', android: 'Dapatkan di Google Play',
      g_title: 'Gabung grup · TourChip',
      g_h: 'Gabung grup <b>Tour</b>Chip',
      g_1: 'Ini grup privat. Hanya yang menerima tautan dari pemimpin yang bisa bergabung.',
      g_open: 'Buka TourChip untuk bergabung',
      g_2: 'Sudah terpasang? Pindai kode QR dengan kamera untuk membuka aplikasi, atau ketuk "Pindai untuk bergabung" atau "Gabung dengan kode undangan" di aplikasi.',
      g_inv: 'Kode undangan', g_3: 'Belum punya aplikasinya? Ketuk tombol unduh di atas. Buka aplikasi setelah terpasang dan kamu akan bergabung otomatis (di iPhone, ketuk "Izinkan Tempel"). Kalau tidak, pindai kode QR ini sekali lagi, atau ketuk "Gabung dengan kode undangan" dan masukkan angka di atas.',
      l_title: 'Pemimpin tur · TourChip', l_kicker: 'TourChip · Kartu pemimpin tur', l_flowers: 'bunga dari anggota', l_empty: 'Belum ada ucapan terima kasih yang dipublikasikan.', l_missing: 'Kartu ini tidak ditemukan, atau pemimpin menjadikannya privat.', l_more: 'Tentang aplikasi TourChip',
      v_title: 'Voucher TourChip',
      v_h: 'Voucher <b>Tour</b>Chip',
      v_1: 'Voucher dari agen perjalanan (tiket jumlah anggota atau tiket hari). Setelah membuat grup, pemimpin memindainya di "Tiket → Pindai voucher".',
      v_open: 'Buka TourChip untuk memakai'
    },
    vi: {
      home_title: 'TourChip · Tập trung và điểm danh cho chuyến đi đoàn',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Quét để tham gia. Ai cũng nghe lời gọi tập trung.',
      home_2: 'Ứng dụng cho trưởng đoàn và hướng dẫn viên: gọi tập trung, điểm danh, cột sáng 3D tại điểm hẹn, thấy cả đoàn trên bản đồ và nút "Tôi bị lạc".',
      home_3: 'Miễn phí đến 20 người · Thành viên luôn miễn phí',
      privacy: 'Quyền riêng tư', terms: 'Điều khoản',
      ios: 'Tải trên App Store', android: 'Tải trên Google Play',
      g_title: 'Tham gia đoàn · TourChip',
      g_h: 'Tham gia đoàn <b>Tour</b>Chip',
      g_1: 'Đây là đoàn riêng tư. Chỉ người nhận được liên kết của trưởng đoàn mới tham gia được.',
      g_open: 'Mở TourChip để tham gia',
      g_2: 'Đã cài ứng dụng? Quét mã QR bằng camera để mở ứng dụng, hoặc chạm "Quét để tham gia" hay "Tham gia bằng mã mời" trong ứng dụng.',
      g_inv: 'Mã mời', g_3: 'Chưa có ứng dụng? Chạm nút tải về ở trên. Cài xong mở ứng dụng là tự vào đoàn (trên iPhone, chạm "Cho phép dán"). Nếu chưa vào được, hãy quét lại mã QR này, hoặc chạm "Tham gia bằng mã mời" và nhập dãy số ở trên.',
      l_title: 'Trưởng đoàn · TourChip', l_kicker: 'TourChip · Danh thiếp trưởng đoàn', l_flowers: 'hoa thành viên tặng', l_empty: 'Chưa có lời cảm ơn công khai.', l_missing: 'Không tìm thấy danh thiếp này, hoặc trưởng đoàn đã tắt công khai.', l_more: 'Tìm hiểu ứng dụng TourChip',
      v_title: 'Phiếu TourChip',
      v_h: 'Phiếu <b>Tour</b>Chip',
      v_1: 'Phiếu do công ty du lịch cấp cho trưởng đoàn (vé số người hoặc vé ngày). Sau khi tạo đoàn, quét phiếu ở mục "Vé → Quét phiếu".',
      v_open: 'Mở TourChip để dùng'
    },
    th: {
      home_title: 'TourChip · รวมตัวและเช็กชื่อสำหรับทริปกลุ่ม',
      home_h: '<b>Tour</b>Chip',
      home_1: 'สแกนเพื่อเข้าร่วม ทุกคนได้ยินการเรียกรวมตัว',
      home_2: 'แอปสำหรับหัวหน้าทัวร์และไกด์: เรียกรวมตัว เช็กชื่อ เสาแสง 3D ที่จุดนัดพบ เห็นกลุ่มบนแผนที่ และปุ่ม "ฉันหลงทาง"',
      home_3: 'ฟรีสูงสุด 20 คน · สมาชิกฟรีตลอด',
      privacy: 'นโยบายความเป็นส่วนตัว', terms: 'ข้อกำหนด',
      ios: 'ดาวน์โหลดบน App Store', android: 'ดาวน์โหลดบน Google Play',
      g_title: 'เข้าร่วมกลุ่ม · TourChip',
      g_h: 'เข้าร่วมกลุ่ม <b>Tour</b>Chip',
      g_1: 'นี่คือกลุ่มส่วนตัว เฉพาะคนที่ได้รับลิงก์จากหัวหน้าเท่านั้นที่เข้าร่วมได้',
      g_open: 'เปิด TourChip เพื่อเข้าร่วม',
      g_2: 'ติดตั้งแอปแล้ว? สแกน QR code ด้วยกล้องเพื่อเปิดแอป หรือแตะ "สแกนเพื่อเข้าร่วม" หรือ "เข้าร่วมด้วยรหัสเชิญ" ในแอป',
      g_inv: 'รหัสเชิญ', g_3: 'ยังไม่มีแอป? แตะปุ่มดาวน์โหลดด้านบน ติดตั้งแล้วเปิดแอปก็จะเข้าร่วมให้อัตโนมัติ (บน iPhone ให้แตะ "อนุญาตให้วาง") ถ้ายังไม่เข้าร่วม ให้สแกน QR code นี้อีกครั้ง หรือแตะ "เข้าร่วมด้วยรหัสเชิญ" แล้วใส่ตัวเลขด้านบน',
      l_title: 'หัวหน้าทัวร์ · TourChip', l_kicker: 'TourChip · นามบัตรหัวหน้าทัวร์', l_flowers: 'ดอกไม้จากสมาชิก', l_empty: 'ยังไม่มีคำขอบคุณที่เปิดเผย', l_missing: 'ไม่พบนามบัตรนี้ หรือหัวหน้าทัวร์ปิดการเปิดเผยแล้ว', l_more: 'รู้จักแอป TourChip',
      v_title: 'คูปอง TourChip',
      v_h: 'คูปอง <b>Tour</b>Chip',
      v_1: 'คูปองจากบริษัททัวร์ (บัตรเพิ่มจำนวนคนหรือบัตรเพิ่มวัน) หลังสร้างกลุ่มแล้ว หัวหน้าสแกนที่ "บัตร → สแกนคูปอง"',
      v_open: 'เปิด TourChip เพื่อใช้'
    },
    pt: {
      home_title: 'TourChip · Encontros e chamadas para viagens em grupo',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Escaneie para entrar. Todos ouvem a convocação.',
      home_2: 'Ferramenta para líderes de grupo e guias: convocações, chamada, um feixe de luz 3D no ponto de encontro, veja seu grupo no mapa e “Estou perdido”.',
      home_3: 'Grátis até 20 pessoas · Sempre grátis para membros',
      privacy: 'Privacidade',
      terms: 'Termos',
      ios: 'Baixar na App Store',
      android: 'Disponível no Google Play',
      g_title: 'Entrar no grupo · TourChip',
      g_h: 'Entre em um grupo do <b>Tour</b>Chip',
      g_1: 'Este é um grupo privado. Só quem tem o link do líder pode entrar.',
      g_open: 'Abrir o TourChip para entrar',
      g_2: 'Já tem o app? Escanear o QR code com a câmera abre o app. Você também pode tocar em “Escanear para entrar” ou “Entrar com código de convite” no app.',
      g_inv: 'Código de convite',
      g_3: 'Ainda não tem o app? Toque em um botão de download acima. Ao abrir o app depois de instalar, você entra automaticamente (no iPhone, toque em “Permitir Colar”). Se não entrar, escaneie este QR code de novo ou toque em “Entrar com código de convite” e digite o número acima.',
      l_title: 'Líder de grupo · TourChip',
      l_kicker: 'TourChip · Cartão do líder',
      l_flowers: 'flores dos membros',
      l_empty: 'Nenhum agradecimento público ainda.',
      l_missing: 'Este cartão não foi encontrado ou o líder o deixou privado.',
      l_more: 'Sobre o app TourChip',
      v_title: 'Voucher do TourChip',
      v_h: 'Voucher do <b>Tour</b>Chip',
      v_1: 'Um voucher da sua agência (passe de 100 pessoas ou passe de dias). Depois de criar o grupo, o líder o escaneia em “Passes → Escanear voucher”.',
      v_open: 'Abrir o TourChip para usar'
    },
    es: {
      home_title: 'TourChip · Reuniones y pase de lista para viajes en grupo',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Escanea para unirte. Todos oyen la llamada de reunión.',
      home_2: 'Una herramienta para líderes y guías de grupo: llamadas de reunión, pase de lista, un haz de luz 3D en el punto de encuentro, ver a tu grupo en el mapa y “Me perdí”.',
      home_3: 'Gratis hasta 20 personas · Siempre gratis para los miembros',
      privacy: 'Privacidad',
      terms: 'Términos',
      ios: 'Descargar en App Store',
      android: 'Disponible en Google Play',
      g_title: 'Unirse a un grupo · TourChip',
      g_h: 'Únete a un grupo de <b>Tour</b>Chip',
      g_1: 'Es un grupo privado. Solo pueden unirse quienes tengan el enlace del líder.',
      g_open: 'Abrir TourChip para unirte',
      g_2: '¿Ya la tienes instalada? Al escanear el código QR con la cámara se abre la app. También puedes tocar “Escanear para unirse” o “Unirse con código de invitación” en la app.',
      g_inv: 'Código de invitación',
      g_3: '¿Aún no tienes la app? Toca un botón de descarga de arriba. Al abrir la app después de instalarla, te unirás automáticamente (en iPhone, toca “Permitir pegar”). Si no ocurre, vuelve a escanear este código QR o toca “Unirse con código de invitación” e introduce el número de arriba.',
      l_title: 'Líder de grupo · TourChip',
      l_kicker: 'TourChip · Tarjeta de líder',
      l_flowers: 'flores de los miembros',
      l_empty: 'Aún no hay agradecimientos públicos.',
      l_missing: 'No se encontró esta tarjeta, o el líder la hizo privada.',
      l_more: 'Sobre la app TourChip',
      v_title: 'Cupón de TourChip',
      v_h: 'Cupón de <b>Tour</b>Chip',
      v_1: 'Un cupón de tu agencia (pase de personas o pase de días). Después de crear un grupo, el líder lo escanea en “Pases → Escanear cupón”.',
      v_open: 'Abrir TourChip para usarlo'
    },
    hi: {
      home_title: 'TourChip · ग्रुप यात्राओं के लिए इकट्ठा होना और हाज़िरी',
      home_h: '<b>Tour</b>Chip',
      home_1: 'स्कैन करके जुड़ें। इकट्ठा होने की कॉल सबको सुनाई देती है।',
      home_2: 'टूर लीडर और गाइड के लिए ग्रुप टूल: इकट्ठा होने की कॉल, हाज़िरी, मिलने की जगह पर 3D रोशनी का खंभा, मैप पर अपना ग्रुप देखें, और "मुझे रास्ता नहीं मिल रहा"।',
      home_3: '20 लोगों तक मुफ़्त · सदस्यों के लिए हमेशा मुफ़्त',
      privacy: 'प्राइवेसी',
      terms: 'शर्तें',
      ios: 'App Store से डाउनलोड करें',
      android: 'Google Play पर पाएँ',
      g_title: 'ग्रुप से जुड़ें · TourChip',
      g_h: '<b>Tour</b>Chip ग्रुप से जुड़ें',
      g_1: 'यह एक प्राइवेट ग्रुप है। सिर्फ़ लीडर के लिंक वाले लोग ही जुड़ सकते हैं।',
      g_open: 'जुड़ने के लिए TourChip खोलें',
      g_2: 'ऐप पहले से है? कैमरे से QR कोड स्कैन करने पर ऐप खुल जाता है। आप ऐप में "स्कैन करके जुड़ें" या "इनवाइट कोड से जुड़ें" भी दबा सकते हैं।',
      g_inv: 'इनवाइट कोड',
      g_3: 'ऐप नहीं है? ऊपर डाउनलोड बटन दबाएँ। इंस्टॉल करके ऐप खोलते ही आप अपने आप जुड़ जाएँगे (iPhone पर "पेस्ट की अनुमति दें" दबाएँ)। अगर नहीं जुड़े, तो यह QR कोड दोबारा स्कैन करें या "इनवाइट कोड से जुड़ें" दबाकर ऊपर का नंबर डालें।',
      l_title: 'टूर लीडर · TourChip',
      l_kicker: 'TourChip · टूर लीडर कार्ड',
      l_flowers: 'सदस्यों से मिले फूल',
      l_empty: 'अभी कोई पब्लिक धन्यवाद नहीं।',
      l_missing: 'यह कार्ड नहीं मिला, या लीडर ने इसे प्राइवेट कर दिया है।',
      l_more: 'TourChip ऐप के बारे में',
      v_title: 'TourChip वाउचर',
      v_h: '<b>Tour</b>Chip वाउचर',
      v_1: 'आपकी एजेंसी का वाउचर (ग्रुप-साइज़ पास या डे पास)। ग्रुप शुरू करने के बाद लीडर इसे "पास → वाउचर स्कैन करें" में स्कैन करते हैं।',
      v_open: 'इस्तेमाल करने के लिए TourChip खोलें'
    },
    fr: {
      home_title: 'TourChip · Rassemblements et appels pour les voyages de groupe',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Scannez pour rejoindre. Tout le monde entend l\'appel au rassemblement.',
      home_2: 'L\'outil de groupe des accompagnateurs et guides : appels au rassemblement, appel nominal, faisceau lumineux 3D au point de rassemblement, votre groupe sur la carte et « Je suis perdu ».',
      home_3: 'Gratuit jusqu\'à 20 personnes · Toujours gratuit pour les membres',
      privacy: 'Confidentialité',
      terms: 'Conditions',
      ios: 'Télécharger dans l\'App Store',
      android: 'Disponible sur Google Play',
      g_title: 'Rejoindre un groupe · TourChip',
      g_h: 'Rejoindre un groupe <b>Tour</b>Chip',
      g_1: 'Ce groupe est privé. Seules les personnes ayant le lien de l\'accompagnateur peuvent le rejoindre.',
      g_open: 'Ouvrir TourChip pour rejoindre',
      g_2: 'App déjà installée ? Scanner le QR code avec l\'appareil photo ouvre l\'app. Vous pouvez aussi toucher « Scanner » ou « Rejoindre avec un code » dans l\'app.',
      g_inv: 'Code d\'invitation',
      g_3: 'Pas encore l\'app ? Touchez un bouton de téléchargement ci-dessus. Ouvrez l\'app après l\'installation et vous rejoindrez le groupe automatiquement (sur iPhone, touchez « Autoriser le collage »). Sinon, scannez à nouveau ce QR code, ou touchez « Rejoindre avec un code » et saisissez le numéro ci-dessus.',
      l_title: 'Accompagnateur · TourChip',
      l_kicker: 'TourChip · Carte d\'accompagnateur',
      l_flowers: 'fleurs des membres',
      l_empty: 'Pas encore de remerciements publics.',
      l_missing: 'Cette carte est introuvable, ou l\'accompagnateur l\'a rendue privée.',
      l_more: 'À propos de l\'app TourChip',
      v_title: 'Bon TourChip',
      v_h: 'Bon <b>Tour</b>Chip',
      v_1: 'Un bon de votre agence (pass grand groupe ou pass 7 jours). Après avoir créé le groupe, l\'accompagnateur le scanne dans « Pass → Scanner un bon ».',
      v_open: 'Ouvrir TourChip pour l\'utiliser'
    },
    de: {
      home_title: 'TourChip · Sammeln und Durchzählen für Gruppenreisen',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Scannen und beitreten. Alle hören den Sammelruf.',
      home_2: 'Ein Gruppen-Tool für Reiseleitungen und Guides: Sammelrufe, Durchzählen, eine 3D-Lichtsäule am Treffpunkt, die Gruppe auf der Karte sehen und „Ich hab mich verlaufen“.',
      home_3: 'Gratis bis 20 Personen · Für Mitglieder immer gratis',
      privacy: 'Datenschutz',
      terms: 'Nutzungsbedingungen',
      ios: 'Laden im App Store',
      android: 'Jetzt bei Google Play',
      g_title: 'Gruppe beitreten · TourChip',
      g_h: 'Einer <b>Tour</b>Chip-Gruppe beitreten',
      g_1: 'Das ist eine private Gruppe. Nur wer den Link der Reiseleitung hat, kann beitreten.',
      g_open: 'TourChip öffnen und beitreten',
      g_2: 'Schon installiert? Wenn du den QR-Code mit der Kamera scannst, öffnet sich die App. Du kannst in der App auch auf „Scannen“ oder „Mit Einladungscode beitreten“ tippen.',
      g_inv: 'Einladungscode',
      g_3: 'Noch keine App? Tippe oben auf einen Download-Button. Öffne die App nach der Installation, dann trittst du automatisch bei (auf dem iPhone „Einsetzen erlauben“ tippen). Falls nicht, scanne diesen QR-Code noch einmal oder tippe auf „Mit Einladungscode beitreten“ und gib die Nummer oben ein.',
      l_title: 'Reiseleitung · TourChip',
      l_kicker: 'TourChip · Karte der Reiseleitung',
      l_flowers: 'Blumen von Mitgliedern',
      l_empty: 'Noch keine öffentlichen Dankesworte.',
      l_missing: 'Diese Karte wurde nicht gefunden oder die Reiseleitung hat sie auf privat gestellt.',
      l_more: 'Über die TourChip-App',
      v_title: 'TourChip-Gutschein',
      v_h: '<b>Tour</b>Chip-Gutschein',
      v_1: 'Ein Gutschein deiner Agentur (Gruppenpass oder Tagespass). Nach dem Start einer Gruppe scannt die Reiseleitung ihn unter „Pässe → Gutschein scannen“.',
      v_open: 'TourChip öffnen und einlösen'
    },
    it: {
      home_title: 'TourChip · Ritrovi e appelli per i viaggi di gruppo',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Scansiona per entrare. Tutti sentono la chiamata di ritrovo.',
      home_2: 'Uno strumento per capigruppo e guide: chiamate di ritrovo, appello, un raggio di luce 3D sul punto di ritrovo, il gruppo sulla mappa e "Mi sono perso".',
      home_3: 'Gratis fino a 20 persone · Sempre gratis per i partecipanti',
      privacy: 'Privacy',
      terms: 'Termini',
      ios: 'Scarica su App Store',
      android: 'Disponibile su Google Play',
      g_title: 'Entra in un gruppo · TourChip',
      g_h: 'Entra in un gruppo <b>Tour</b>Chip',
      g_1: 'Questo è un gruppo privato. Può entrare solo chi ha il link del capogruppo.',
      g_open: 'Apri TourChip per entrare',
      g_2: 'Hai già l\'app? Scansionando il QR code con la fotocamera si apre l\'app. Puoi anche toccare "Scansiona" o "Entra con codice invito" nell\'app.',
      g_inv: 'Codice invito',
      g_3: 'Non hai ancora l\'app? Tocca uno dei pulsanti di download qui sopra. Apri l\'app dopo l\'installazione ed entrerai in automatico (su iPhone tocca "Consenti incolla"). Se non succede, scansiona di nuovo questo QR code oppure tocca "Entra con codice invito" e inserisci il numero qui sopra.',
      l_title: 'Capogruppo · TourChip',
      l_kicker: 'TourChip · Scheda del capogruppo',
      l_flowers: 'fiori dai partecipanti',
      l_empty: 'Ancora nessun ringraziamento pubblico.',
      l_missing: 'Scheda non trovata, oppure il capogruppo l\'ha resa privata.',
      l_more: 'Scopri l\'app TourChip',
      v_title: 'Voucher TourChip',
      v_h: 'Voucher <b>Tour</b>Chip',
      v_1: 'Un voucher della tua agenzia (pass gruppo o pass giorni). Dopo aver creato il gruppo, il capogruppo lo scansiona in "Pass → Scansiona voucher".',
      v_open: 'Apri TourChip per usarlo'
    },
    cs: {
      home_title: 'TourChip · Srazy a prezence pro skupinové zájezdy',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Naskenujte a připojte se. Svolání na sraz uslyší každý.',
      home_2: 'Nástroj pro vedoucí zájezdů a průvodce: svolání na sraz, prezence, 3D světelný sloup na místě srazu, skupina na mapě a „Nevím, kde jsem“.',
      home_3: 'Zdarma až pro 20 lidí · Pro účastníky vždy zdarma',
      privacy: 'Ochrana soukromí',
      terms: 'Podmínky',
      ios: 'Stáhnout v App Store',
      android: 'Získat na Google Play',
      g_title: 'Připojit se ke skupině · TourChip',
      g_h: 'Připojte se ke skupině <b>Tour</b>Chip',
      g_1: 'Toto je soukromá skupina. Připojit se mohou jen lidé s odkazem od vedoucího.',
      g_open: 'Otevřít TourChip a připojit se',
      g_2: 'Už aplikaci máte? Naskenováním QR kódu fotoaparátem se aplikace otevře. V aplikaci můžete také klepnout na „Naskenovat“ nebo „Připojit se kódem pozvánky“.',
      g_inv: 'Kód pozvánky',
      g_3: 'Ještě nemáte aplikaci? Klepněte na tlačítko ke stažení výše. Po instalaci aplikaci otevřete a připojíte se automaticky (na iPhonu klepněte na „Povolit vložení“). Pokud se to nestane, naskenujte tento QR kód znovu nebo klepněte na „Připojit se kódem pozvánky“ a zadejte číslo výše.',
      l_title: 'Vedoucí zájezdu · TourChip',
      l_kicker: 'TourChip · Karta vedoucího',
      l_flowers: 'květin od účastníků',
      l_empty: 'Zatím žádná veřejná poděkování.',
      l_missing: 'Tato karta nebyla nalezena, nebo ji vedoucí skryl.',
      l_more: 'O aplikaci TourChip',
      v_title: 'Voucher TourChip',
      v_h: 'Voucher <b>Tour</b>Chip',
      v_1: 'Voucher od vaší cestovní kanceláře (rozšíření skupiny nebo denní pas). Po založení skupiny ho vedoucí naskenuje v „Pasy → Naskenovat voucher“.',
      v_open: 'Otevřít TourChip a použít'
    },
    pl: {
      home_title: 'TourChip · Zbiórki i sprawdzanie obecności na wycieczkach grupowych',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Zeskanuj i dołącz. Każdy usłyszy zbiórkę.',
      home_2: 'Narzędzie dla pilotów i przewodników: wezwania na zbiórkę, sprawdzanie obecności, świetlny słup 3D w miejscu zbiórki, grupa na mapie i przycisk „Zgubiłem(-am) się”.',
      home_3: 'Za darmo do 20 osób · Uczestnicy zawsze za darmo',
      privacy: 'Prywatność',
      terms: 'Warunki',
      ios: 'Pobierz z App Store',
      android: 'Pobierz z Google Play',
      g_title: 'Dołącz do grupy · TourChip',
      g_h: 'Dołącz do grupy <b>Tour</b>Chip',
      g_1: 'To prywatna grupa. Dołączyć mogą tylko osoby z linkiem od pilota.',
      g_open: 'Otwórz TourChip, żeby dołączyć',
      g_2: 'Masz już aplikację? Zeskanowanie kodu QR aparatem ją otworzy. Możesz też dotknąć w aplikacji „Skanuj” lub „Dołącz kodem zaproszenia”.',
      g_inv: 'Kod zaproszenia',
      g_3: 'Nie masz aplikacji? Dotknij przycisku pobierania powyżej. Po instalacji otwórz aplikację, a dołączysz automatycznie (na iPhonie dotknij „Zezwól na wklejanie”). Jeśli to nie zadziała, zeskanuj ten kod QR ponownie albo dotknij „Dołącz kodem zaproszenia” i wpisz numer powyżej.',
      l_title: 'Pilot wycieczki · TourChip',
      l_kicker: 'TourChip · Karta pilota',
      l_flowers: 'kwiatów od uczestników',
      l_empty: 'Brak publicznych podziękowań.',
      l_missing: 'Nie znaleziono tej karty albo pilot ustawił ją jako prywatną.',
      l_more: 'O aplikacji TourChip',
      v_title: 'Voucher TourChip',
      v_h: 'Voucher <b>Tour</b>Chip',
      v_1: 'Voucher od biura podróży (pakiet osób lub pakiet dni). Po utworzeniu grupy pilot skanuje go w „Pakiety → Zeskanuj voucher”.',
      v_open: 'Otwórz TourChip, żeby go użyć'
    },
    uk: {
      home_title: 'TourChip · Збори й переклички для групових подорожей',
      home_h: '<b>Tour</b>Chip',
      home_1: 'Скануйте, щоб приєднатися. Сигнал збору почують усі.',
      home_2: 'Інструмент для керівників груп і гідів: сигнали збору, перекличка, 3D-промінь світла на місці збору, група на карті та кнопка «Не знаходжу групу».',
      home_3: 'Безкоштовно до 20 осіб · Для учасників завжди безкоштовно',
      privacy: 'Конфіденційність',
      terms: 'Умови',
      ios: 'Завантажити в App Store',
      android: 'Завантажити з Google Play',
      g_title: 'Приєднатися до групи · TourChip',
      g_h: 'Приєднайтеся до групи в <b>Tour</b>Chip',
      g_1: 'Це закрита група. Приєднатися можуть лише ті, хто має посилання від керівника.',
      g_open: 'Відкрити TourChip і приєднатися',
      g_2: 'Застосунок уже встановлено? Скануйте QR-код камерою — і він відкриється. Також можна натиснути в застосунку «Сканувати» або «Приєднатися за кодом».',
      g_inv: 'Код запрошення',
      g_3: 'Ще немає застосунку? Натисніть кнопку завантаження вище. Після встановлення відкрийте застосунок — і ви приєднаєтеся автоматично (на iPhone натисніть «Дозволити вставлення»). Якщо не вийшло, скануйте цей QR-код ще раз або натисніть «Приєднатися за кодом» і введіть номер вище.',
      l_title: 'Керівник групи · TourChip',
      l_kicker: 'TourChip · Картка керівника групи',
      l_flowers: 'квітів від учасників',
      l_empty: 'Публічних подяк поки немає.',
      l_missing: 'Картку не знайдено, або керівник зробив її приватною.',
      l_more: 'Про застосунок TourChip',
      v_title: 'Ваучер TourChip',
      v_h: 'Ваучер <b>Tour</b>Chip',
      v_1: 'Ваучер від вашої агенції (пакет учасників або пакет днів). Після створення групи керівник сканує його в розділі «Пакети → Сканувати ваучер».',
      v_open: 'Відкрити TourChip і використати'
    }
  };

  // 其他頁面（例如首頁）的字串放在 window.TC_I18N，載入 i18n.js 之前先定義
  var X = window.TC_I18N || {};
  for (var L in X) { if (!T[L]) T[L] = {}; for (var k in X[L]) T[L][k] = X[L][k]; }

  var SHOT_DIRS = { 'zh-Hant': 'zh', 'zh-Hans': 'zh-Hans', en: 'en', ja: 'ja', ko: 'ko', ms: 'ms', id: 'id', vi: 'vi', th: 'th', pt: 'pt', es: 'es', hi: 'hi' };
  function shotDir(lang) { return SHOT_DIRS[lang] || 'en'; }
  var NAMES = { 'zh-Hant': '繁體中文', 'zh-Hans': '简体中文', en: 'English', ja: '日本語', ko: '한국어', ms: 'Bahasa Melayu', id: 'Bahasa Indonesia', vi: 'Tiếng Việt', th: 'ไทย', pt: 'Português', es: 'Español', hi: 'हिन्दी', fr: 'Français', de: 'Deutsch', it: 'Italiano', cs: 'Čeština', pl: 'Polski', uk: 'Українська' };

  function norm(tag) {
    tag = String(tag || '').toLowerCase().replace(/_/g, '-');
    var p = tag.split('-');
    if (p[0] === 'zh') return /hans|cn|sg|my/.test(tag) ? 'zh-Hans' : 'zh-Hant';
    if (p[0] === 'in') return 'id';
    return T[p[0]] ? p[0] : null;
  }

  // 首頁的各語言網址 /en/、/ja/ …（tool/gen_lang_pages.py 產生，分享預覽才會是該語言）；繁中是 /
  function pathLang() {
    var m = location.pathname.match(/^\/(zh-Hans|en|ja|ko|ms|id|vi|th|pt|es|hi|fr|de|it|cs|pl|uk)\/?$/);
    return m ? m[1] : null;
  }
  function isHome() { return location.pathname === '/' || location.pathname === '/index.html' || !!pathLang(); }

  function pick() {
    // 1. 網址 /ja/ 或 ?lang=ja  2. 上次手動選的語言  3. 瀏覽器語言  4. 英文
    var pl = pathLang(); if (pl) return pl;
    try { var q = norm(new URLSearchParams(location.search).get('lang')); if (q) return q; } catch (e) {}
    try { var s = norm(localStorage.getItem('tc_lang')); if (s) return s; } catch (e) {}
    var list = (navigator.languages && navigator.languages.length) ? navigator.languages : [navigator.language || 'en'];
    for (var i = 0; i < list.length; i++) { var n = norm(list[i]); if (n) return n; }
    return 'en';
  }

  function apply(lang) {
    var d = T[lang] || T.en, base = T['zh-Hant'];
    document.documentElement.lang = lang;
    var nodes = document.querySelectorAll('[data-t]');
    for (var i = 0; i < nodes.length; i++) {
      var k = nodes[i].getAttribute('data-t');
      // 頁面原本寫的繁中文字先記下來，切回繁中或缺翻譯時用
      if (nodes[i]._zh == null) nodes[i]._zh = nodes[i].hasAttribute('data-t-html') ? nodes[i].innerHTML : nodes[i].textContent;
      var v = d[k] != null ? d[k] : (lang !== 'zh-Hant' && T.en[k] != null ? T.en[k] : nodes[i]._zh);
      if (nodes[i].hasAttribute('data-t-html')) nodes[i].innerHTML = v; else nodes[i].textContent = v;
    }
    // data-ta="alt:key;content:key"：翻譯屬性
    var an = document.querySelectorAll('[data-ta]');
    for (var j = 0; j < an.length; j++) {
      an[j].getAttribute('data-ta').split(';').forEach(function (pair) {
        var p = pair.split(':'); if (p.length !== 2) return;
        var el = an[j]; el._zha = el._zha || {};
        if (el._zha[p[0]] == null) el._zha[p[0]] = el.getAttribute(p[0]) || '';
        var v = d[p[1]] != null ? d[p[1]] : (lang !== 'zh-Hant' && T.en[p[1]] != null ? T.en[p[1]] : el._zha[p[0]]);
        if (v != null) an[j].setAttribute(p[0], v.replace(/<[^>]+>/g, ''));
      });
    }
    // 截圖：每種語言用自己語言的 App 畫面（img/shots/<語言>），沒有的語言用英文
    var shots = document.querySelectorAll('img[data-shot]');
    for (var m = 0; m < shots.length; m++) shots[m].src = '/img/shots/' + shotDir(lang) + '/' + shots[m].getAttribute('data-shot') + '.webp?v=20261116';
    var t = document.querySelector('[data-title]');
    if (window._zhTitle == null) window._zhTitle = document.title;
    if (t) { var tk = t.getAttribute('data-title'); document.title = d[tk] || (lang !== 'zh-Hant' && T.en[tk]) || window._zhTitle; }
    var sel = document.querySelectorAll('select[data-lang]');
    for (var n = 0; n < sel.length; n++) sel[n].value = lang;
  }

  var current = pick();
  apply(current);

  // 語言選單
  var sels = document.querySelectorAll('select[data-lang]');
  for (var i = 0; i < sels.length; i++) {
    if (!sels[i].options.length) for (var code in NAMES) { var o = document.createElement('option'); o.value = code; o.textContent = NAMES[code]; sels[i].appendChild(o); }
    sels[i].value = current;
    sels[i].addEventListener('change', function (e) {
      current = e.target.value;
      try { localStorage.setItem('tc_lang', current); } catch (err) {}
      apply(current);
      // 首頁：網址跟著換成該語言的網址，複製分享出去預覽就是這個語言
      if (isHome() && history.replaceState) {
        try { history.replaceState(null, '', (current === 'zh-Hant' ? '/' : '/' + current + '/') + location.search.replace(/([?&])lang=[^&]*&?/, '$1').replace(/[?&]$/, '') + location.hash); } catch (err) {}
      }
    });
  }
})();
