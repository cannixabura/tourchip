// 官網頁面的多語言：依瀏覽器語言顯示（繁中、簡中、英、日、韓、馬來、印尼、越南、泰），其他語言用英文。
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
      g_2: '已經安裝 App：用手機相機掃 QR code 會直接打開；也可以在 App 裡按「掃碼入團」。',
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
      g_2: '已经安装 App：用手机相机扫二维码会直接打开；也可以在 App 里按“扫码入团”。',
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
      g_2: 'Already installed? Scanning the QR code with your camera opens the app. You can also tap "Scan to join" in the app.',
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
      g_2: 'インストール済みなら、カメラでQRコードをスキャンするとアプリが開きます。アプリ内の「スキャンして参加」でも参加できます。',
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
      g_2: '이미 설치했다면 카메라로 QR 코드를 스캔하면 앱이 열려요. 앱에서 "스캔해서 참가"를 눌러도 돼요.',
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
      g_2: 'Sudah dipasang? Imbas kod QR dengan kamera untuk membuka aplikasi, atau ketik "Imbas untuk sertai" dalam aplikasi.',
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
      g_2: 'Sudah terpasang? Pindai kode QR dengan kamera untuk membuka aplikasi, atau ketuk "Pindai untuk bergabung" di aplikasi.',
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
      g_2: 'Đã cài ứng dụng? Quét mã QR bằng camera để mở ứng dụng, hoặc chạm "Quét để tham gia" trong ứng dụng.',
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
      g_2: 'ติดตั้งแอปแล้ว? สแกน QR code ด้วยกล้องเพื่อเปิดแอป หรือแตะ "สแกนเพื่อเข้าร่วม" ในแอป',
      v_title: 'คูปอง TourChip',
      v_h: 'คูปอง <b>Tour</b>Chip',
      v_1: 'คูปองจากบริษัททัวร์ (บัตรเพิ่มจำนวนคนหรือบัตรเพิ่มวัน) หลังสร้างกลุ่มแล้ว หัวหน้าสแกนที่ "บัตร → สแกนคูปอง"',
      v_open: 'เปิด TourChip เพื่อใช้'
    }
  };

  // 其他頁面（例如首頁）的字串放在 window.TC_I18N，載入 i18n.js 之前先定義
  var X = window.TC_I18N || {};
  for (var L in X) { if (!T[L]) T[L] = {}; for (var k in X[L]) T[L][k] = X[L][k]; }

  var NAMES = { 'zh-Hant': '繁體中文', 'zh-Hans': '简体中文', en: 'English', ja: '日本語', ko: '한국어', ms: 'Bahasa Melayu', id: 'Bahasa Indonesia', vi: 'Tiếng Việt', th: 'ไทย' };

  function norm(tag) {
    tag = String(tag || '').toLowerCase().replace(/_/g, '-');
    var p = tag.split('-');
    if (p[0] === 'zh') return /hans|cn|sg|my/.test(tag) ? 'zh-Hans' : 'zh-Hant';
    if (p[0] === 'in') return 'id';
    return T[p[0]] ? p[0] : null;
  }

  function pick() {
    // 1. 網址 ?lang=ja  2. 上次手動選的語言  3. 瀏覽器語言  4. 英文
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
    // 截圖：中文看中文版，其他語言看英文版
    var shots = document.querySelectorAll('img[data-shot]');
    for (var m = 0; m < shots.length; m++) shots[m].src = '/img/shots/' + (lang.indexOf('zh') === 0 ? 'zh' : 'en') + '/' + shots[m].getAttribute('data-shot') + '.webp';
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
    });
  }
})();
