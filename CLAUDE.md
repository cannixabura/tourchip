# 旅行團 TourChip

給領隊、導遊用的帶團工具（獨立 App），從城市低語的「低語團」獨立出來。
- 產品規格：claude.ai 文件「旅行團 產品規格」
- 畫面設計：claude.ai 畫布「旅行團 畫面設計」（9 個畫面，沿用城市低語夜光設計系統）
- 中文名稱「旅行團」，英文 TourChip；bundle id / package：`com.softchip.tourchip`；Apple Team `JCFN9LMAXF`

## 架構

- **App**：這個資料夾（Flutter）。`lib/` 是完整程式碼，但 `ios/`、`android/` 平台資料夾還沒產生（第一步要做）。
- **後端**：和城市低語共用 Firebase 專案 `mood-whisper-f7de9` 與 `~/lbs_dating_app/geo-service`。
  - `geo-service/tourgroup.js`：純函式（時區、共同團主、分組、公告、行程表、團購券）
  - `geo-service/tourgroup_api.js`：HTTP、Redis、推播
  - `geo-service/index.js`：新增 `exports.tourGroup`、`exports.remindTourGroups`；`playPurchase` 多了第三個參數 `pkg`（預設仍是城市低語）
  - 測試：`tourgroup.test.js`、`tourgroup.flow.test.js`；整個 geo-service 166 個測試全部通過
  - Redis 全部用 `tgroup*`、`tvoucher*` 開頭，**城市低語的低語團完全不受影響，而且低語團必須一直保留**
- **官網**：`hosting/`（入團頁 `/g/`、團購券頁 `/v/`、隱私權、條款、AASA），部署到 Firebase Hosting 的 `tourchip` 網站 → https://tourchip.web.app

## 已決定、不要改

- 團員一定要裝 App；完全免費下載；團員永遠免費
- 20 人以內免費，第 21 人起團主買 `tour_pass_7d`（消耗型，NT$290），上限 100 人
- 團購券 = 同一個商品 `tour_pass_7d`，App 內購買，變成 QR code（`https://tourchip.web.app/v/<10 碼>`）發給領隊
- 共同團主最多 2 位；團主才能升級、交棒、解散
- **團員的位置不會給團主**；只有團員自己按「我迷路了」才傳一次，30 分鐘刪除（Apple 5.1.2(i)）
- 集合時間、行程表一律用「集合點的當地時區」；解散時間 = 結束日 23:59，以最後一個集合點的時區為準
- 不需要帳號：Firebase 匿名登入，身分和城市低語各自獨立、彼此不相認
- 第一版開放未成年團員；第二階段的「行程中分享位置給領隊」上線前要先做家長同意流程
- 介面文字目前用 `tx('中文', 'English')`（`lib/l10n.dart`），之後再換 ARB

## 開工步驟（在 Mac 上依序做，每一步做完再下一步）

1. **版本控制**：`git init && git add -A && git commit -m "旅行團初版程式碼"`，之後每一步都能用 `git diff` 檢查。
2. **產生平台資料夾**：
   `flutter create --org com.softchip --project-name tourchip --platforms ios,android .`
   完成後用 `git status` 確認 `lib/`、`pubspec.yaml` 沒被覆蓋（若有，`git checkout -- lib pubspec.yaml`），並刪掉它產生的 `test/widget_test.dart`。
3. **Firebase**：`flutterfire configure --project=mood-whisper-f7de9 --platforms=ios,android --ios-bundle-id=com.softchip.tourchip --android-package-name=com.softchip.tourchip`
   這會在同一個 Firebase 專案註冊新的 iOS／Android App，並產生 `lib/firebase_options.dart`、`GoogleService-Info.plist`、`google-services.json`。在 Firebase Console 確認：Authentication 的匿名登入已開（城市低語已開）、Cloud Messaging 的 APNs 金鑰對新 App 也有效。
4. **編譯**：`flutter pub get && flutter analyze`，修好所有錯誤（這份程式碼是在沒有 Flutter 的環境寫的，預期會有少量錯誤）。`mobile_scanner` 是新套件，版本照 pub 上最新穩定版調整。
5. **iOS 設定**（參考 `~/lbs_dating_app/ios/Runner`）：
   - Deployment target 與城市低語相同（Podfile `platform :ios, '18.0'`）
   - Signing：Team JCFN9LMAXF，bundle `com.softchip.tourchip`
   - Capabilities：Push Notifications、Time Sensitive Notifications（entitlement `com.apple.developer.usernotifications.time-sensitive`）、Associated Domains `applinks:tourchip.web.app`、In-App Purchase、Background Modes → Remote notifications
   - Info.plist：`NSLocationWhenInUseUsageDescription`（「旅行團會在你使用 App 時取得位置，用來在你的手機上算出到集合點的距離與方向；不會傳給領隊，除非你按下『我迷路了』。」）、`NSCameraUsageDescription`（「掃描領隊的入團 QR code 或團購券。」）
   - 顯示名稱：繁中 `旅行團`、英文 `TourChip`（`CFBundleDisplayName` ＋ `zh-Hant.lproj/InfoPlist.strings`）
   - 把 `platform_assets/ios/group_call.caf` 加進 Runner target（集合專屬提示音）
