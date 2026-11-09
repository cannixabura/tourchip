import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../l10n.dart';
import '../tour/model.dart';
import '../tour/profile.dart';
import '../tour/service.dart';
import '../translate.dart';
import '../ui/night.dart';
import 'meet_flag.dart';
import 'person_marker.dart';

/// 城市低語的 3D 夜光地圖（MapLibre＋OpenFreeMap），加上旅行團的圖層：
///   集合點：團色的長桿三角旗（會飄揚）＋地面流動的彩色光圈（MeetFlag，疊在地圖上、跟著集合點的螢幕位置移動）
///   迷路的團員：紅色圓點＋團號（團員自己按「我迷路了」才有，只有團主與共同團主看得到）
///   行程表的集合點：小圓點（行程預覽）
///   同團的人：大頭貼＋氣泡＋稱呼（同意並開著分享的人才看得到；沒入團的人看不到任何人）。長按可以傳訊息
///   自己：大頭貼（在自己的位置；在團裡時帶著自己的氣泡）
///
/// 鏡頭和城市低語一樣跟著手機動：
///   方位跟著羅盤（手機朝哪裡，地圖就轉到哪裡）
///   仰角跟著手機的傾斜（拿直看遠方、平放看正下方）
///   兩指縮放；鏡頭中心是自己的位置（看集合點、迷路的團員時會先飛過去，按「回到我的位置」回來）
/// 選集合點（picking）時改回一般地圖：拖曳、縮放、旋轉都用手指，旗子的光圈對準地圖中央。
const _styleAsset = 'assets/map/night_style.json';

class TourMap extends StatefulWidget {
  /// 不在任何團裡（首頁）時是 null：只有 3D 城市
  final TourGroup? group;
  /// 選集合點：地圖中央出現十字，拖曳地圖決定位置（發集合、行程表用）
  final bool picking;
  /// 進場鏡頭：從城市高空俯衝到街道（首頁第一次打開）
  final bool intro;
  /// 地圖下方被面板蓋住的高度：「回到我的位置」按鈕放在它上面
  final double bottomInset;
  final void Function(MapLibreMapController controller)? onReady;
  /// 長按地圖上的人
  final void Function(TourPerson person)? onPersonLongPress;
  /// 點一下地圖上的人（看氣泡、翻譯、傳訊息）
  final void Function(TourPerson person)? onPersonTap;
  /// 一開始的地圖中心（選點時傳入已選過的點）；沒有就用最近一次的位置
  final LatLng? center;
  const TourMap({super.key, this.group, this.picking = false, this.intro = false, this.bottomInset = 0, this.onReady, this.onPersonLongPress, this.onPersonTap, this.center});

  @override
  State<TourMap> createState() => TourMapState();
}

class TourMapState extends State<TourMap> with SingleTickerProviderStateMixin {
  /// 最近一次取得的手機位置（所有地圖共用）：開新地圖時不用等定位就能先顯示
  static LatLng? lastMe;
  String? _style;
  LatLng? _start;
  MapLibreMapController? _c;
  bool _layersReady = false;
  bool _myLocation = false;

