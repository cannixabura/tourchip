import 'dart:ui' show PlatformDispatcher;

/// 介面文字：第一版只有繁體中文與英文，手機語言是中文就用中文，其他一律英文。
/// 用法：tx('集合', 'Gather')。之後要加日文、韓文時再改成 ARB（flutter gen-l10n）。
bool get isZh => PlatformDispatcher.instance.locale.languageCode == 'zh';

String tx(String zh, String en) => isZh ? zh : en;

/// 送給伺服器的語言（Accept-Language），讓錯誤訊息與推播用同一種語言
String get langTag => isZh ? 'zh-Hant' : 'en';
