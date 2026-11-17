import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

import '../l10n.dart';
import 'model.dart';
import 'service.dart';

enum CastMode { off, listening, speaking }

class CastState {
  final CastMode mode;
  final String castId;
  final bool connecting, connected, micOn;
  /// 正在聽的人數（講的人看）
  final int listeners;
  final String? error;
  const CastState({this.mode = CastMode.off, this.castId = '', this.connecting = false, this.connected = false, this.micOn = false, this.listeners = 0, this.error});
  CastState copy({bool? connecting, bool? connected, bool? micOn, int? listeners, String? error, bool clearError = false}) => CastState(
        mode: mode, castId: castId, connecting: connecting ?? this.connecting, connected: connected ?? this.connected, micOn: micOn ?? this.micOn,
        listeners: listeners ?? this.listeners, error: clearError ? null : (error ?? this.error));
  bool get on => mode != CastMode.off;
}

/// 講解廣播：團主或共同團主對著手機講，團員用自己的耳機、藍牙耳機或手機喇叭聽（單向，用城市低語同一台 LiveKit 主機）。
/// - 講的人：開始廣播後自動連線並開麥克風；可以暫時靜音、結束。
/// - 聽的人：頂部的耳機圖示按一下開始聽、再按一下關掉；點廣播通知打開 App 也會直接開始聽。
/// - 聲音輸出：接了耳機或藍牙就用耳機；沒接時「擴音」開＝手機喇叭，關＝聽筒。
/// - 背景：iOS 背景音訊（UIBackgroundModes audio）；Android 前景服務（CastService.kt，常駐通知）。
class TourCast {
  TourCast._();
  static final state = ValueNotifier<CastState>(const CastState());
  /// 擴音：沒接耳機時用手機喇叭（關掉就用聽筒）
  static final speaker = ValueNotifier<bool>(true);
  static const _android = MethodChannel('tourchip/cast');

  static Room? _room;
  static EventsListener<RoomEvent>? _events;
  /// 使用者選了要聽哪一場（按了耳機圖示或點了通知）
  static String? _wantListen;
  /// 點了廣播通知、團的狀態還沒更新到那一場：更新到了就開始聽
  static String? _pendingFromPush;
  /// 講的人按了「結束廣播」的那一場：伺服器確認結束、團的狀態更新之前，不要再連回去
  static String? _ended;
  static bool _busy = false;

  /// 這一場還算在進行嗎（自己剛結束的不算）
  static TourCastInfo? live(TourCastInfo? c) => c == null || c.id == _ended ? null : c;
  static int _retries = 0;
  static Timer? _retry;

  /// 每次團的狀態更新時呼叫（TourService._apply）：該連就連、該斷就斷
  static void sync(TourGroup? g) {
    final raw = g?.cast;
    if (raw == null || raw.id != _ended) _ended = null;
    final c = live(raw);
    if (c == null) {
      _wantListen = null;
      if (state.value.on || _room != null) _disconnect();
      return;
    }
    if (_pendingFromPush != null && (_pendingFromPush == c.id || _pendingFromPush!.isEmpty)) {
      _wantListen = c.id;
      _pendingFromPush = null;
    }
    final want = c.mine ? CastMode.speaking : (_wantListen == c.id ? CastMode.listening : CastMode.off);
    final s = state.value;
    if (want == CastMode.off) {
      if (s.on) _disconnect();
      return;
    }
    if (s.castId == c.id && s.mode == want && (s.connected || s.connecting || _retry != null)) return;
    _connect(g!, c, want);
  }

  /// 聽的人：開始聽／不聽了（頂部耳機圖示）
  static void listen(bool on) {
    final g = TourService.current.value;
    final c = g?.cast;
    if (c == null || c.mine) return;
    _wantListen = on ? c.id : null;
    _retries = 0;
    sync(g);
  }

  /// 點了廣播通知：打開就開始聽
  static void listenFromPush(String castId) {
    _pendingFromPush = castId;
    sync(TourService.current.value);
  }

  /// 講的人：開始廣播（sub：只講給某一組）。成功後狀態更新會自動連線開麥克風。回傳錯誤代碼或 null
  static Future<String?> start({int? sub}) async {
    final r = await TourService.call('cast_start', {'sub': sub ?? -1});
    return r['success'] == true ? null : '${r['code'] ?? 'busy'}';
  }

  /// 講的人：結束廣播
  static Future<void> stop() async {
    final id = TourService.current.value?.cast?.id ?? state.value.castId;
    if (id.isNotEmpty) _ended = id;
    await _disconnect();
    final r = await TourService.call('cast_stop');
    if (r['success'] != true && r['code'] != 'ended') {
      // 伺服器沒結束：恢復原狀，讓狀態更新照常連回去
      _ended = null;
      sync(TourService.current.value);
    }
  }