6. **Android 設定**（參考 `~/lbs_dating_app/android/app`）：
   - `applicationId = "com.softchip.tourchip"`，`compileSdk = 37`
   - 權限：`INTERNET`、`ACCESS_FINE_LOCATION`、`ACCESS_COARSE_LOCATION`、`CAMERA`、`POST_NOTIFICATIONS`、`VIBRATE`
   - App Links：`<intent-filter android:autoVerify="true">`，`https://tourchip.web.app/g/` 與 `/v/`
   - `platform_assets/android/raw/` 的 `group_call.wav`、`keep.xml` 複製到 `android/app/src/main/res/raw/`
   - App 名稱：`values/strings.xml` TourChip、`values-zh/strings.xml` 旅行團
   - 拿到簽章 SHA-256 後填進 `hosting/.well-known/assetlinks.json`
7. **後端部署**（只部署新的兩個 function，不動其他）：
   ```
   cd ~/lbs_dating_app/geo-service && npm test
   cd ~/lbs_dating_app && firebase deploy --only functions:tourGroup,functions:remindTourGroups
   ```
   在 Play Console 把 Cloud Functions 的服務帳號也加到新 App `com.softchip.tourchip`（「查看財務資料」），Google Play 購買驗證才會通過。
8. **官網**（在這個資料夾）：
   ```
   firebase hosting:sites:create tourchip --project mood-whisper-f7de9
   firebase deploy --only hosting:tourchip
   ```
   部署後打開 https://tourchip.web.app/.well-known/apple-app-site-association 確認是 JSON。`hosting/*.html` 裡的 `idREPLACE_APP_STORE_ID` 等上架後換成真的 App Store ID。
9. **商店**：
   - App Store Connect 新增 App，名稱「旅行團 TourChip－帶團集合點名」（英文「TourChip: Lead Your Group」），bundle `com.softchip.tourchip`；建立消耗型商品 `tour_pass_7d`，NT$290
   - Play Console 新增 App，建立一次性商品 `tour_pass_7d`
   - 隱私權政策網址 https://tourchip.web.app/privacy ；年齡分級不要選 18+（第一版開放未成年團員；沒有陌生人聊天、沒有公開內容）
10. **推播翻譯**：伺服器推播的中文原文要加進 `geo-service/i18n.js` 的翻譯表（英文至少）：
    「第 21 位團員正在等待入團，升級 7 天方案或使用團購券後就能加入。」「你成為這一團的共同團主了，可以發集合、點名和公告。」「你成為這一團的團主了。」「這一團已經解散，謝謝這幾天一起同行。」「點名：到了請按「我到了」」「… 號需要幫忙」「… 號迷路了，傳來了目前的位置」以及 `tourgroup.js` 的 `callText()`。

## 兩台手機實測清單

- [ ] A 開團（選分組 1 號車、2 號車）→ QR code → B 用 App 掃碼入團、用相機掃也能開 App 入團
- [ ] A 在名單把 B 設為共同團主；B 能發集合、點名、公告，不能解散
- [ ] 發集合：拖曳地圖放光柱 → C 手機響專屬提示音（鎖屏、專注模式都要響）→ 全螢幕卡片顯示當地時間、倒數、距離、方向 → 按「收到」
- [ ] 沒按收到的人每分鐘再響一次，最多 3 次；「單獨呼叫」只響那一個人
- [ ] 只叫 2 號車：1 號車的人看不到
- [ ] 點名三個答案；「需要幫忙」團主與共同團主都收到全螢幕提醒
- [ ] 我迷路了：團主地圖出現紅點與團號，「找到了」後消失；30 分鐘後自動消失
- [ ] 行程表：新增台北、東京的集合點，時間標籤正確；最後一個集合點改成東京後，解散時間變成東京 23:59
- [ ] 第 21 人入團被擋、團主收到通知 → 買 7 天方案（沙盒）→ 可入團
- [ ] 另一支手機（不在團裡）買團購券 → QR code → 團主掃描 → 升級；同一張券第二次掃描顯示已使用
- [ ] 換新 QR code 後舊的不能入團；交棒；團員退出；解散後所有人回到首頁
- [ ] 3D 地圖：光柱立在建築之間、選點時十字光柱對準地圖中心（`TourMap` 的 picking 覆蓋層可能要微調位置）
