import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;

import 'l10n.dart';
import 'ui/night.dart';

/// 訊息、公告、氣泡的「翻譯」：完全在手機上進行，內容不會上傳。
/// iPhone 用 Apple 翻譯（iOS 18，需要下載語言時系統會自己問），
/// Android 用 Google ML Kit（第一次翻某種語言要下載約 30 MB 的模型，下載前先問）。
/// 原生程式在 ios/Runner/AppDelegate.swift 與 android/.../Translator.kt（與城市低語相同）。
class ChatTranslator {
  ChatTranslator._();

  static const _channel = MethodChannel('tourchip/translate');
  static final Map<String, String?> _detected = {};
  static final Map<String, bool> _pairSupported = {};
  static final Map<String, String> _done = {};

  /// App 的語言 → 翻譯用的語言代碼。iPhone 的中文分繁簡；ML Kit 的中文只有簡體，繁體之後再轉換。
  static String get target {
    if (!isZh) return lang;
    return Platform.isIOS ? lang : 'zh';
  }

  static bool get _traditional => lang == 'zh-Hant';

  static String _base(String code) => code.split('-').first;

  static final _kana = RegExp(r'[\u3040-\u30ff\u31f0-\u31ff\uff66-\uff9f]');
  static final _hangul = RegExp(r'[\uac00-\ud7af\u1100-\u11ff\u3130-\u318f]');
  static final _thai = RegExp(r'[\u0e00-\u0e7f]');
  static final _han = RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]');

  /// 這段文字是什麼語言；認不出來回傳 null。結果會快取。
  /// 系統的語言偵測對短字串很不準（「停車場」「集合」這種全是漢字的字會被當成日文），所以先看文字本身用的字：
  ///   有假名 → 日文；有韓文字母 → 韓文；有泰文字母 → 泰文
  ///   有漢字、沒有假名 → 中文（日文使用者例外：系統也說是日文才算日文），再用繁簡轉換表分辨繁體或簡體
  ///   其他（拉丁字母等）才交給系統偵測
  static Future<String?> detect(String text) async {
    // 結果跟使用者的語言有關（日文、繁簡的判斷），快取要分語言
    final key = '$lang\u0000$text';
    if (_detected.containsKey(key)) return _detected[key];
    String? found;
    if (_kana.hasMatch(text)) {
      found = 'ja';
    } else if (_hangul.hasMatch(text)) {
      found = 'ko';
    } else if (_thai.hasMatch(text)) {
      found = 'th';
    } else if (_han.hasMatch(text)) {
      found = lang == 'ja' && await _native(text) == 'ja' ? 'ja' : await _chineseScript(text);
    } else {
      found = await _native(text);
    }
    return _detected[key] = found;
  }

  static Future<String?> _native(String text) async {
    try {
      final code = await _channel.invokeMethod<String>('identify', {'text': text});
      if (code != null && code != 'und') return Platform.isIOS ? code : _base(code);
    } catch (_) {}
    return null;
  }

  /// 繁體或簡體：只有一邊轉得動才算那一邊；兩邊都一樣（「九份老街」）就當成跟使用者相同。
  /// iPhone 回傳 zh-Hant／zh-Hans；Android 的 ML Kit 只有 zh
  static Future<String> _chineseScript(String text) async {
    if (!Platform.isIOS) return 'zh';
    await ChineseConverter.load();
    final isHant = ChineseConverter.toSimplified(text) != text; // 有繁體專用字
    final isHans = ChineseConverter.toTraditional(text) != text; // 有簡體專用字
    if (isHant && !isHans) return 'zh-Hant';
    if (isHans && !isHant) return 'zh-Hans';
    return lang == 'zh-Hans' ? 'zh-Hans' : 'zh-Hant';
  }

  static Future<bool> _supported(String source, String target) async {
    final key = '$source>$target';
    final known = _pairSupported[key];
    if (known != null) return known;
    var ok = false;
    try {
      ok = Platform.isIOS
          ? await _channel.invokeMethod<String>('status', {'source': source, 'target': target}) != 'unsupported'
          : await _channel.invokeMethod<bool>('supported', {'lang': source}) == true;
    } catch (_) {}
    return _pairSupported[key] = ok;
  }

  /// 跟使用者的語言不同（或繁簡不同）、而且翻得了，才回傳 true
  static Future<bool> needsTranslation(String text) async {
    if (text.trim().isEmpty) return false;
    final source = await detect(text);
    if (source == null) return false;
    final t = target;
    if (_base(source) == _base(t)) {
      if (_base(t) != 'zh') return false;
      await ChineseConverter.load();
      return (_traditional ? ChineseConverter.toTraditional(text) : ChineseConverter.toSimplified(text)) != text;
    }
    return _supported(source, t);
  }

  static Future<bool> _hasModel(String lang) async =>
      await _channel.invokeMethod<bool>('isDownloaded', {'lang': lang}) == true;

  /// 已經翻過的結果（沒有就是 null）
  static String? cached(String text) => _done['$lang\u0000$text'];

  /// 翻譯；Android 需要下載模型時先問使用者。取消、失敗或不用翻回傳 null。
  static Future<String?> translate(BuildContext context, String text) async {
    final key = '$lang\u0000$text';
    if (_done[key] != null) return _done[key];
    final source = await detect(text);
    if (source == null) return null;
    final t = target;
    await ChineseConverter.load();
    String? out;
    if (_base(source) == _base(t)) {
      if (_base(t) != 'zh') return null;
      out = _traditional ? ChineseConverter.toTraditional(text) : ChineseConverter.toSimplified(text);
    } else {
      try {
        if (!Platform.isIOS) {
          final missing = [for (final l in {source, t}) if (!await _hasModel(l)) l];
          if (missing.isNotEmpty) {
            if (!context.mounted || !await _confirmDownload(context)) return null;
            for (final l in missing) {
              if (await _channel.invokeMethod<bool>('download', {'lang': l}) != true) return null;
            }
          }
        }
        out = await _channel.invokeMethod<String>('translate', {'text': text, 'source': source, 'target': t});
      } catch (_) {
        out = null;
      }
      if (out != null && _base(t) == 'zh') {
        out = _traditional ? ChineseConverter.toTraditional(out) : ChineseConverter.toSimplified(out);
      }
    }
    if (out == null || out == text) return null;
    return _done[key] = out;
  }

  static Future<bool> _confirmDownload(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x99070B1F),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(Night.space6),
        child: GlassCard(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.translate, color: Night.auroraViolet, size: 32),
            const SizedBox(height: Night.space3),
            Text(tx('下載翻譯語言', 'Download translation'), style: Night.title, textAlign: TextAlign.center),
            const SizedBox(height: Night.space2),
            Text(tx('第一次翻譯這種語言，需要下載約 30 MB 的語言檔（建議用 Wi-Fi）。之後翻譯都在手機上進行，內容不會上傳。',
                'Translating this language for the first time needs a download of about 30 MB (Wi-Fi recommended). After that, translation happens on your phone and nothing is uploaded.'),
                style: Night.body),
            const SizedBox(height: Night.space4),
            Row(children: [
              Expanded(child: NightButton(tx('取消', 'Cancel'), kind: NightButtonKind.ghost, onPressed: () => Navigator.pop(dialogContext, false))),
              const SizedBox(width: Night.space2),
              Expanded(child: NightButton(tx('下載', 'Download'), icon: Icons.download, onPressed: () => Navigator.pop(dialogContext, true))),
            ]),
          ]),
        ),
      ),
    );
    return ok == true;
  }
}