  /// 講的人：暫時靜音／恢復
  static Future<void> setMic(bool on) async {
    final room = _room;
    if (room == null || state.value.mode != CastMode.speaking) return;
    try {
      await room.localParticipant?.setMicrophoneEnabled(on);
    } catch (_) {}
    state.value = state.value.copy(micOn: room.localParticipant?.isMicrophoneEnabled() ?? false);
  }

  /// 擴音（沒接耳機時）：開＝手機喇叭，關＝聽筒。接了耳機或藍牙一律走耳機
  static Future<void> setSpeaker(bool on) async {
    speaker.value = on;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(on);
    } catch (_) {}
  }

  static Future<void> _connect(TourGroup g, TourCastInfo c, CastMode mode) async {
    if (_busy) return;
    _busy = true;
    _retry?.cancel();
    _retry = null;
    try {
      if (_room != null) await _closeRoom();
      state.value = CastState(mode: mode, castId: c.id, connecting: true);
      final r = await TourService.call('cast_token', {'castId': c.id});
      if (_ended == c.id) {
        state.value = const CastState();
        return;
      }
      if (r['success'] != true) {
        state.value = state.value.copy(connecting: false, error: '${r['code'] ?? 'busy'}');
        if (r['code'] == 'ended' || r['code'] == 'not_target') {
          _wantListen = null;
          state.value = const CastState();
        } else {
          _scheduleRetry();
        }
        return;
      }
      final room = Room(roomOptions: const RoomOptions(
        adaptiveStream: false,
        dynacast: false,
        defaultAudioPublishOptions: AudioPublishOptions(encoding: AudioEncoding.presetSpeech, dtx: true),
      ));
      _room = room;
      _events = room.createListener()
        ..on<ParticipantConnectedEvent>((_) => _count())
        ..on<ParticipantDisconnectedEvent>((_) => _count())
        ..on<RoomReconnectedEvent>((_) {
          state.value = state.value.copy(connected: true, clearError: true);
          _count();
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (_room != room) return;
          state.value = state.value.copy(connected: false);
          _scheduleRetry();
        });
      await room.connect('${r['url']}', '${r['token']}');
      if (_room != room) return;
      if (_ended == c.id) {
        await _disconnect();
        return;
      }
      await setSpeaker(speaker.value);
      var micOn = false;
      if (mode == CastMode.speaking && r['canPublish'] == true) {
        try {
          await room.localParticipant?.setMicrophoneEnabled(true);
        } catch (_) {}
        micOn = room.localParticipant?.isMicrophoneEnabled() ?? false;
      }
      _retries = 0;
      state.value = state.value.copy(connecting: false, connected: true, micOn: micOn,
          error: mode == CastMode.speaking && !micOn ? 'mic_denied' : null, clearError: mode != CastMode.speaking || micOn);
      _count();
      await _foreground(true, g, c, mode);
    } catch (_) {
      state.value = state.value.copy(connecting: false, connected: false, error: 'connect');
      _scheduleRetry();
    } finally {
      _busy = false;
    }
  }

  /// 斷線：3、6、12… 秒後重連（最多 8 次）；廣播還在、還想聽才重連
  static void _scheduleRetry() {
    if (_retry != null || _retries >= 8) return;
    final delay = Duration(seconds: 3 << (_retries < 4 ? _retries : 4));
    _retries++;
    _retry = Timer(delay, () {
      _retry = null;
      final g = TourService.current.value;
      final c = live(g?.cast);
      final s = state.value;
      if (g == null || c == null || !s.on || c.id != s.castId) return;
      _connect(g, c, s.mode);
    });
  }

  static void _count() {
    final room = _room;
    if (room == null) return;
    state.value = state.value.copy(listeners: room.remoteParticipants.length);
  }

  static Future<void> _closeRoom() async {
    final room = _room;
    _room = null;
    await _events?.dispose();
    _events = null;
    try {
      await room?.disconnect();
      await room?.dispose();
    } catch (_) {}
  }

  static Future<void> _disconnect() async {
    _retry?.cancel();
    _retry = null;
    _retries = 0;
    state.value = const CastState();
    await _closeRoom();
    await _foreground(false, null, null, CastMode.off);
  }

  /// Android：廣播連線時開前景服務（常駐通知），背景也繼續講或聽
  static Future<void> _foreground(bool on, TourGroup? g, TourCastInfo? c, CastMode mode) async {
    if (!Platform.isAndroid) return;
    try {
      if (on && g != null && c != null) {
        final speaking = mode == CastMode.speaking;
        await _android.invokeMethod('start', {
          'speaking': speaking,
          'title': speaking ? tx('講解廣播中', 'Live talk on air') : tx('正在聽講解廣播', 'Listening to the live talk'),
          'text': speaking ? g.name : '${c.byName.isEmpty ? tx('領隊', 'Leader') : c.byName} · ${g.name}',
          'channel': tx('講解廣播', 'Live talk'),
        });
      } else {
        await _android.invokeMethod('stop');
      }
    } catch (_) {}
  }
}
