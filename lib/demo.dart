import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 商店截圖模式（只在 debug 版有效，正式版完全不會讀）。
/// App 啟動時讀 App 資料夾裡的 Documents/demo.json：
///   {"lang": "ja", "shot": 3, "group": {...團的 JSON...}, "profile": {...}, "aiyaImage": "menu.jpg", "spot": {...}}
/// 有這個檔案時：換成指定語言、跳過導覽、伺服器的團狀態改用檔案裡的範例資料（不連網、不送任何東西）。
/// 字串裡的 $ME 換成這支手機的帳號；"xxxIn": 秒數 會換成「現在＋秒數」的 "xxx"（例如 atIn → at）。
class Demo {
  Demo._();
  static Map<String, dynamic>? cfg;
  static bool get on => cfg != null;
  static int get shot => (cfg?['shot'] as num?)?.toInt() ?? 0;
  /// 9 = 展示影片：自動走完整個流程
  static bool get tour => shot == 9;
  static final _marks = <String, int>{};

  /// 影片的場景時間點（毫秒，系統時間），寫到 Documents/timeline.json 給合成字幕用
  static void mark(String name) {
    _marks[name] = DateTime.now().millisecondsSinceEpoch;
    try {
      File('$_dir/timeline.json').writeAsStringSync(jsonEncode(_marks));
    } catch (_) {}
  }

  static String _dir = '';

  static Future<void> load() async {
    if (!kDebugMode) return;
    // App 的資料夾：iOS 的 HOME，或暫存資料夾（…/tmp）的上一層
    final dirs = {'${Platform.environment['HOME'] ?? ''}/Documents', '${Directory.systemTemp.parent.path}/Documents'};
    for (final d in dirs) {
      try {
        final f = File('$d/demo.json');
        if (!await f.exists()) continue;
        cfg = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _dir = d;
        debugPrint('Demo: $d shot ${cfg?['shot']}');
        return;
      } catch (e) {
        debugPrint('Demo: $d $e');
      }
    }
    debugPrint('Demo: none in $dirs');
  }

  static Object? _fill(Object? v, String me, int now) {
    if (v is String) return v.replaceAll(r'$ME', me);
    if (v is List) return [for (final x in v) _fill(x, me, now)];
    if (v is Map) {
      final out = <String, dynamic>{};
      v.forEach((k, x) {
        if (k.endsWith('In') && k.length > 2 && x is num) {
          out[k.substring(0, k.length - 2)] = now + (x * 1000).round();
        } else {
          out['$k'] = _fill(x, me, now);
        }
      });
      return out;
    }
    return v;
  }

  /// 假裝是伺服器的 status 回應
  static Map<String, dynamic> status() {
    final me = FirebaseAuth.instance.currentUser?.uid ?? 'me';
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'success': true,
      'group': _fill(cfg?['group'], me, now),
      'profile': _fill(cfg?['profile'], me, now),
    };
  }

  /// 截圖用的照片（App 資料夾 Documents 裡的檔名）
  static Future<Uint8List?> image(String key) async {
    final name = cfg?[key];
    if (name is! String) return null;
    try {
      return await File('$_dir/$name').readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
