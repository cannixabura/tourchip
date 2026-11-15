import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../aiya/aiya_spots.dart';
import '../l10n.dart';
import '../tour/model.dart';
import '../tour/nav.dart';
import '../tour/profile.dart';
import '../tour/service.dart';
import '../ui/avatar.dart';
import '../ui/night.dart';
import 'join.dart';
import 'pass_screen.dart';
import 'social.dart';
import 'thanks.dart';

const _site = 'https://tourchip.web.app';
const _contact = 'service.softchip@gmail.com';

/// 右下角的設定按鈕（首頁、團的畫面都有）
class SettingsButton extends StatelessWidget {
  final Color fill;
  const SettingsButton({super.key, this.fill = Night.glassFill});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      shape: const CircleBorder(side: BorderSide(color: Night.glassLine)),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showSettings(context),
        child: SizedBox(
          width: 52, height: 52,
          child: Icon(Icons.settings_outlined, color: Night.ink, semanticLabel: tx('設定', 'Settings')),
        ),
      ),
    );
  }
}

/// 設定：大頭貼、暱稱、語言；旅行社買團購券；操作說明、使用條款、隱私權政策、聯絡我們
Future<void> showSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Night.space4),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.86),
          child: SolidCard(padding: const EdgeInsets.fromLTRB(Night.space4, Night.space4, Night.space4, Night.space2), child: const _SettingsBody()),
        ),
      ),
    ),
  );
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();
  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  @override
  Widget build(BuildContext context) {
    Widget section(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(Night.space2, Night.space4, 0, Night.space1),
          child: Text(t, style: Night.caption.copyWith(color: Night.inkMuted)),
        );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(tx('設定', 'Settings'), closeTooltip: tx('關閉', 'Close')),
      Flexible(
        child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
          section(tx('我', 'Me')),
          ValueListenableBuilder<MyProfile>(
            valueListenable: ProfileStore.me,
            builder: (context, p, _) => _Row(
              leading: Avatar(p.avatar, size: 36),
              title: tx('編輯個人資料', 'Edit profile'),
              subtitle: p.name.isEmpty ? tx('大頭貼與暱稱，領隊點名時看得到', 'Photo and nickname your leader sees') : p.name,
              onTap: () => editProfile(context),
            ),
          ),
          _Row(
            icon: Icons.local_florist_outlined,
            title: tx('我的名片與感謝', 'My card and thanks'),
            subtitle: tx('帶團收到的花與感謝；可以開公開名片', 'Flowers and thanks from your trips; optional public card'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderCardScreen())),
          ),
          // 城市低語的介紹卡（所有人都看得到；年齡由 App Store、Google Play 與城市低語自己把關）。只打開商店頁，不傳任何帳號或團的資料
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Night.space2, vertical: Night.space2),
            child: Material(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => openLink(context, Platform.isIOS
                    ? 'https://apps.apple.com/app/id6820145668'
                    : 'https://play.google.com/store/apps/details?id=com.softchip.moodwhisper'),
                child: Padding(
                  padding: const EdgeInsets.all(Night.space3),
                  child: Row(children: [
                    const Icon(Icons.nightlife_outlined, color: Night.ink, size: 26),
                    const SizedBox(width: Night.space3),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tx('想認識在地人？', 'Want to meet locals?'), style: Night.caption.copyWith(color: Night.ink, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(tx('「城市低語」是我們的另一個 App：在夜光城市地圖上留下此刻的心情，和附近的人打招呼。限 18 歲以上。',
                          'Mood Whisper is our other app: share your mood on a glowing city map and say hi to people nearby. 18+ only.'),
                          style: Night.caption.copyWith(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(Platform.isIOS ? tx('去 App Store 看看', 'See it on the App Store') : tx('去 Google Play 看看', 'See it on Google Play'),
                          style: Night.caption.copyWith(fontSize: 12, decoration: TextDecoration.underline)),
                    ])),
                    const Icon(Icons.open_in_new, color: Night.ink, size: 16),
                  ]),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TourGroup?>(
            valueListenable: TourService.current,
            builder: (context, g, _) => g == null
                ? const SizedBox.shrink()
                : _SwitchRow(
                    icon: Icons.share_location_outlined,
                    title: tx('和團員互相看得到', 'Share location with my group'),
                    subtitle: g.shareOn
                        ? tx('同團的人在地圖上看得到你；關掉後立刻消失', 'Your group sees you on the map. Turn off to disappear right away.')
                        : tx('關著：同團的人看不到你的位置', 'Off: your group cannot see your location'),
                    value: g.shareOn,
                    onChanged: (on) async {
                      if (on && !g.shareConsent) {
                        await askShareConsent(context);
                        return;
                      }
                      final r = await TourService.setShare(on);
                      if (r['success'] != true && context.mounted) showGlassToast(context, tourError('${r['code']}'), danger: true);
                    },
                  ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AiyaSpots.on,
            builder: (context, on, _) => _SwitchRow(
              icon: Icons.auto_awesome_outlined,
              title: tx('靠近景點時艾婭提醒', 'AIYA at nearby sights'),
              subtitle: tx('走到行程上的景點附近，問你要不要聽一分鐘介紹', 'Near a sight on the itinerary, AIYA offers a one-minute intro'),
              value: on,
              onChanged: AiyaSpots.setOn,
            ),
          ),
          _Row(
            icon: Icons.translate,
            title: tx('語言', 'Language'),
            subtitle: langLabel,
            onTap: () async {
              await pickLanguage(context);
              if (mounted) setState(() {});
            },
          ),
          section(tx('旅行社', 'Agencies')),
          _Row(
            icon: Icons.confirmation_number_outlined,
            title: tx('購買團購券', 'Buy group passes'),
            subtitle: tx('買來發給領隊，掃碼就能升級到 100 人', 'Give leaders a QR code to upgrade to 100 people'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PassScreen())),
          ),
          section(tx('關於', 'About')),
          _Row(
            icon: Icons.menu_book_outlined,
            title: tx('操作說明', 'How to use'),
            subtitle: tx('從開團、集合到點名，一次看懂', 'From starting a group to roll call'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
          _Row(icon: Icons.description_outlined, title: tx('使用條款', 'Terms of use'), onTap: () => _open('$_site/terms')),
          _Row(icon: Icons.privacy_tip_outlined, title: tx('隱私權政策', 'Privacy policy'), onTap: () => _open('$_site/privacy')),
          _Row(
            icon: Icons.mail_outline,
            title: tx('聯絡我們', 'Contact us'),
            subtitle: _contact,
            onTap: () => _open('mailto:$_contact?subject=${Uri.encodeComponent(tx('旅行團意見回饋', 'TourChip feedback'))}'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Night.space4),
            child: Text(tx('旅行團 TourChip · 20 人以內免費 · 團員永遠免費', 'TourChip · Free up to 20 · Always free for members'), style: Night.caption, textAlign: TextAlign.center),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _open(String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: url.startsWith('mailto:') ? LaunchMode.externalApplication : LaunchMode.inAppBrowserView);
      if (!ok && mounted) showGlassToast(context, url, icon: Icons.link);
    } catch (_) {
      if (mounted) showGlassToast(context, url, icon: Icons.link);
    }
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Night.space2, vertical: Night.space3),
      child: Row(children: [
        SizedBox(width: 36, child: Center(child: Icon(icon, color: Night.ink, size: 24))),
        const SizedBox(width: Night.space4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Night.ink, fontSize: 17, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(subtitle, style: Night.caption.copyWith(color: Night.inkMuted, fontSize: 13)),
          ]),
        ),
        Switch(value: value, onChanged: onChanged, activeTrackColor: Night.deepViolet),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _Row({this.icon, this.leading, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Night.radiusMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Night.space2, vertical: Night.space3),
        child: Row(children: [
          SizedBox(width: 36, child: Center(child: leading ?? Icon(icon, color: Night.ink, size: 24))),
          const SizedBox(width: Night.space4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Night.ink, fontSize: 17, fontWeight: FontWeight.w500)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Night.caption.copyWith(color: Night.inkMuted, fontSize: 13)),
              ],
            ]),
          ),
          const Icon(Icons.chevron_right, color: Night.inkFaint),
        ]),
      ),
    );
  }
}