/// 一段可以「點一下翻譯」的文字：右下角有「翻譯」，翻好後顯示譯文，再點一下看原文。
/// 跟使用者語言相同（或翻不了）時不顯示按鈕。
class TranslatableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool compact;
  const TranslatableText(this.text, {super.key, this.style, this.textAlign, this.maxLines, this.compact = false});

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  bool _can = false, _busy = false, _showing = false;
  String? _out;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(TranslatableText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _out = null;
      _showing = false;
      _check();
    }
  }

  Future<void> _check() async {
    final text = widget.text;
    final can = await ChatTranslator.needsTranslation(text);
    if (!mounted || text != widget.text) return;
    setState(() {
      _can = can;
      _out = ChatTranslator.cached(text);
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_out != null) {
      setState(() => _showing = !_showing);
      return;
    }
    setState(() => _busy = true);
    final text = widget.text;
    final out = await ChatTranslator.translate(context, text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (text == widget.text && out != null) {
        _out = out;
        _showing = true;
      }
    });
    if (out == null && mounted) showGlassToast(context, tx('目前無法翻譯', "Can't translate right now"), danger: true);
  }

  @override
  Widget build(BuildContext context) {
    final body = Text(_showing && _out != null ? _out! : widget.text,
        style: widget.style, textAlign: widget.textAlign, maxLines: widget.maxLines, overflow: widget.maxLines == null ? null : TextOverflow.ellipsis);
    if (!_can) return body;
    final label = _busy ? tx('翻譯中…', 'Translating…') : (_showing ? tx('看原文', 'Show original') : tx('翻譯', 'Translate'));
    final link = InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.compact ? 2 : 4, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.translate, size: widget.compact ? 13 : 15, color: Night.auroraBlue),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Night.auroraBlue, fontSize: widget.compact ? 12 : 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
    final end = widget.textAlign == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: end, children: [body, link]);
  }
}

