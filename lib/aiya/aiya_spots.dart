import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';
import '../map/tour_map.dart';
import '../tour/model.dart';
import '../screens/join.dart';
import '../ui/night.dart';
import 'aiya_screen.dart';
import 'aiya_store.dart';

/// 靠近景點時艾婭介紹：App 開著、走到行程表上某個集合點 200 公尺內，地圖上方冒出小卡片問要不要聽。
/// 位置只在手機上比對；送給伺服器的只有景點名稱和景點座標（行程的地點，不是你的位置）。
/// 每個景點只問一次；設定裡可以關掉。
class AiyaSpots {
  static const _onKey = 'aiya_spot_on', _seenKey = 'aiya_spot_seen';
  static const radiusM = 200.0;
  static final on = ValueNotifier<bool>(true);
  static Set<String> _seen = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    on.value = p.getBool(_onKey) ?? true;
    _seen = (p.getStringList(_seenKey) ?? const []).toSet();
  }

  static Future<void> setOn(bool v) async {
    on.value = v;
    (await SharedPreferences.getInstance()).setBool(_onKey, v);
  }

  static String _id(TourGroup g, TourStop s) => '${g.code}:${s.id}';
  static bool seen(TourGroup g, TourStop s) => _seen.contains(_id(g, s));
  static Future<void> markSeen(TourGroup g, TourStop s) async {
    _seen.add(_id(g, s));
    final list = _seen.toList();
    (await SharedPreferences.getInstance()).setStringList(_seenKey, list.length > 300 ? list.sublist(list.length - 300) : list);
  }

  /// 最近的、還沒問過的景點（前後 12 小時內的行程，200 公尺內）
  static TourStop? nearest(TourGroup g, double lat, double lng) {
    final now = DateTime.now().millisecondsSinceEpoch;
    TourStop? best;
    var bestD = radiusM;
    for (final s in g.stops) {
      if (s.lat == null || s.lng == null || s.place.trim().isEmpty) continue;
      if ((s.at - now).abs() > 12 * 3600 * 1000 || seen(g, s)) continue;
      final d = Geolocator.distanceBetween(lat, lng, s.lat!, s.lng!);
      if (d <= bestD) { bestD = d; best = s; }
    }
    return best;
  }
}

const _ttsLocales = {
  'zh-Hant': 'zh-TW', 'zh-Hans': 'zh-CN', 'en': 'en-US', 'ja': 'ja-JP', 'ko': 'ko-KR', 'ms': 'ms-MY',
  'id': 'id-ID', 'vi': 'vi-VN', 'th': 'th-TH', 'pt': 'pt-BR', 'es': 'es-MX', 'hi': 'hi-IN',
};

/// 團的地圖上方：靠近景點時的艾婭小卡片
class AiyaSpotPrompt extends StatefulWidget {
  final TourGroup g;
  const AiyaSpotPrompt({super.key, required this.g});
  @override
  State<AiyaSpotPrompt> createState() => _AiyaSpotPromptState();
}