/// 編輯個人資料：大頭貼（相簿選一張）＋暱稱（10 字）
Future<void> editProfile(BuildContext context) {
  final p = ProfileStore.me.value;
  final name = TextEditingController(text: p.name);
  File? photo;
  var remove = false, busy = false;
  return showPanel<void>(context, (ctx, setS) {
    final shown = remove ? '' : p.avatar;
    Future<void> pick() async {
      try {
        final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
        if (x != null) setS(() { photo = File(x.path); remove = false; });
      } catch (_) {}
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tx('編輯個人資料', 'Edit profile'), style: Night.title, textAlign: TextAlign.center),
      const SizedBox(height: Night.space4),
      Center(
        child: GestureDetector(
          onTap: busy ? null : pick,
          child: Stack(children: [
            photo != null
                ? Container(
                    width: 104, height: 104, padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Night.auroraViolet, boxShadow: [Night.glowViolet]),
                    child: ClipOval(child: Image.file(photo!, fit: BoxFit.cover)),
                  )
                : Avatar(shown, size: 104),
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: Night.deepGradient, border: Border.all(color: Night.night900, width: 2)),
                child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: Night.space2),
      Text(tx('輕觸更換大頭貼', 'Tap to change your photo'), style: Night.caption, textAlign: TextAlign.center),
      if (photo != null || shown.isNotEmpty)
        Center(
          child: TextButton(
            onPressed: busy ? null : () => setS(() { photo = null; remove = true; }),
            style: TextButton.styleFrom(foregroundColor: Night.inkFaint),
            child: Text(tx('移除大頭貼', 'Remove photo')),
          ),
        ),
      const SizedBox(height: Night.space3),
      TextField(
        controller: name,
        maxLength: ProfileStore.maxName,
        style: const TextStyle(color: Night.ink, fontSize: 17),
        decoration: InputDecoration(labelText: tx('暱稱', 'Nickname'), hintText: tx('領隊和團員看到的名字', 'The name your group sees')),
      ),
      const SizedBox(height: Night.space3),
      Row(children: [
        Expanded(child: NightButton(tx('取消', 'Cancel'), kind: NightButtonKind.ghost, onPressed: busy ? null : () => Navigator.pop(ctx))),
        const SizedBox(width: Night.space3),
        Expanded(
          child: NightButton(busy ? tx('儲存中…', 'Saving…') : tx('儲存', 'Save'), onPressed: busy ? null : () async {
            setS(() => busy = true);
            final err = await ProfileStore.save(name: name.text, photo: photo, removePhoto: remove);
            if (!ctx.mounted) return;
            setS(() => busy = false);
            if (err == null) {
              Navigator.pop(ctx);
            } else {
              showGlassToast(ctx, err == 'upload' ? tx('照片上傳失敗，請再試一次', "Couldn't upload the photo. Please try again.") : tourError(err), danger: true);
            }
          }),
        ),
      ]),
    ]);
  });
}

