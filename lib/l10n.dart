import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_table.dart';
import 'translate.dart' show ChineseConverter;

/// 介面文字：12 種語言（繁中、簡中、英、日、韓、馬來、印尼、越南、泰、葡萄牙、西班牙、印地）。
/// 程式裡一律寫 tx(中文, English)：
/// - 繁中用第一個參數、英文用第二個
/// - 簡中由繁中用 OpenCC 對照表轉換
/// - 其他語言查 l10n_table.dart（tool/i18n/ui.tsv 產生）；帶變數的句子用英文句比對出變數再填進譯文
/// - 查不到的一律用英文

const supportedLangs = ['zh-Hant', 'zh-Hans', 'en', 'ja', 'ko', 'ms', 'id', 'vi', 'th', 'pt', 'es', 'hi'];

const langNames = {
  'zh-Hant': '繁體中文',
  'zh-Hans': '简体中文',
  'en': 'English',
  'ja': '日本語',
  'ko': '한국어',
  'ms': 'Bahasa Melayu',
  'id': 'Bahasa Indonesia',
  'vi': 'Tiếng Việt',
  'th': 'ไทย',
  'pt': 'Português',
  'es': 'Español',
  'hi': 'हिन्दी',
};

/// 'system'（跟隨手機）或 supportedLangs 其中之一
final appLang = ValueNotifier<String>('system');
const _langKey = 'app_lang';

Future<void> initLang() async {
  try {
    var v = (await SharedPreferences.getInstance()).getString(_langKey);
    if (v == 'zh') v = 'zh-Hant'; // 舊版存的值
    if (v != null && supportedLangs.contains(v)) appLang.value = v;
  } catch (_) {}
  await ChineseConverter.load();
}

/// 換語言：存起來，並讓整個畫面用新語言重畫
Future<void> setLang(String v) async {
  appLang.value = v;
  _cache.clear();
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

/// 手機語言 → 支援的語言
String systemLang() {
  final l = PlatformDispatcher.instance.locale;
  if (l.languageCode == 'zh') {
    final hans = l.scriptCode == 'Hans' || (l.scriptCode == null && const {'CN', 'SG', 'MY'}.contains(l.countryCode));
    return hans ? 'zh-Hans' : 'zh-Hant';
  }
  if (l.languageCode == 'in') return 'id'; // 舊的印尼語代碼
  return supportedLangs.contains(l.languageCode) ? l.languageCode : 'en';
}

/// 目前的語言（已解析「跟隨手機」）
String get lang => appLang.value == 'system' ? systemLang() : appLang.value;

bool get isZh => lang.startsWith('zh');

/// 給 MaterialApp 的 locale（日期、系統按鈕）
Locale get appLocale => switch (lang) {
      'zh-Hant' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
      'zh-Hans' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      final l => Locale(l),
    };

const appLocales = [
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  Locale('en'), Locale('ja'), Locale('ko'), Locale('ms'), Locale('id'), Locale('vi'), Locale('th'),
  Locale('pt'), Locale('es'), Locale('hi'),
];

String tx(String zh, String en) => switch (lang) {
      'zh-Hant' => zh,
      'zh-Hans' => ChineseConverter.toSimplified(zh),
      'en' => en,
      final l => _lookup(l, zh, en),
    };

/// 指定語言的介面文字（求助卡用當地語言給當地人看）
String txIn(String l, String zh, String en) => switch (l) {
      'zh-Hant' => zh,
      'zh-Hans' => ChineseConverter.toSimplified(zh),
      'en' => en,
      _ => _lookup(l, zh, en),
    };

/// 送給伺服器的語言（Accept-Language），讓錯誤訊息與推播用同一種語言
String get langTag => lang;

/// 設定頁顯示用
String get langLabel => appLang.value == 'system' ? tx('跟隨手機設定', 'Same as phone') : langNames[appLang.value]!;

/// 星期幾（1 = 星期一）
String weekdayShort(int weekday) {
  const w = {
    'zh': ['一', '二', '三', '四', '五', '六', '日'],
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'ja': ['月', '火', '水', '木', '金', '土', '日'],
    'ko': ['월', '화', '수', '목', '금', '토', '일'],
    'ms': ['Isn', 'Sel', 'Rab', 'Kha', 'Jum', 'Sab', 'Ahd'],
    'id': ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
    'vi': ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
    'th': ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'],
    'pt': ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'],
    'es': ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'],
    'hi': ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'],
  };
  return (w[isZh ? 'zh' : lang] ?? w['en']!)[weekday - 1];
}

// ───────── 翻譯表查詢 ─────────

const _col = {'ja': 2, 'ko': 3, 'ms': 4, 'id': 5, 'vi': 6, 'th': 7, 'pt': 8, 'es': 9, 'hi': 10};
Map<String, List<String>>? _literal;
List<(RegExp, RegExp, List<String>)>? _templates;
final Map<String, String> _cache = {};
final _ph = RegExp(r'\{(\d+|\*)\}');

void _build() {
  _literal = {};
  _templates = [];
  for (final row in uiTable) {
    if (!_ph.hasMatch(row[1]) && !_ph.hasMatch(row[0])) {
      _literal![row[0]] = row;
    } else {
      _templates!.add((_pattern(row[0]), _pattern(row[1]), row));
    }
  }
}

RegExp _pattern(String template) {
  final b = StringBuffer('^');
  var last = 0;
  for (final m in _ph.allMatches(template)) {
    b.write(RegExp.escape(template.substring(last, m.start)));
    b.write(m.group(1) == '*' ? '(?:.*?)' : '(.*?)');
    last = m.end;
  }
  b.write(RegExp.escape(template.substring(last)));
  b.write(r'$');
  return RegExp(b.toString(), dotAll: true);
}

String _lookup(String l, String zh, String en) {
  final col = _col[l];
  if (col == null) return en;
  final key = '$l\u0000$zh\u0000$en';
  final hit = _cache[key];
  if (hit != null) return hit;
  if (_literal == null) _build();
  String out = en;
  final row = _literal![zh];
  if (row != null) {
    out = row[col];
  } else {
    for (final (zhRe, enRe, r) in _templates!) {
      if (!zhRe.hasMatch(zh)) continue;
      final m = enRe.firstMatch(en);
      if (m == null) continue;
      // 英文樣板裡 {n} 出現的順序 → 第幾個擷取群組
      final order = [for (final p in _ph.allMatches(r[1])) p.group(1)!];
      out = r[col].replaceAllMapped(RegExp(r'\{(\d+)\}'), (p) {
        final i = order.indexOf(p.group(1)!);
        return i < 0 ? '' : (m.group(i + 1) ?? '');
      });
      break;
    }
  }
  if (_cache.length > 2000) _cache.clear();
  return _cache[key] = out;
}