class _AiyaSpotPromptState extends State<AiyaSpotPrompt> {
  StreamSubscription<Position>? _sub;
  TourStop? _stop;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    AiyaSpots.load().then((_) => _sync());
    AiyaSpots.on.addListener(_sync);
    TourMapState.paused.addListener(_sync);
  }

  @override
  void dispose() {
    AiyaSpots.on.removeListener(_sync);
    TourMapState.paused.removeListener(_sync);
    _sub?.cancel();
    super.dispose();
  }

  /// 只在開關打開、地圖在前景、已經有位置權限時才聽位置（不主動跳權限詢問）
  Future<void> _sync() async {
    final want = AiyaSpots.on.value && !TourMapState.paused.value && widget.g.stops.any((s) => s.lat != null);
    if (!want) {
      await _sub?.cancel();
      _sub = null;
      if (mounted && _stop != null && !_loading) setState(() => _stop = null);
      return;
    }
    if (_sub != null) return;
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.whileInUse && perm != LocationPermission.always) return;
    if (!mounted || _sub != null) return;
    _sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25)).listen((p) {
      if (!mounted || _loading) return;
      final s = AiyaSpots.nearest(widget.g, p.latitude, p.longitude);
      if (s?.id != _stop?.id) setState(() => _stop = s);
    }, onError: (_) {});
  }

  Future<void> _dismiss() async {
    final s = _stop;
    if (s == null) return;
    setState(() => _stop = null);
    await AiyaSpots.markSeen(widget.g, s);
  }

  Future<void> _listen() async {
    final s = _stop;
    if (s == null || _loading) return;
    setState(() => _loading = true);
    var r = await aiyaCall('spot', {'place': s.place, 'lat': s.lat, 'lng': s.lng});
    if (r['code'] == 'consent' && mounted) {
      if (await askAiyaConsent(context)) {
        await aiyaCall('consent');
        r = await aiyaCall('spot', {'place': s.place, 'lat': s.lat, 'lng': s.lng});
      } else {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (r['success'] != true) {
      showGlassToast(context, switch ('${r['code']}') {
        'spot_max' => tx('今天的景點介紹已經聽滿了，明天再來。', 'That\'s all the sight intros for today. More tomorrow.'),
        _ => tx('艾婭現在有點忙，等一下再試。', 'AIYA is busy right now. Try again soon.'),
      }, icon: Icons.auto_awesome);
      return;
    }
    await _dismiss();
    if (!mounted) return;
    if (r['known'] != true) {
      showGlassToast(context, tx('艾婭對這裡不太熟，有問題可以直接問她。', 'AIYA doesn\'t know much about this spot. Ask her anything.'), icon: Icons.auto_awesome);
      return;
    }
    final title = '${r['title']}'.trim().isEmpty ? s.place : '${r['title']}';
    await showSpotIntro(context, title, '${r['intro']}');
  }

  @override
  Widget build(BuildContext context) {
    final s = _stop;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: s == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(s.id),
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              decoration: BoxDecoration(color: Night.mapGlass, borderRadius: BorderRadius.circular(Night.radiusMd), border: Border.all(color: const Color(0x66FFC861))),
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFFFC861), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tx('「${s.place}」就在附近，要聽艾婭介紹嗎？', '${s.place} is nearby. Hear AIYA\'s intro?'),
                      style: const TextStyle(color: Night.ink, fontSize: 14, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                TextButton(
                  onPressed: _loading ? null : _listen,
                  child: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC861)))
                      : Text(tx('聽介紹', 'Listen'), style: const TextStyle(color: Color(0xFFFFC861), fontWeight: FontWeight.w600)),
                ),
                IconButton(tooltip: tx('不用了', 'No thanks'), visualDensity: VisualDensity.compact, onPressed: _loading ? null : _dismiss, icon: const Icon(Icons.close, color: Night.inkMuted, size: 20)),
              ]),
            ),
    );
  }
}

/// 景點介紹卡：文字、念給我聽（手機內建語音，不另外收費）、問艾婭更多
Future<void> showSpotIntro(BuildContext context, String title, String intro) async {
  final tts = FlutterTts();
  final speaking = ValueNotifier<bool>(false);
  tts.setCompletionHandler(() => speaking.value = false);
  tts.setCancelHandler(() => speaking.value = false);
  Future<void> toggle() async {
    if (speaking.value) {
      await tts.stop();
      speaking.value = false;
      return;
    }
    try {
      await tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [IosTextToSpeechAudioCategoryOptions.duckOthers]);
      await tts.setLanguage(_ttsLocales[langTag] ?? 'en-US');
      await tts.setSpeechRate(0.48);
      speaking.value = true;
      await tts.speak(intro);
    } catch (_) {
      speaking.value = false;
    }
  }

  final more = await showModalBottomSheet<bool>(
    context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Night.space4),
        child: SolidCard(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFFFC861), size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: Night.title)),
            ]),
            const SizedBox(height: Night.space3),
            Flexible(child: SingleChildScrollView(child: Text(intro, style: const TextStyle(color: Night.ink, fontSize: 16, height: 1.6)))),
            const SizedBox(height: Night.space2),
            Text(tx('艾婭是 AI，可能會出錯。', 'AIYA is an AI and can be wrong.'), style: Night.caption),
            const SizedBox(height: Night.space4),
            ValueListenableBuilder<bool>(
              valueListenable: speaking,
              builder: (context, on, _) => NightButton(on ? tx('停止', 'Stop') : tx('念給我聽', 'Read it to me'), icon: on ? Icons.stop_rounded : Icons.volume_up_outlined, onPressed: toggle),
            ),
            const SizedBox(height: Night.space2),
            NightButton(tx('問艾婭更多', 'Ask AIYA more'), kind: NightButtonKind.ghost, icon: Icons.chat_bubble_outline, onPressed: () => Navigator.pop(ctx, true)),
          ]),
        ),
      ),
    ),
  );
  await tts.stop();
  speaking.dispose();
  if (more == true && context.mounted) await openAiya(context);
}