  // 鏡頭（跟城市低語相同的做法）
  LatLng? _me;
  LatLng? _focus; // 不是 null：正在看別的地方（集合點、迷路的團員）
  double _heading = 0, _pitch = 50 * pi / 180, _scale = 1, _baseScale = 1;
  bool _flying = false;
  DateTime _lastMove = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<CompassEvent>? _compass;
  StreamSubscription<AccelerometerEvent>? _tilt;
  StreamSubscription<Position>? _position;
  final Set<String> _images = {};
  (double, double, double)? _lastAccel;
  bool _tiltLive = false;
  bool _peopleBusy = false, _peopleAgain = false;
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  bool get _motion => !widget.picking;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString(_styleAsset).then((s) { if (mounted) setState(() => _style = s); });
    ProfileStore.me.addListener(_syncPeople);
    if (!widget.intro) _fade.value = 1;
    _locate();
    if (_motion) _startSensors();
  }

  @override
  void dispose() {
    _c?.removeListener(_onCamera);
    ProfileStore.me.removeListener(_syncPeople);
    _compass?.cancel();
    _tilt?.cancel();
    _position?.cancel();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final g = widget.group;
    // 先用已知的點立刻顯示地圖，不等定位（定位可能要好幾秒，選點畫面會一直空白）
    final quick = widget.center ?? lastMe ??
        (g?.call != null ? LatLng(g!.call!.lat, g.call!.lng) : null) ??
        g?.stops.where((s) => s.lat != null).map((s) => LatLng(s.lat!, s.lng!)).firstOrNull;
    if (quick != null && mounted) setState(() => _start = quick);
    if (lastMe != null) _me = lastMe;
    LatLng? p;
    final allowed = await ensureLocation();
    if (!mounted) return;
    if (mounted && allowed != _myLocation) setState(() => _myLocation = allowed);
    if (allowed) {
      try {
        final pos = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 8)));
        p = LatLng(pos.latitude, pos.longitude);
        _me = p;
        lastMe = p;
      } catch (_) {}
      if (!mounted) return;
      if (_motion) {
        _position = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)).listen((pos) {
          _me = LatLng(pos.latitude, pos.longitude);
          lastMe = _me;
          _moveCamera();
          _syncPeople();
        }, onError: (_) {});
      }
    }
    // 抓不到位置：先看集合點，再看行程表第一個有座標的點，都沒有就看台北
    if (_start != null) {
      // 地圖已經先開了：跟著手機轉的地圖會自己移到我的位置；選點時沒傳入點，就移到我的位置
      if (widget.picking && widget.center == null && p != null) _c?.animateCamera(CameraUpdate.newLatLng(p));
      _moveCamera(force: true);
      return;
    }
    p ??= g?.call != null ? LatLng(g!.call!.lat, g.call!.lng) : null;
    p ??= g?.stops.where((s) => s.lat != null).map((s) => LatLng(s.lat!, s.lng!)).firstOrNull;
    p ??= const LatLng(25.0478, 121.5170);
    if (mounted) setState(() => _start = p);
  }

  void _startSensors() {
    try {
      _compass = FlutterCompass.events?.listen((e) {
        if (e.heading == null) return;
        _heading = e.heading!;
        _moveCamera();
      }, onError: (_) {});
    } catch (_) {}
    try {
      _tilt = accelerometerEventStream().listen((e) {
        // 真的手機讀數一直在微微跳動；模擬器、少數裝置會一直送同一個固定值。
        // 讀數開始變動之後才跟著傾斜，否則保持預設的 3D 仰角（不要躺平成正上方）
        final first = _lastAccel;
        _lastAccel = (e.x, e.y, e.z);
        if (!_tiltLive) {
          if (first == null || first == _lastAccel) return;
          _tiltLive = true;
        }
        final target = atan2(e.y, e.z).clamp(0.0, 80 * pi / 180);
        _pitch += (target - _pitch) * 0.1;
        _moveCamera();
      }, onError: (_) {});
    } catch (_) {}
  }

  LatLng? get _target => _focus ?? _me ?? _start;
  double get _zoom => 16 + log(_scale) / ln2;
  double get _tiltDeg => (_pitch * 180 / pi).clamp(0.0, 60.0);

  /// 感測器一秒幾十次：最多每 60 毫秒動一次鏡頭
  void _moveCamera({bool force = false}) {
    final c = _c, t = _target;
    if (c == null || t == null || _flying || !_motion) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastMove).inMilliseconds < 60) return;
    _lastMove = now;
    c.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: t, zoom: _zoom, tilt: _tiltDeg, bearing: _heading)), duration: const Duration(milliseconds: 100));
  }

  /// 地圖中央（選集合點時用）
  LatLng? get center => _c?.cameraPosition?.target;

  /// 飛到某個點（集合點、迷路的團員）；跟著手機轉的鏡頭會停在那裡，直到按「回到我的位置」
  Future<void> flyTo(double lat, double lng) async {
    final c = _c;
    if (c == null) return;
    if (_motion) setState(() => _focus = LatLng(lat, lng));
    _flying = true;
    try {
      await c.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lng), zoom: 16.5, tilt: 55, bearing: _heading)), duration: const Duration(milliseconds: 900));
    } catch (_) {}
    _flying = false;
    _scale = pow(2, 0.5).toDouble();
    _pitch = 55 * pi / 180;
  }

  void _backToMe() {
    setState(() => _focus = null);
    _moveCamera(force: true);
  }

  @override
  void didUpdateWidget(covariant TourMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_layersReady) _syncLayers();
  }

  Color get _tint => widget.group?.tint ?? Night.auroraViolet;

  Future<void> _onStyleLoaded() async {
    final c = _c;
    if (c == null || !mounted) return;
    try {
      // 夜色 3D 建築：越高越亮，只有最高的建築帶一點淡紫（與城市低語相同）
      await c.addFillExtrusionLayer('openmaptiles', '3d-buildings', const FillExtrusionLayerProperties(
        fillExtrusionColor: ['interpolate', ['linear'], ['get', 'render_height'], 0, '#181D44', 20, '#22285A', 60, '#2F3570', 150, '#4A3F8C'],
        fillExtrusionHeight: ['get', 'render_height'],
        fillExtrusionBase: ['get', 'render_min_height'],
        fillExtrusionOpacity: 0.72,
      ), sourceLayer: 'building');
    } catch (_) {}
    try {
      const empty = {'type': 'FeatureCollection', 'features': []};
      await c.addGeoJsonSource('tour-stops', empty);
      await c.addGeoJsonSource('tour-lost', empty);
      await c.addCircleLayer('tour-stops', 'tour-stops-dot', const CircleLayerProperties(
        circleRadius: 5, circleColor: '#F3F0FF', circleOpacity: 0.55, circleStrokeColor: '#070B1F', circleStrokeWidth: 1.5, circlePitchAlignment: 'map',
      ));
      await c.addCircleLayer('tour-lost', 'tour-lost-dot', const CircleLayerProperties(
        circleRadius: 9, circleColor: '#FF6B7A', circleStrokeColor: '#070B1F', circleStrokeWidth: 2,
      ));
      await c.addGeoJsonSource('tour-people', empty);
      await c.addSymbolLayer('tour-people', 'tour-people', const SymbolLayerProperties(
        iconImage: ['get', 'icon'], iconAnchor: 'center', iconAllowOverlap: true, iconIgnorePlacement: true,
        iconPitchAlignment: 'viewport', iconRotationAlignment: 'viewport', symbolSortKey: ['get', 'z'],
      ));
      await c.addSymbolLayer('tour-lost', 'tour-lost-label', const SymbolLayerProperties(
        textField: ['get', 'label'], textFont: ['Noto Sans Regular'], textSize: 12, textColor: '#FF6B7A',
        textHaloColor: '#070B1F', textHaloWidth: 1.5, textOffset: [0, 1.6], textAllowOverlap: true,
      ));
      if (!mounted) return;
      _layersReady = true;
      await _syncLayers();
    } catch (_) {}
    if (!mounted) return;
    widget.onReady?.call(c);
    if (widget.intro) {
      _playIntro();
    } else if (_motion) {
      // iOS 不一定套用 initialCameraPosition 的仰角：地圖準備好後主動擺一次 3D 鏡頭
      _moveCamera(force: true);
    }
  }

  /// 進場鏡頭：從城市高空、正上方俯視，2.6 秒俯衝到街道並傾斜成 3D，夜光地圖同時從黑暗中亮起。
  /// 系統開啟「減少動態效果」時直接到位。
  Future<void> _playIntro() async {
    final c = _c, t = _target;
    if (c == null || t == null) return;
    final reduce = MediaQuery.of(context).disableAnimations;
    _flying = true;
    _fade.forward();
    final to = CameraPosition(target: t, zoom: 16, tilt: 50, bearing: _heading);
    try {
      reduce ? await c.moveCamera(CameraUpdate.newCameraPosition(to)) : await c.animateCamera(CameraUpdate.newCameraPosition(to), duration: const Duration(milliseconds: 2600));
    } catch (_) {}
    // 讓仰角從鏡頭的 50° 平順接回感測器
    _pitch = 50 * pi / 180;
    _flying = false;
  }

  Future<void> _syncLayers() async {
    final c = _c;
    if (c == null) return;
    final g = widget.group;
    try {
      await c.setGeoJsonSource('tour-lost', _points([for (final l in g?.lost ?? const <TourLost>[]) (l.lat, l.lng, '${l.no}')]));
      await c.setGeoJsonSource('tour-stops', _points([for (final s in g?.stops ?? const <TourStop>[]) if (s.lat != null) (s.lat!, s.lng!, '')]));
    } catch (_) {}
    _syncPeople();
    _syncFlag();
  }

  /// 集合點在螢幕上的位置（旗子跟著它）；鏡頭一動就重算
  Offset? _flagAt;
  /// 旗子範圍內大家的頭像、氣泡、稱呼（螢幕座標）：從旗子上挖掉，看起來就像人在旗子前面
  List<Rect> _flagHoles = const [];
  bool _flagBusy = false, _flagAgain = false;
  void _onCamera() => _syncFlag();
  Future<void> _syncFlag() async {
    final c = _c, call = widget.group?.call;
    if (c == null || widget.picking) return;
    if (call == null) {
      if (_flagAt != null && mounted) setState(() => _flagAt = null);
      return;
    }
    if (_flagBusy) { _flagAgain = true; return; }
    _flagBusy = true;
    try {
      final shapes = _shapes;
      final pts = await c.toScreenLocationBatch([LatLng(call.lat, call.lng), for (final s in shapes) s.$1]);
      if (!mounted || pts.isEmpty) return;
      final k = Theme.of(context).platform == TargetPlatform.android ? MediaQuery.of(context).devicePixelRatio : 1.0;
      final at = Offset(pts[0].x / k, pts[0].y / k);
      final holes = <Rect>[
        for (var i = 0; i < shapes.length && i + 1 < pts.length; i++) shapes[i].$2.shift(Offset(pts[i + 1].x / k, pts[i + 1].y / k)),
      ];
      setState(() {
        _flagAt = at;
        _flagHoles = holes;
      });
    } catch (_) {
    } finally {
      _flagBusy = false;
      if (_flagAgain && mounted) { _flagAgain = false; _syncFlag(); }
    }
  }

  static String _label(TourPerson p) {
    final base = p.name.isNotEmpty ? p.name : tx('${p.no} 號', 'No. ${p.no}');
    return switch (p.role) { 'host' => tx('團主 $base', 'Leader $base'), 'cohost' => tx('共同團主 $base', 'Co-leader $base'), _ => base };
  }

  static Color _ring(String role) => switch (role) { 'host' => Night.cityAmber, 'cohost' => Night.knockPink, _ => Night.auroraBlue };

  /// 同團的人＋自己：每個人畫成一張圖（內容變了才重畫），再更新圖層
  Future<void> _syncPeople() async {
    final c = _c;
    if (c == null || !_layersReady || widget.picking) return;
    if (_peopleBusy) { _peopleAgain = true; return; }
    _peopleBusy = true;
    try {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final g = widget.group;
      final prof = ProfileStore.me.value;
      final rows = <(String id, double lat, double lng, String label, String bubble, String avatar, Color ring, bool me, int z, bool tr, bool off)>[
        // 灰色（離線）的人排在下面，在線的人蓋在上面
        for (final p in g?.people ?? const <TourPerson>[])
          ('p:${p.uid}', p.lat, p.lng, _label(p), _shownBubble(p) ?? p.bubble, p.avatar, _ring(p.role), false, p.online ? (p.isStaff ? 2 : 1) : 0, _shownBubble(p) != null, !p.online),
        if (_me != null) ('me', _me!.latitude, _me!.longitude, tx('我', 'Me'), g?.myBubble ?? '', prof.avatar, Night.auroraViolet, true, 3, false, false),
      ];
      final features = <Map<String, dynamic>>[];
      final shapes = <(LatLng, Rect)>[];
      for (final r in rows) {
        final sh = PersonMarker.shapes(label: r.$4, bubble: r.$5, translated: r.$10);
        for (final rect in [sh.bubble, sh.avatar, sh.name]) {
          if (rect != null) shapes.add((LatLng(r.$2, r.$3), rect));
        }
        final icon = 'person-${Object.hash(r.$4, r.$5, r.$6, r.$7.toARGB32(), dpr, r.$10, r.$11).toUnsigned(32).toRadixString(16)}';
        if (!_images.contains(icon)) {
          final png = await PersonMarker.render(label: r.$4, bubble: r.$5, avatar: r.$6, ring: r.$7, dpr: dpr, me: r.$8, translated: r.$10, offline: r.$11);
          if (!mounted) return;
          await c.addImage(icon, png);
          _images.add(icon);
        }
        features.add({'type': 'Feature', 'properties': {'icon': icon, 'id': r.$1, 'z': r.$9}, 'geometry': {'type': 'Point', 'coordinates': [r.$3, r.$2]}});
      }
      await c.setGeoJsonSource('tour-people', {'type': 'FeatureCollection', 'features': features});
      _shapes = shapes;
      _syncFlag();
      // 有自己的大頭貼時不再畫系統藍點
      if (mounted && _myLocation && _me != null && !_hideDot) setState(() => _hideDot = true);
    } catch (_) {
    } finally {
      _peopleBusy = false;
      if (_peopleAgain && mounted) { _peopleAgain = false; _syncPeople(); }
    }
  }

  bool _hideDot = false;

  /// 地圖上大家看得到的部分（氣泡、大頭貼、稱呼）：旗子要避開
  List<(LatLng, Rect)> _shapes = const [];

  /// 點一下氣泡翻譯：uid → (原文, 譯文)；原文變了就作廢
  final Map<String, (String, String)> _bubbleTr = {};
  String? _shownBubble(TourPerson p) {
    final t = _bubbleTr[p.uid];
    return t != null && t.$1 == p.bubble ? t.$2 : null;
  }

  Future<void> _toggleBubble(TourPerson p) async {
    if (_shownBubble(p) != null) {
      _bubbleTr.remove(p.uid);
      _syncPeople();
      return;
    }
    final text = p.bubble;
    final can = await ChatTranslator.check(text);
    if (can != TranslateCheck.ok) {
      if (mounted) {
        showGlassToast(context, can == TranslateCheck.same ? tx('這則氣泡已經是你的語言', 'This bubble is already in your language') : tx('這個語言目前無法翻譯', "This language can't be translated yet"), icon: Icons.translate);
      }
      return;
    }
    if (!mounted) return;
    final out = await ChatTranslator.translate(context, text);
    if (!mounted) return;
    if (out == null) {
      showGlassToast(context, tx('目前無法翻譯', "Can't translate right now"), danger: true);
      return;
    }
    _bubbleTr[p.uid] = (text, out);
    _syncPeople();
  }

  /// 點到的是不是某人的氣泡（氣泡在大頭貼上方）
  Future<TourPerson?> _bubbleAt(Offset at) async {
    final c = _c, people = (widget.group?.people ?? const <TourPerson>[]).where((p) => p.bubble.isNotEmpty).toList();
    if (c == null || people.isEmpty) return null;
    try {
      final pts = await c.toScreenLocationBatch([for (final p in people) LatLng(p.lat, p.lng)]);
      if (!mounted) return null;
      final k = Theme.of(context).platform == TargetPlatform.android ? MediaQuery.of(context).devicePixelRatio : 1.0;
      // 後畫的在上面：從最後一個往前找
      for (var i = min(people.length, pts.length) - 1; i >= 0; i--) {
        final p = people[i];
        final b = PersonMarker.shapes(label: _label(p), bubble: _shownBubble(p) ?? p.bubble, translated: _shownBubble(p) != null).bubble;
        if (b != null && b.inflate(6).shift(Offset(pts[i].x / k, pts[i].y / k)).contains(at)) return p;
      }
    } catch (_) {}
    return null;
  }

  /// 長按：找手指附近（44 點以內）最近的人
  Future<void> _longPress(Offset at) async {
    final p = await _personAt(at);
    if (p == null || widget.onPersonLongPress == null) return;
    HapticFeedback.mediumImpact();
    widget.onPersonLongPress!(p);
  }

  Future<void> _tap(Offset at) async {
    final b = await _bubbleAt(at);
    if (b != null) {
      HapticFeedback.selectionClick();
      _toggleBubble(b);
      return;
    }
    final p = await _personAt(at);
    if (p == null || widget.onPersonTap == null) return;
    HapticFeedback.selectionClick();
    widget.onPersonTap!(p);
  }

  Future<TourPerson?> _personAt(Offset at) async {
    final c = _c, people = widget.group?.people ?? const <TourPerson>[];
    if (c == null || people.isEmpty) return null;
    try {
      final pts = await c.toScreenLocationBatch([for (final p in people) LatLng(p.lat, p.lng)]);
      if (!mounted) return null;
      // Android 回傳實體像素，iOS 回傳點
      final k = Theme.of(context).platform == TargetPlatform.android ? MediaQuery.of(context).devicePixelRatio : 1.0;
      TourPerson? best;
      var bestD = 44.0;
      for (var i = 0; i < people.length && i < pts.length; i++) {
        // 大頭貼與氣泡畫在定位點上方，往上 28 點也算點到
        final pt = Offset(pts[i].x / k, pts[i].y / k);
        final d = [(pt - at).distance, (pt.translate(0, -28) - at).distance].reduce((x, y) => x < y ? x : y);
        if (d < bestD) { bestD = d; best = people[i]; }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _points(List<(double, double, String)> pts) => {
        'type': 'FeatureCollection',
        'features': [
          for (final p in pts)
            {'type': 'Feature', 'properties': {'label': p.$3}, 'geometry': {'type': 'Point', 'coordinates': [p.$2, p.$1]}}
        ],
      };

  @override
  Widget build(BuildContext context) {
    if (_style == null || _start == null) return const ColoredBox(color: Night.night900, child: Center(child: CircularProgressIndicator(color: Night.auroraViolet)));
    final map = MapLibreMap(
      styleString: _style!,
      // 進場鏡頭的起點：城市高空、正上方
      initialCameraPosition: widget.intro ? CameraPosition(target: _start!, zoom: 12) : CameraPosition(target: _start!, zoom: 16, tilt: 50),
      onMapCreated: (c) {
        _c = c;
        c.addListener(_onCamera);
      },
      onStyleLoadedCallback: _onStyleLoaded,
      trackCameraPosition: true,
      myLocationEnabled: _myLocation && !_hideDot,
      myLocationRenderMode: MyLocationRenderMode.normal,
      compassEnabled: false,
      // 跟著手機轉時，手指只負責縮放（由外面的手勢處理）
      scrollGesturesEnabled: !_motion,
      rotateGesturesEnabled: !_motion,
      tiltGesturesEnabled: !_motion,
      zoomGesturesEnabled: !_motion,
      logoViewMargins: const Point(-100, -100),
      attributionButtonMargins: const Point(-100, -100),
    );
    return Stack(children: [
      if (_motion)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => _baseScale = _scale,
          onScaleUpdate: (d) {
            _scale = (_baseScale * d.scale).clamp(0.2, 8.0);
            _moveCamera();
          },
          onLongPressStart: (d) => _longPress(d.localPosition),
          onTapUp: (d) => _tap(d.localPosition),
          child: map,
        )
      else
        map,
      // 夜光地圖從黑暗中亮起（進場鏡頭期間）
      IgnorePointer(
        child: AnimatedBuilder(
          animation: _fade,
          builder: (context, _) {
            final v = Curves.easeInOut.transform(_fade.value);
            return v >= 1 ? const SizedBox.shrink() : Container(color: Night.night900.withValues(alpha: 1 - v));
          },
        ),
      ),
      // 集合點的旗子（跟著集合點的螢幕位置；越近越大一點）
      if (!widget.picking && _flagAt != null && widget.group?.call != null)
        Builder(builder: (context) {
          final k = (0.75 + (_zoom - 15) * 0.15).clamp(0.6, 1.2);
          final a = MeetFlag.anchor(k);
          final origin = _flagAt! - a;
          final box = origin & Size(MeetFlag.width * k, MeetFlag.height * k);
          final holes = [for (final h in _flagHoles) if (h.overlaps(box)) h.shift(-origin)];
          final flag = MeetFlag(tint: _tint, scale: k);
          return Positioned(left: origin.dx, top: origin.dy, child: holes.isEmpty ? flag : ClipPath(clipper: _Holes(holes), child: flag));
        }),
      // 地圖資料授權要求的出處標示
      // 放在畫面最底下（手勢列上方），不擋到按鈕
      Positioned(left: 16, bottom: max(2.0, MediaQuery.of(context).padding.bottom - 14), child: const IgnorePointer(child: Text('© OpenMapTiles © OpenStreetMap', style: TextStyle(color: Night.inkFaint, fontSize: 9)))),
      if (_motion && _focus != null)
        Positioned(
          left: 0, right: 0, bottom: widget.bottomInset + Night.space6,
          child: Center(
            child: Material(
              color: Night.glassFill,
              shape: const StadiumBorder(side: BorderSide(color: Night.glassLine)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _backToMe,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.my_location, color: Night.auroraBlue, size: 18),
                    const SizedBox(width: 8),
                    Text(tx('回到我的位置', 'Back to me'), style: const TextStyle(color: Night.ink, fontSize: 14, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      // 選點：旗子的光圈中心對準地圖中央
      if (widget.picking)
        Positioned.fill(child: LayoutBuilder(builder: (context, box) {
          final a = MeetFlag.anchor(1);
          return Stack(children: [Positioned(left: box.maxWidth / 2 - a.dx, top: box.maxHeight / 2 - a.dy, child: MeetFlag(tint: _tint))]);
        })),
    ]);
  }
}

/// 旗子挖洞：整個範圍減掉大家的頭像、氣泡、稱呼
class _Holes extends CustomClipper<Path> {
  final List<Rect> holes;
  _Holes(this.holes);
  @override
  Path getClip(Size size) {
    final cut = Path();
    for (final h in holes) {
      cut.addRRect(RRect.fromRectAndRadius(h, const Radius.circular(12)));
    }
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), cut);
  }
  @override
  bool shouldReclip(_Holes old) => old.holes != holes;
}
