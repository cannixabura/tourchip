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
import '../tour/service.dart';
import '../ui/night.dart';

/// 城市低語的 3D 夜光地圖（MapLibre＋OpenFreeMap），加上旅行團的圖層：
///   集合點光柱：團色的 3D 柱子（fill-extrusion，真的立在建築之間）＋地面光環
///   迷路的團員：紅色圓點＋團號（團員自己按「我迷路了」才有，只有團主與共同團主看得到）
///   行程表的集合點：小圓點（行程預覽）
/// 團員的位置不會出現在這張地圖上；自己的位置是系統藍點，只在自己的手機上。
///
/// 鏡頭和城市低語一樣跟著手機動：
///   方位跟著羅盤（手機朝哪裡，地圖就轉到哪裡）
///   仰角跟著手機的傾斜（拿直看遠方、平放看正下方）
///   兩指縮放；鏡頭中心是自己的位置（看集合點、迷路的團員時會先飛過去，按「回到我的位置」回來）
/// 選集合點（picking）時改回一般地圖：拖曳、縮放、旋轉都用手指，十字光柱對準地圖中央。
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
  const TourMap({super.key, this.group, this.picking = false, this.intro = false, this.bottomInset = 0, this.onReady});

  @override
  State<TourMap> createState() => TourMapState();
}

class TourMapState extends State<TourMap> with SingleTickerProviderStateMixin {
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
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  bool get _motion => !widget.picking;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString(_styleAsset).then((s) { if (mounted) setState(() => _style = s); });
    if (!widget.intro) _fade.value = 1;
    _locate();
    if (_motion) _startSensors();
  }

  @override
  void dispose() {
    _compass?.cancel();
    _tilt?.cancel();
    _position?.cancel();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final g = widget.group;
    LatLng? p;
    final allowed = await ensureLocation();
    if (mounted && allowed != _myLocation) setState(() => _myLocation = allowed);
    if (allowed) {
      try {
        final pos = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 8)));
        p = LatLng(pos.latitude, pos.longitude);
        _me = p;
      } catch (_) {}
      if (_motion) {
        _position = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)).listen((pos) {
          _me = LatLng(pos.latitude, pos.longitude);
          _moveCamera();
        }, onError: (_) {});
      }
    }
    // 抓不到位置：先看集合點，再看行程表第一個有座標的點，都沒有就看台北
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
    if (c == null) return;
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
      await c.addGeoJsonSource('tour-meet-ring', empty);
      await c.addGeoJsonSource('tour-meet-pillar', empty);
      await c.addGeoJsonSource('tour-lost', empty);
      await c.addCircleLayer('tour-stops', 'tour-stops-dot', const CircleLayerProperties(
        circleRadius: 5, circleColor: '#F3F0FF', circleOpacity: 0.55, circleStrokeColor: '#070B1F', circleStrokeWidth: 1.5, circlePitchAlignment: 'map',
      ));
      await c.addCircleLayer('tour-meet-ring', 'tour-meet-glow', CircleLayerProperties(
        circleRadius: 34, circleColor: _hex(_tint), circleOpacity: 0.16, circleBlur: 0.6, circlePitchAlignment: 'map',
      ));
      await c.addCircleLayer('tour-meet-ring', 'tour-meet-ring', CircleLayerProperties(
        circleRadius: 20, circleColor: '#000000', circleOpacity: 0, circleStrokeColor: _hex(_tint), circleStrokeWidth: 2.5, circlePitchAlignment: 'map',
      ));
      await c.addFillExtrusionLayer('tour-meet-pillar', 'tour-meet-pillar', FillExtrusionLayerProperties(
        fillExtrusionColor: _hex(_tint), fillExtrusionHeight: 180, fillExtrusionBase: 0, fillExtrusionOpacity: 0.85,
      ));
      await c.addCircleLayer('tour-lost', 'tour-lost-dot', const CircleLayerProperties(
        circleRadius: 9, circleColor: '#FF6B7A', circleStrokeColor: '#070B1F', circleStrokeWidth: 2,
      ));
      await c.addSymbolLayer('tour-lost', 'tour-lost-label', const SymbolLayerProperties(
        textField: ['get', 'label'], textFont: ['Noto Sans Regular'], textSize: 12, textColor: '#FF6B7A',
        textHaloColor: '#070B1F', textHaloWidth: 1.5, textOffset: [0, 1.6], textAllowOverlap: true,
      ));
      _layersReady = true;
      await _syncLayers();
    } catch (_) {}
    widget.onReady?.call(c);
    if (widget.intro) _playIntro();
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
    final call = g?.call;
    try {
      await c.setGeoJsonSource('tour-meet-ring', _points(call == null ? const [] : [(call.lat, call.lng, '')]));
      await c.setGeoJsonSource('tour-meet-pillar', {
        'type': 'FeatureCollection',
        'features': call == null ? [] : [_square(call.lat, call.lng, 4)],
      });
      await c.setGeoJsonSource('tour-lost', _points([for (final l in g?.lost ?? const <TourLost>[]) (l.lat, l.lng, '${l.no}')]));
      await c.setGeoJsonSource('tour-stops', _points([for (final s in g?.stops ?? const <TourStop>[]) if (s.lat != null) (s.lat!, s.lng!, '')]));
    } catch (_) {}
  }

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Map<String, dynamic> _points(List<(double, double, String)> pts) => {
        'type': 'FeatureCollection',
        'features': [
          for (final p in pts)
            {'type': 'Feature', 'properties': {'label': p.$3}, 'geometry': {'type': 'Point', 'coordinates': [p.$2, p.$1]}}
        ],
      };

  /// 光柱的底：以集合點為中心、邊長約 2×half 公尺的正方形
  static Map<String, dynamic> _square(double lat, double lng, double half) {
    final dLat = half / 111320.0, dLng = half / (111320.0 * cos(lat * pi / 180));
    return {
      'type': 'Feature', 'properties': {},
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [[lng - dLng, lat - dLat], [lng + dLng, lat - dLat], [lng + dLng, lat + dLat], [lng - dLng, lat + dLat], [lng - dLng, lat - dLat]]
        ],
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_style == null || _start == null) return const ColoredBox(color: Night.night900, child: Center(child: CircularProgressIndicator(color: Night.auroraViolet)));
    final map = MapLibreMap(
      styleString: _style!,
      // 進場鏡頭的起點：城市高空、正上方
      initialCameraPosition: widget.intro ? CameraPosition(target: _start!, zoom: 12) : CameraPosition(target: _start!, zoom: 16, tilt: 50),
      onMapCreated: (c) => _c = c,
      onStyleLoadedCallback: _onStyleLoaded,
      trackCameraPosition: true,
      myLocationEnabled: _myLocation,
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
      // 地圖資料授權要求的出處標示
      Positioned(left: 12, bottom: widget.bottomInset + 4, child: const IgnorePointer(child: Text('© OpenMapTiles © OpenStreetMap', style: TextStyle(color: Night.inkFaint, fontSize: 10)))),
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
      if (widget.picking)
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 104),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 14, height: 90, decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [_tint, _tint.withValues(alpha: 0)]),
                )),
                Container(width: 46, height: 14, decoration: BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(99), border: Border.all(color: _tint, width: 2.5))),
              ]),
            ),
          ),
        ),
    ]);
  }
}
