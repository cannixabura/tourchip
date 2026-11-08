import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/profile.dart';
import '../tour/service.dart';
import '../ui/avatar.dart';
import '../ui/night.dart';
import 'join.dart';
import 'pass_screen.dart';
import 'social.dart';

const _site = 'https://tourchip.web.app';
const _contact = 'service.softchip@gmail.com';

/// 右下角的設定按鈕（首頁、團的畫面都有）
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Night.glassFill,
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
          tx('首頁按「開一個團」，填團名、選團色和天數，可以分組（例如 1 號車、2 號車）。', 'Tap "Start a group", set a name, color and number of days. You can add sub-groups such as Bus 1 and Bus 2.'),
          tx('出示 QR code，團員用 App 或手機相機掃一下就入團。', 'Show the QR code. Members scan it with the app or their camera to join.'),
          tx('20 人以內免費；第 21 人起升級 7 天方案或使用團購券，最多 100 人。', 'Free up to 20 people. From the 21st, upgrade to the 7-day pass or use a group pass (up to 100).'),
        ]),
        block(Icons.place_outlined, tx('發集合', 'Call a meetup'), [
          tx('拖曳地圖把光柱放在集合點，選時間後送出，全團手機都會響專屬提示音。', 'Drag the map to place the light pillar, pick a time and send. Every phone plays the meetup sound.'),
          tx('沒按「收到」的人每分鐘再響一次，最多 3 次；也可以只叫某一組或單獨呼叫一個人。', 'Anyone who has not tapped "Got it" is reminded every minute, up to 3 times. You can call one sub-group or one person.'),
        ]),
        block(Icons.how_to_reg_outlined, tx('點名', 'Roll call'), [
          tx('團員可以回「我到了」「還要 5 分鐘」「需要幫忙」，需要幫忙的人排在最上面。', 'Members answer "I\'m here", "5 more minutes" or "I need help". Those who need help are listed first.'),
        ]),
        block(Icons.explore_outlined, tx('團員：找到集合點', 'Members: find the meetup'), [
          tx('3D 地圖會跟著手機轉，光柱就是集合點；卡片上有當地時間、倒數、距離與方向。', 'The 3D map turns with your phone. The light pillar is the meetup; the card shows local time, countdown, distance and direction.'),
          tx('兩指縮放地圖；看別的地方後按「回到我的位置」回來。', 'Pinch to zoom. After looking elsewhere, tap "Back to me".'),
        ]),
        block(Icons.people_alt_outlined, tx('和團員互相看得到', 'See your group on the map'), [
          tx('同意分享後，同一團的人（含領隊）會在 3D 地圖上看到彼此的大頭貼和位置；不在團裡的人看不到任何人。', 'After you agree to share, everyone in your group, including leaders, sees each other on the 3D map. People outside the group see no one.'),
          tx('位置只在 App 開著時更新；退團或團解散就刪除。隨時可以在設定關掉。', 'Location updates only while the app is open and is deleted when you leave or the group ends. Turn it off any time in Settings.'),
          tx('未滿 18 歲要先取得家長或監護人同意才能分享。', 'Under 18? Ask a parent or guardian before sharing.'),
        ]),
        block(Icons.chat_bubble_outline, tx('氣泡與訊息', 'Bubbles and messages'), [
          tx('在地圖下方「發一個氣泡」，同團的人會在你的大頭貼上方看到（最多 20 字）。', 'Tap "Post a bubble" below the map. Your group sees it above your photo (up to 20 characters).'),
          tx('長按地圖上的人就能傳訊息，對方會收到通知；右上角的訊息按鈕可以看所有對話。', 'Long-press someone on the map to message them. They get a notification. The messages button at the top shows all chats.'),
          tx('在對話右上角可以封鎖或檢舉。團解散後訊息全部刪除。', 'Block or report from the top of a chat. Messages are deleted when the group ends.'),
        ]),
        block(Icons.sos_outlined, tx('我迷路了', "I'm lost"), [
          tx('按「我迷路了」會把你現在的位置傳給團主與共同團主，地圖上出現紅點與團號，30 分鐘後自動刪除。', 'Tapping "I\'m lost" sends your current location to the leaders as a red dot with your number. It is deleted after 30 minutes.'),
        ]),
        block(Icons.event_note_outlined, tx('行程表與解散', 'Itinerary and ending'), [
          tx('行程表的時間都用集合點的當地時區。', 'Itinerary times use the local time zone of each meetup.'),
          tx('最後一天 23:59 團自動解散，名單、點名紀錄全部刪除。', 'The group ends at 23:59 on the last day and the list and roll calls are deleted.'),
        ]),
      ]),
    );
  }
}
