import 'package:flutter_test/flutter_test.dart';
import 'package:tourchip/tour/install_link.dart';
import 'package:tourchip/tour/service.dart';

void main() {
  test('Google Play 安裝來源：tg=團代碼&v=版本', () {
    final l = joinLinkFromReferrer('tg=abcdefgh&v=3');
    expect(l?.code, 'ABCDEFGH');
    expect(l?.version, 3);
  });

  test('沒有版本就當成 1；整個入團連結也接受', () {
    expect(joinLinkFromReferrer('tg=ABCDEFGH')?.version, 1);
    final l = joinLinkFromReferrer('https://tourchip.web.app/g/ABCDEFGH?v=2&i=01234567');
    expect(l?.code, 'ABCDEFGH');
    expect(l?.version, 2);
  });

  test('不是入團的來源就忽略', () {
    expect(joinLinkFromReferrer(null), isNull);
    expect(joinLinkFromReferrer(''), isNull);
    expect(joinLinkFromReferrer('utm_source=google-play&utm_medium=organic'), isNull);
    expect(joinLinkFromReferrer('tg=ABC'), isNull);
    expect(joinLinkFromReferrer('tg=ABCDEFG1'), isNull); // 1 不在團代碼字元裡
  });

  test('入團連結帶邀請碼也照樣解析', () {
    final l = parseTourLink('https://tourchip.web.app/g/ABCDEFGH?v=4&i=12345678');
    expect(l, isA<JoinLink>());
    expect((l as JoinLink).version, 4);
  });
}
