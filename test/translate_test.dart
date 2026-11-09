import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourchip/translate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 系統偵測故意一律回答日文：漢字字串不能被它帶走
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('tourchip/translate'),
    (call) async => call.method == 'identify' ? 'ja' : null,
  );

  test('全是漢字的短字串是中文，不是日文', () async {
    expect(await ChatTranslator.detect('停車場'), 'zh');
    expect(await ChatTranslator.detect('B1 停車場集合'), 'zh');
  });

  test('有假名、韓文、泰文字母就照字判斷', () async {
    expect(await ChatTranslator.detect('駐車場で集合します'), 'ja');
    expect(await ChatTranslator.detect('주차장'), 'ko');
    expect(await ChatTranslator.detect('ที่จอดรถ'), 'th');
  });

  test('拉丁字母交給系統偵測', () async {
    expect(await ChatTranslator.detect('Meet at the parking lot'), 'ja');
  });
}
