import 'package:flutter_test/flutter_test.dart';
import 'package:tourchip/tour/service.dart';

void main() {
  test('入團連結：團代碼與 QR 版本', () {
    final l = parseTourLink('https://tourchip.web.app/g/ABCD2345?v=3');
    expect(l, isA<JoinLink>());
    expect((l as JoinLink).code, 'ABCD2345');
    expect(l.version, 3);
  });

  test('團購券連結', () {
    final l = parseTourLink('https://tourchip.web.app/v/abcd2345ef');
    expect(l, isA<VoucherLink>());
    expect((l as VoucherLink).code, 'ABCD2345EF');
  });

  test('其他網站或格式不對都不接受', () {
    expect(parseTourLink('https://mood-whisper-f7de9.web.app/g/ABCD2345?v=1'), isNull);
    expect(parseTourLink('https://tourchip.web.app/g/ABC'), isNull);
    expect(parseTourLink('https://tourchip.web.app/g/ABCD1234'), isNull); // 1 不在字母表裡
    expect(parseTourLink('hello'), isNull);
  });
}
