import 'package:flutter_test/flutter_test.dart';
import 'package:tourchip/l10n.dart';
import 'package:tourchip/translate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('literal and template lookups', () {
    appLang.value = 'ja';
    expect(tx('集合', 'Gather'), '集合');
    expect(tx('翻譯', 'Translate'), '翻訳');
    const n = 7;
    expect(tx('$n 號', 'No. $n'), '7番');
    appLang.value = 'th';
    expect(tx('到了 3／5', 'Here 3/5'), 'มาถึง 3/5');
    appLang.value = 'ko';
    expect(tx('不在表裡', 'Not in table'), 'Not in table');
    appLang.value = 'vi';
    const a = 2, b = 9;
    expect(tx('到了 $a／$b', 'Here $a/$b'), 'Đã đến 2/9');
  });

  test('simplified Chinese via OpenCC', () async {
    await ChineseConverter.load();
    appLang.value = 'zh-Hans';
    expect(tx('旅行團會在你使用 App 時取得位置', 'x'), '旅行团会在你使用 App 时取得位置');
    expect(tx('發一個氣泡', 'Post a bubble'), '发一个气泡');
    expect(ChineseConverter.toTraditional('发一个气泡'), '發一個氣泡');
  });
}
