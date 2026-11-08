// 這個檔案要在 Mac 上用 FlutterFire CLI 重新產生（會覆蓋這個暫時的版本）：
//   flutterfire configure --project=mood-whisper-f7de9 --platforms=ios,android \
//     --ios-bundle-id=com.softchip.tourchip --android-package-name=com.softchip.tourchip
// 旅行團與城市低語共用同一個 Firebase 專案（mood-whisper-f7de9），但註冊成另一個 App。
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('請先執行 flutterfire configure 產生 lib/firebase_options.dart（見 CLAUDE.md）');
}
