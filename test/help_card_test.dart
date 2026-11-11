import 'package:flutter_test/flutter_test.dart';
import 'package:tourchip/l10n.dart';
import 'package:tourchip/screens/help_card.dart';

void main() {
  test('求助卡：依所在地時區選當地語言，不認得的用英文', () {
    expect(localLangFor('Asia/Tokyo'), 'ja');
    expect(localLangFor('Asia/Seoul'), 'ko');
    expect(localLangFor('Asia/Bangkok'), 'th');
    expect(localLangFor('Asia/Taipei'), 'zh-Hant');
    expect(localLangFor('Asia/Jakarta'), 'id');
    expect(localLangFor('Europe/Paris'), 'en');
  });

  test('求助卡：指定語言的句子（含團名、電話）', () {
    const name = '北海道五日';
    const phone = '+886 912 345 678';
    expect(txIn('ja', '團名：$name', 'Group: $name'), '団体名：$name');
    expect(txIn('ko', '請幫我打電話給領隊：$phone', 'Please call my tour leader: $phone'), '인솔자에게 전화해 주세요: $phone');
    expect(txIn('en', '請幫幫我', 'Please help me'), 'Please help me');
    expect(txIn('zh-Hant', '請幫幫我', 'Please help me'), '請幫幫我');
  });
}
