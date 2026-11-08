import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 介面文字：第一版只有繁體中文與英文。
/// 語言預設跟隨手機（中文用中文、其他一律英文），也可以在設定裡固定成中文或英文。
/// 用法：tx('集合', 'Gather')。之後要加日文、韓文時再改成 ARB（flutter gen-l10n）。

/// 'system'（跟隨手機）、'zh'、'en'
final appLang = ValueNotifier<String>('system');
const _langKey = 'app_lang';

Future<void> initLang() async {
  try {
    final v = (await SharedPreferences.getInstance()).getString(_langKey);
    if (v == 'zh' || v == 'en') appLang.value = v!;
  } catch (_) {}
}

/// 換語言：存起來，並讓整個畫面用新語言重畫
Future<void> setLang(String v) async {
  appLang.value = v;
  try {
    final p = await SharedPreferences.getInstance();
    v == 'system' ? await p.remove(_langKey) : await p.setString(_langKey, v);
  } catch (_) {}
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return;
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }
  root.visitChildren(mark);
}

bool get isZh => appLang.value == 'system' ? PlatformDispatcher.instance.locale.languageCode == 'zh' : appLang.value == 'zh';

String tx(String zh, String en) => isZh ? zh : en;

/// 送給伺服器的語言（Accept-Language），讓錯誤訊息與推播用同一種語言
String get langTag => isZh ? 'zh-Hant' : 'en';

/// 設定頁顯示用
String get langLabel => switch (appLang.value) { 'zh' => '繁體中文', 'en' => 'English', _ => tx('跟隨手機設定', 'Same as phone') };