/// 繁簡轉換（台灣用語）。對照表取自 OpenCC（Apache 2.0），見 assets/opencc/NOTICE.txt。
/// 先比對詞（最長優先），再逐字轉換。
class ChineseConverter {
  ChineseConverter._();

  static final Map<String, String> _chars = {}, _phrases = {}, _tw = {}, _twVariants = {};
  static final Map<String, String> _tsChars = {}, _tsPhrases = {};
  static int _maxPhrase = 1, _maxTw = 1, _maxTs = 1;
  static Future<void>? _loading;
  static final Map<String, String> _simpCache = {};

  static Future<void> load() => _loading ??= () async {
        try {
          _parse(await rootBundle.loadString('assets/opencc/s2t.txt'),
              (h) => switch (h) { '# phrases' => _phrases, '# tw' => _tw, '# twv' => _twVariants, _ => _chars });
          _parse(await rootBundle.loadString('assets/opencc/t2s.txt'), (h) => h == '# phrases' ? _tsPhrases : _tsChars);
        } catch (_) {}
        for (final k in _phrases.keys) { if (k.length > _maxPhrase) _maxPhrase = k.length; }
        for (final k in _tw.keys) { if (k.length > _maxTw) _maxTw = k.length; }
        for (final k in _tsPhrases.keys) { if (k.length > _maxTs) _maxTs = k.length; }
      }();

  static void _parse(String text, Map<String, String> Function(String header) sectionOf) {
    var section = sectionOf('# chars');
    for (final line in text.split('\n')) {
      if (line.startsWith('# ')) {
        section = sectionOf(line.trim());
        continue;
      }
      final tab = line.indexOf('\t');
      if (tab > 0) section[line.substring(0, tab)] = line.substring(tab + 1).trim();
    }
  }

  /// 簡 → 繁（台灣）。必須先 [load]；還沒載入時原樣回傳
  static String toTraditional(String s) {
    if (_chars.isEmpty) return s;
    final t = _replace(s, _phrases, _maxPhrase, (c) => _chars[c] ?? c);
    return _replace(t, _tw, _maxTw, (c) => _twVariants[c] ?? c);
  }

  /// 繁 → 簡。必須先 [load]；還沒載入時原樣回傳
  static String toSimplified(String s) {
    if (_tsChars.isEmpty) return s;
    final hit = _simpCache[s];
    if (hit != null) return hit;
    if (_simpCache.length > 3000) _simpCache.clear();
    return _simpCache[s] = _replace(s, _tsPhrases, _maxTs, (c) => _tsChars[c] ?? c);
  }

  static String _replace(String s, Map<String, String> phrases, int maxLen, String Function(String) single) {
    final out = StringBuffer();
    var i = 0;
    while (i < s.length) {
      var matched = false;
      for (var len = maxLen < s.length - i ? maxLen : s.length - i; len > 1; len--) {
        final hit = phrases[s.substring(i, i + len)];
        if (hit != null) {
          out.write(hit);
          i += len;
          matched = true;
          break;
        }
      }
      if (!matched) {
        out.write(single(s[i]));
        i++;
      }
    }
    return out.toString();
  }
}
