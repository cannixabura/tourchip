import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../tour/model.dart';
import '../tour/service.dart';
import '../ui/night.dart';

/// 城市低語的 3D 夜光地圖（MapLibre＋OpenFreeMap），加上旅行團的圖層：
///   集合點光柱：團色的 3D 柱子（fill-extrusion，真的立在建築之間）＋地面光環
///   迷路的團員：紅色圓點＋團號（團員自己按「我迷路了」才有，只有團主與共同團主看得到）
///   行程表的集合點：小圓點（行程預覽）
/// 團員的位置不會出現在這張地圖上；自己的位置是系統藍點，只在自己的手機上。
const _styleAsset = 'assets/map/night_style.json';

class TourMap extends StatefulWidget {
  final TourGroup group;
  /// 選集合點：地圖中央出現十字，拖曳地圖決定位置（發集合、行程表用）
  final bool picking;
  final void Function(MapLibreMapController controller)? onReady;
  const TourMap({super.key, required this.group, this.picking = false, this.onReady});

  @override
  State<TourMap> createState() => TourMapState();
}

class TourMapState extends State<TourMap> {
  String? _style;
  LatLng? _start;
  MapLibreMapController? _c;
  bool _layersReady = false;
  bool _myLocation = false;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString(_styleAsset).then((s) { if (mounted) setState(() => _style = s); });
    _locate();
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
      } catch (_) {}
    }
    // 抓不到位置：先看集合點，再看行程表第一個有座標的點，都沒有就看台北
    p ??= g.call != null ? LatLng(g.call!.lat, g.call!.lng) : null;
    p ??= g.stops.where((s) => s.lat != null).map((s) => LatLng(s.lat!, s.lng!)).firstOrNull;
    p ??= const LatLng(25.0330, 121.5654);
    if (mounted) setState(() => _start = p);
  }

  /// 地圖中央（選集合點時用）
  LatLng? get center => _c?.cameraPosition?.target;

  Future<void> flyTo(double lat, double lng) async {
    await _c?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lng), zoom: 16.5, tilt: 55)), duration: const Duration(milliseconds: 900));
  }

  @override
  void didUpdateWidget(covariant TourMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_layersReady) _syncLayers();
  }

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
        circleRadius: 34, circleColor: _hex(widget.group.tint), circleOpacity: 0.16, circleBlur: 0.6, circlePitchAlignment: 'map',
      ));
      await c.addCircleLayer('tour-meet-ring', 'tour-meet-ring', CircleLayerProperties(
        circleRadius: 20, circleColor: '#000000', circleOpacity: 0, circleStrokeColor: _hex(widget.group.tint), circleStrokeWidth: 2.5, circlePitchAlignment: 'map',
      ));
      await c.addFillExtrusionLayer('tour-meet-pillar', 'tour-meet-pillar', FillExtrusionLayerProperties(
        fillExtrusionColor: _hex(widget.group.tint), fillExtrusionHeight: 180, fillExtrusionBase: 0, fillExtrusionOpacity: 0.85,
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
  }

  Future<void> _syncLayers() async {
    final c = _c;
    if (c == null) return;
    final g = widget.group;
    final call = g.call;
    try {
      await c.setGeoJsonSource('tour-meet-ring', _points(call == null ? const [] : [(call.lat, call.lng, '')]));
      await c.setGeoJsonSource('tour-meet-pillar', {
        'type': 'FeatureCollection',
        'features': call == null ? [] : [_square(call.lat, call.lng, 4)],
      });
      await c.setGeoJsonSource('tour-lost', _points([for (final l in g.lost) (l.lat, l.lng, '${l.no}')]));
      await c.setGeoJsonSource('tour-stops', _points([for (final s in g.stops) if (s.lat != null) (s.lat!, s.lng!, '')]));
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
    if (_style == null || _start == null) return const ColoredBox(color: Night.night800, child: Center(child: CircularProgressIndicator(color: Night.auroraViolet)));
    return Stack(children: [
      MapLibreMap(
        styleString: _style!,
        initialCameraPosition: CameraPosition(target: _start!, zoom: 16, tilt: 50),
        onMapCreated: (c) => _c = c,
        onStyleLoadedCallback: _onStyleLoaded,
        trackCameraPosition: true,
        myLocationEnabled: _myLocation,
        myLocationRenderMode: MyLocationRenderMode.normal,
        compassEnabled: false,
        logoViewMargins: const Point(-100, -100),
        attributionButtonMargins: const Point(-100, -100),
      ),
      // 地圖資料授權要求的出處標示
      const Positioned(left: 12, bottom: 4, child: IgnorePointer(child: Text('© OpenMapTiles © OpenStreetMap', style: TextStyle(color: Night.inkFaint, fontSize: 10)))),
      if (widget.picking)
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 104),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 14, height: 90, decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [widget.group.tint, widget.group.tint.withValues(alpha: 0)]),
                )),
                Container(width: 46, height: 14, decoration: BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(99), border: Border.all(color: widget.group.tint, width: 2.5))),
              ]),
            ),
          ),
        ),
    ]);
  }
}
