import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'service.dart';

/// 還沒裝 App 的人掃了入團 QR code → 入團網頁 → 商店下載。裝好第一次打開時，
/// 找回他剛剛掃的那個入團連結，自動入團（不用再掃一次）：
/// - Android：入團網頁的 Google Play 連結帶 referrer（tg=<團代碼>&v=<版本>），用 Play 安裝來源讀回來
/// - iOS：入團網頁按「App Store 下載」時把入團連結複製到剪貼簿，這裡讀一次（系統會問一次能不能貼上）
/// 只在新安裝後第一次打開時看一次；舊版升級上來的不看（避免無緣無故跳出貼上詢問）。
const _checkedKey = 'install_link_checked';

/// 舊版就會寫的設定：有任何一個就表示不是新安裝
const _oldKeys = ['app_lang', 'profile_name', 'profile_avatar', 'pass_purpose', 'msgs_seen_at'];

/// 標記成已經看過（例如這次是點連結打開的，就不用再找）
Future<void> markInstallLinkChecked() async {
  try { await (await SharedPreferences.getInstance()).setBool(_checkedKey, true); } catch (_) {}
}

/// 新安裝後第一次打開：回傳入團連結（沒有就回傳 null）。之後每次呼叫都回傳 null。
Future<JoinLink?> takeInstallLink() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_checkedKey) == true) return null;
    final upgraded = _oldKeys.any(prefs.containsKey);
    await prefs.setBool(_checkedKey, true);
    if (upgraded) return null;
    if (Platform.isAndroid) {
      final details = await PlayInstallReferrer.installReferrer;
      return joinLinkFromReferrer(details.installReferrer);
    }
    if (Platform.isIOS) {
      if (!await Clipboard.hasStrings()) return null;
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      final link = text == null ? null : parseTourLink(text);
      if (link is! JoinLink) return null;
      await Clipboard.setData(const ClipboardData(text: '')); // 用過就清掉，不留在剪貼簿
      return link;
    }
  } catch (_) {}
  return null;
}

/// Google Play 安裝來源：「tg=ABCDEFGH&v=2」（也接受直接放整個入團連結）
JoinLink? joinLinkFromReferrer(String? referrer) {
  if (referrer == null || referrer.isEmpty) return null;
  final asLink = parseTourLink(referrer);
  if (asLink is JoinLink) return asLink;
  try {
    final q = Uri.splitQueryString(referrer);
    final code = (q['tg'] ?? '').toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) return null;
    return JoinLink(code, int.tryParse(q['v'] ?? '') ?? 1);
  } catch (_) {
    return null;
  }
}