/// 語言：跟隨手機或 9 種語言其中之一
Future<void> pickLanguage(BuildContext context) {
  return showPanel<void>(context, (ctx, setS) {
    Widget option(String value, String label) {
      final on = appLang.value == value;
      return InkWell(
        borderRadius: BorderRadius.circular(Night.radiusMd),
        onTap: () async {
          Navigator.pop(ctx);
          await setLang(value);
          TourService.refresh(); // 讓伺服器記下新的語言（推播、錯誤訊息）
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Night.space2, vertical: Night.space3),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: on ? Night.ink : Night.inkMuted, fontSize: 17))),
            if (on) const Icon(Icons.check, color: Night.auroraBlue),
          ]),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tx('語言', 'Language'), style: Night.title, textAlign: TextAlign.center),
      const SizedBox(height: Night.space3),
      option('system', tx('跟隨手機設定', 'Same as phone')),
      for (final l in supportedLangs) option(l, langNames[l]!),
    ]);
  });
}

/// 操作說明
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget block(IconData icon, String title, List<String> lines) => Padding(
          padding: const EdgeInsets.only(bottom: Night.space4),
          child: GlassCard(
            padding: const EdgeInsets.all(Night.space4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: Night.auroraBlue, size: 22),
                const SizedBox(width: Night.space2),
                Expanded(child: Text(title, style: Night.title.copyWith(fontSize: 18))),
              ]),
              const SizedBox(height: Night.space2),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(top: Night.space1),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 9, right: 8), child: CircleAvatar(radius: 2.5, backgroundColor: Night.inkFaint)),
                    Expanded(child: Text(l, style: Night.body)),
                  ]),
                ),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(backgroundColor: Night.night900, foregroundColor: Night.ink, title: Text(tx('操作說明', 'How to use'))),
      body: ListView(padding: const EdgeInsets.all(Night.space4), children: [
        block(Icons.flag_outlined, tx('領隊：開團', 'Leaders: start a group'), [
          tx('首頁按「開一個團」，填團名、選團色、出發日和天數，可以分組（例如 1 號車、2 號車）。出發前就能先開團讓團員入團。', 'Tap "Start a group", set a name, color, start date and length. You can add sub-groups such as Bus 1 and Bus 2, and set it up before departure.'),
          tx('出示 QR code，團員用 App 或手機相機掃一下就入團。', 'Show the QR code. Members scan it with the app or their camera to join.'),
          tx('還沒裝 App 的人掃碼後會先去下載，裝好打開就自動入團；已經有 App 的人也可以按「輸入邀請碼入團」，輸入 QR code 下面的 8 位數邀請碼。', 'People without the app are taken to download it and join as soon as they open it. Anyone with the app can also tap "Join with invite code" and enter the 8-digit code under the QR code.'),
          tx('按「換新 QR code」後，舊的 QR code、連結和邀請碼立刻失效，已經入團的人不受影響。', 'After "New QR code", the old QR code, link and invite code stop working. People already in the group stay in.'),
          tx('按「艾婭匯入」貼上旅行社的行程表或分房表，艾婭會整理出每天的飯店（Wi-Fi、早餐）、集合時間地點和房號，勾選後存進來；每團可以匯入 5 次，不扣艾婭聊天次數。', 'Tap "Import with AIYA" and paste the agency itinerary or rooming list. AIYA picks out each day\'s hotel (Wi-Fi, breakfast), meetup times and places, and room numbers for you to save. 5 imports per group; they don\'t use your AIYA chats.'),
          tx('20 人、3 天以內免費。人數券讓一團最多 100 人；天數券每張多 7 天，最長 30 天；也可以用旅行社的團購券。', 'Free for 20 people and 3 days. A group-size pass allows 100 people; each day pass adds 7 days (up to 30). Agency vouchers work too.'),
        ]),
        block(Icons.manage_accounts_outlined, tx('領隊：共同團主、公告、分組', 'Leaders: co-leaders, notices and sub-groups'), [
          tx('在名單裡可以設最多 2 位共同團主，他們也能發集合、點名、公告和投票；只有團主能升級、交棒和解散。', 'In the member list you can add up to 2 co-leaders. They can also call meetups, take roll call, post notices and run polls. Only the leader can upgrade, hand over or end the group.'),
          tx('公告會置頂在團員的畫面，也會用推播送達；團員可以點一下翻譯成自己的語言。', 'Notices are pinned on members\' screens and sent as notifications. Members can tap to translate them into their language.'),
          tx('集合、點名、公告和投票都可以只發給其中一組，例如只叫 2 號車。', 'Meetups, roll calls, notices and polls can go to just one sub-group, such as Bus 2.'),
        ]),
        block(Icons.place_outlined, tx('發集合', 'Call a meetup'), [
          tx('拖曳地圖把旗子放在集合點，選時間後送出，全團手機都會響專屬提示音。', 'Drag the map to place the flag, pick a time and send. Every phone plays the meetup sound.'),
          tx('沒按「收到」的人每分鐘再響一次，最多 3 次；也可以只叫某一組或單獨呼叫一個人。', 'Anyone who has not tapped "Got it" is reminded every minute, up to 3 times. You can call one sub-group or one person.'),
          tx('自由活動可以排到 12 小時後集合；集合前 15 分鐘全團會再響一次。', 'Free time can run up to 12 hours. Everyone is reminded 15 minutes before.'),
          tx('集合卡片上按「用地圖帶我走過去」，可以用 Apple 地圖或 Google 地圖步行導航。', 'Tap "Walk me there with Maps" on the card for walking directions in Apple Maps or Google Maps.'),
          tx('有集合時，鎖定畫面會顯示集合時間和倒數（iPhone 的即時動態、Android 的通知），不用打開 App 也看得到。', 'During a meetup, the lock screen shows the time and countdown (a Live Activity on iPhone, a notification on Android), so you don\'t need to open the app.'),
          tx('來不及的話按「我會晚到」，選晚 3、5 或 10 分鐘並寫原因，領隊的名單上馬上看得到。', 'Running late? Tap "I\'ll be late", choose 3, 5 or 10 minutes and add a reason. Your leader sees it right away in the list.'),
        ]),
        block(Icons.how_to_reg_outlined, tx('點名', 'Roll call'), [
          tx('團員可以回「我到了」「還要 5 分鐘」「需要幫忙」，需要幫忙的人排在最上面。', 'Members answer "I\'m here", "5 more minutes" or "I need help". Those who need help are listed first.'),
          tx('到點自動點名：有分享位置的團員走到集合點附近，會自動算「到了」，領隊只要看還沒到的人。', 'Auto check-in: members who share their location are marked as arrived when they reach the meetup, so leaders only need to look at who is missing.'),
          tx('看到沒回應的人（例如沒帶手機的長輩、小孩），按名單右邊的勾幫他點到。', 'For someone without a reply (say, a child or an older traveler without a phone), tap the check mark next to their name.'),
          tx('脫隊預警：大部分人跟著領隊走時，如果有人離領隊超過 250 公尺持續 3 分鐘，團主、共同團主和本人都會收到提醒。', 'Stray alerts: while most of the group is with the leader, anyone more than 250 m away for 3 minutes is flagged to the leaders and gets a reminder too.'),
        ]),
        block(Icons.explore_outlined, tx('團員：找到集合點', 'Members: find the meetup'), [
          tx('3D 地圖會跟著手機轉，團色的旗子就是集合點；卡片上有當地時間、倒數、距離與方向。', 'The 3D map turns with your phone. The flag in your group color is the meetup; the card shows local time, countdown, distance and direction.'),
          tx('點地圖上的旗子，可以隨時打開集合卡片：時間、地點、倒數、距離方向和導航。', 'Tap the flag on the map any time to open the meetup card: time, place, countdown, distance, direction and directions.'),
          tx('兩指縮放地圖；看別的地方後按「回到我的位置」回來。', 'Pinch to zoom. After looking elsewhere, tap "Back to me".'),
          tx('人多找不到人時按「舉起團旗」，整個螢幕變成團色閃爍並顯示你的團號，舉起手機讓領隊看到。', 'In a crowd, tap "Raise flag". Your screen flashes in the group color with your number, so hold it up for your leader.'),
        ]),
        block(Icons.people_alt_outlined, tx('和團員互相看得到', 'See your group on the map'), [
          tx('同意分享後，同一團的人（含領隊）會在 3D 地圖上看到彼此的大頭貼和位置；不在團裡的人看不到任何人。', 'After you agree to share, everyone in your group, including leaders, sees each other on the 3D map. People outside the group see no one.'),
          tx('在團裡時位置會持續更新（App 在背景也是），用來提醒脫隊、到集合點自動點名；退團或團解散就刪除。隨時可以在設定關掉。', 'While you are in a group, your location keeps updating, even in the background, for stray alerts and auto check-in. It is deleted when you leave or the group ends. Turn it off any time in Settings.'),
          tx('未滿 18 歲要先取得家長或監護人同意才能分享。', 'Under 18? Ask a parent or guardian before sharing.'),
        ]),
        block(Icons.chat_bubble_outline, tx('氣泡與訊息', 'Bubbles and messages'), [
          tx('在地圖下方「發一個氣泡」，同團的人會在你的大頭貼上方看到（最多 20 字）。', 'Tap "Post a bubble" below the map. Your group sees it above your photo (up to 20 characters).'),
          tx('長按地圖上的人就能傳訊息，對方會收到通知；右上角的訊息按鈕可以看所有對話。', 'Long-press someone on the map to message them. They get a notification. The messages button at the top shows all chats.'),
          tx('在對話右上角可以封鎖或檢舉。團解散後訊息全部刪除。', 'Block or report from the top of a chat. Messages are deleted when the group ends.'),
        ]),
        block(Icons.how_to_vote_outlined, tx('投票・揪伴', 'Polls and meetups'), [
          tx('團主和共同團主可以發起投票，例如要不要參加自費行程、晚餐吃哪一家：2 到 6 個選項，可以複選，也可以只問某一組。', 'Leaders can run polls, such as who wants an optional tour or where to have dinner: 2 to 6 options, multiple choice if you like, or just for one sub-group.'),
          tx('團員收到通知後投票，投完還能改；領隊看得到誰選了什麼，團員只看到票數。', 'Members get a notification, vote and can change their vote. Leaders see who chose what; members see only the totals.'),
          tx('同意分享後可以發揪伴，例如「誰要一起去逛藥妝店？」（最多 40 字），別人按「我也去」你會收到通知。', 'After you agree to share, you can post a meetup like "Who wants to go shopping?" (up to 40 characters). You get a notification when someone taps "I\'m in".'),
          tx('每人同時最多 3 個揪伴，12 小時後自動消失；封鎖的人互相看不到揪伴，不當內容可以檢舉。', 'You can have up to 3 meetups at a time, and they disappear after 12 hours. People you block can\'t see yours and you can\'t see theirs; report anything inappropriate.'),
          tx('入口在地圖下方的「投票・揪伴」，有新項目時會顯示數字。', 'Open them from "Polls and meetups" below the map. A number shows when there is something new.'),
        ]),
        block(Icons.info_outline, tx('車輛、飯店、緊急聯絡', 'Bus, hotel and emergency'), [
          tx('「車輛・飯店・緊急」裡有你坐的車（車牌、司機電話）、今晚的飯店（可以給司機看、導航）、領隊和旅行社電話，以及當地報警和救護電話。', 'The "Bus · Hotel · SOS" page shows your bus, tonight\'s hotel (show the driver or get directions), leader and agency phones, and local emergency numbers.'),
          tx('你的房號和坐哪一台車也在這裡；飯店有 Wi-Fi 名稱、密碼和早餐時間。', 'Your room number and bus are here too, plus the hotel Wi-Fi name, password and breakfast times.'),
          tx('也可以填「我的資料」（飲食禁忌、健康狀況、緊急聯絡人），只有團主和共同團主看得到，退團或解散就刪除。', 'You can add your details (diet, health, emergency contact). Only leaders see them; they are deleted when you leave or the group ends.'),
        ]),
        block(Icons.sos_outlined, tx('我迷路了', "I'm lost"), [
          tx('按「我迷路了」會把你現在的位置傳給團主與共同團主，地圖上出現紅點與團號，30 分鐘後自動刪除。', 'Tapping "I\'m lost" sends your current location to the leaders as a red dot with your number. It is deleted after 30 minutes.'),
          tx('「求助卡」可以拿給當地人看：用當地語言寫著你和旅行團走散了、請打給領隊，以及今晚住的飯店。在「車輛・飯店・緊急」裡打開。', 'Show the "Help card" to a local: it says in their language that you got separated from your tour, asks them to call your leader, and shows tonight\'s hotel. Open it from "Bus · Hotel · SOS".'),
        ]),
        block(Icons.auto_awesome_outlined, tx('艾婭 AI 小助理', 'AIYA, AI assistant'), [
          tx('點右上角的艾婭頭像，可以問行程、集合時間、當地交通和注意事項；艾婭會參考領隊公布的行程，不會看到任何人的位置。', 'Tap AIYA\'s portrait at the top to ask about the itinerary, meetup times, getting around and tips. AIYA reads the itinerary your leader posted and never sees anyone\'s location.'),
          tx('第一次使用要先同意 AI 資料處理；不用艾婭也能正常使用所有帶團功能。', 'You agree to AI data processing the first time. Every group feature works without AIYA.'),
          tx('入團第一天免費：第一次入團（或開團）起 24 小時內，可以和艾婭聊 30 次，不扣每天的免費次數。', 'Your first day is free: for 24 hours after you first join (or create) a group, you get 30 chats with AIYA that don\'t count toward the daily free chats.'),
          tx('按輸入框左邊的相機可以拍照問艾婭：拍景點聽故事、拍菜單幫你翻譯並標出豬肉、牛肉、酒和常見過敏原，招牌、告示也看得懂；一次聊天最多 5 張，照片不會存下來。', 'Tap the camera next to the text box to ask about a photo: a sight for its story, a menu translated with pork, beef, alcohol and common allergens marked, or a sign. Up to 5 photos per chat; photos are not kept.'),
          tx('走到行程上的景點附近，地圖上方會問你要不要聽艾婭的一分鐘介紹，可以念給你聽，不扣聊天次數；設定裡可以關掉。', 'Near a sight on the itinerary, AIYA offers a one-minute intro at the top of the map, read aloud if you like. It doesn\'t use your chats, and you can turn it off in Settings.'),
          tx('每天有 3 次免費文字聊天；想多聊可以買時光包，或訂閱艾婭之友（每天 20 次、每月送 60 分鐘語音通話）。', 'You get 3 free text chats a day. For more, buy a time pack or subscribe to AIYA Friend (20 chats a day and 60 call minutes a month).'),
          tx('語音通話依秒數計時，先扣艾婭之友的贈送時間，再扣通話時間包；通話前會請你同意聲音送去處理，我們不錄音。', 'Voice calls are charged by the second, first from AIYA Friend minutes, then from call time packs. You agree before your first call; calls are not recorded.'),
          tx('艾婭是 AI，可能會出錯；集合時間和地點請以領隊說的為準。', 'AIYA is an AI and can be wrong. Always follow your leader for meetup times and places.'),
        ]),
        block(Icons.event_note_outlined, tx('行程表與解散', 'Itinerary and ending'), [
          tx('行程表的時間都用集合點的當地時區；每個集合點前 15 分鐘會自動提醒。', 'Itinerary times use the local time zone of each meetup. Everyone is reminded 15 minutes before each one.'),
          tx('領隊可以替每一天寫資訊卡：當天說明、今晚的飯店、攻略連結，團員點那一天就看得到。', 'Leaders can write a card for each day: notes, tonight\'s hotel and guide links. Members see it by tapping that day.'),
          tx('每一天上方會顯示集合點一帶的天氣、最低和最高溫、降雨機率，並提醒帶傘或外套（預報最多 16 天）。', 'Each day shows the weather near that day\'s meetups: high and low, chance of rain, and reminders like bringing an umbrella or a jacket (up to 16 days ahead).'),
          tx('最後一天 23:59 團自動解散，名單、點名紀錄全部刪除。', 'The group ends at 23:59 on the last day and the list and roll calls are deleted.'),
        ]),
        block(Icons.local_florist_outlined, tx('送花與旅程回憶卡', 'Flowers and trip memory card'), [
          tx('最後一天起可以送花和一句感謝給領隊；領隊在設定的「我的名片與感謝」看得到，也可以開公開名片網頁，自己挑要公開哪些感謝。', 'From the last day you can send your leader flowers and a thank-you note. Leaders see them in Settings under "My card and thanks" and can open a public card page showing the thanks they pick.'),
          tx('旅程回憶卡把團名、日期、天數和行程表上的集合點做成一張足跡卡，可以存成圖片分享；在選單裡打開，團解散後 14 天內首頁也打得開。', 'The trip memory card turns the group name, dates, days and itinerary meetups into a footprint card you can share as an image. Open it from the menu; for 14 days after the group ends it is also on the home screen.'),
        ]),
      ]),
    );
  }
}
