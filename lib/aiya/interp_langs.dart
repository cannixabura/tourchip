import '../l10n.dart';
import '../screens/help_card.dart' show localLangFor;
import '../translate.dart' show ChineseConverter;

/// 口譯可以選的語言（約 60 種）：OpenAI 高品質 AI 都能翻；免費模式依手機實際支援（語音辨識、翻譯、朗讀）判斷。
/// 伺服器 geo-service/aiya.js 的 INTERPRET_LANGS 要和這裡的代碼一致。
class InterpLang {
  final String code;
  /// 這個語言自己的名稱（給當地人看）
  final String native;
  /// 中文名稱（繁體；簡中介面自動轉簡體）
  final String zh;
  final String en;
  /// 語音辨識、朗讀用的地區代碼，依序試
  final List<String> locales;
  /// 翻譯用的語言代碼（預設＝code；粵語用繁中翻譯）
  final String? trans;
  const InterpLang(this.code, this.native, this.zh, this.en, this.locales, {this.trans});

  String get translateCode => trans ?? code;

  /// 清單上的第二行：使用者介面語言的名稱
  String get localName => switch (lang) {
        'zh-Hant' => zh,
        'zh-Hans' => ChineseConverter.toSimplified(zh),
        _ => en,
      };
}

const interpLangList = <InterpLang>[
  InterpLang('zh-Hant', '繁體中文', '繁體中文', 'Chinese (Traditional)', ['zh-TW', 'zh-HK']),
  InterpLang('zh-Hans', '简体中文', '簡體中文', 'Chinese (Simplified)', ['zh-CN', 'zh-SG']),
  InterpLang('yue', '廣東話', '廣東話（粵語）', 'Cantonese', ['zh-HK', 'yue-HK', 'yue-CN'], trans: 'zh-Hant'),
  InterpLang('en', 'English', '英文', 'English', ['en-US', 'en-GB', 'en-AU', 'en-IN']),
  InterpLang('ja', '日本語', '日文', 'Japanese', ['ja-JP']),
  InterpLang('ko', '한국어', '韓文', 'Korean', ['ko-KR']),
  InterpLang('th', 'ไทย', '泰文', 'Thai', ['th-TH']),
  InterpLang('vi', 'Tiếng Việt', '越南文', 'Vietnamese', ['vi-VN']),
  InterpLang('id', 'Bahasa Indonesia', '印尼文', 'Indonesian', ['id-ID']),
  InterpLang('ms', 'Bahasa Melayu', '馬來文', 'Malay', ['ms-MY']),
  InterpLang('fil', 'Filipino', '菲律賓文', 'Filipino', ['fil-PH', 'tl-PH']),
  InterpLang('my', 'မြန်မာ', '緬甸文', 'Burmese', ['my-MM']),
  InterpLang('km', 'ខ្មែរ', '高棉文', 'Khmer', ['km-KH']),
  InterpLang('lo', 'ລາວ', '寮文', 'Lao', ['lo-LA']),
  InterpLang('mn', 'Монгол', '蒙古文', 'Mongolian', ['mn-MN']),
  InterpLang('hi', 'हिन्दी', '印地文', 'Hindi', ['hi-IN']),
  InterpLang('bn', 'বাংলা', '孟加拉文', 'Bengali', ['bn-BD', 'bn-IN']),
  InterpLang('ur', 'اردو', '烏爾都文', 'Urdu', ['ur-PK', 'ur-IN']),
  InterpLang('ne', 'नेपाली', '尼泊爾文', 'Nepali', ['ne-NP']),
  InterpLang('si', 'සිංහල', '僧伽羅文', 'Sinhala', ['si-LK']),
  InterpLang('ta', 'தமிழ்', '坦米爾文', 'Tamil', ['ta-IN', 'ta-LK', 'ta-SG', 'ta-MY']),
  InterpLang('te', 'తెలుగు', '泰盧固文', 'Telugu', ['te-IN']),
  InterpLang('mr', 'मराठी', '馬拉地文', 'Marathi', ['mr-IN']),
  InterpLang('gu', 'ગુજરાતી', '古吉拉特文', 'Gujarati', ['gu-IN']),
  InterpLang('kn', 'ಕನ್ನಡ', '卡納達文', 'Kannada', ['kn-IN']),
  InterpLang('ml', 'മലയാളം', '馬拉雅拉姆文', 'Malayalam', ['ml-IN']),
  InterpLang('pa', 'ਪੰਜਾਬੀ', '旁遮普文', 'Punjabi', ['pa-IN']),
  InterpLang('kk', 'Қазақ', '哈薩克文', 'Kazakh', ['kk-KZ']),
  InterpLang('uz', "O'zbek", '烏茲別克文', 'Uzbek', ['uz-UZ']),
  InterpLang('fr', 'Français', '法文', 'French', ['fr-FR', 'fr-CA', 'fr-BE', 'fr-CH']),
  InterpLang('de', 'Deutsch', '德文', 'German', ['de-DE', 'de-AT', 'de-CH']),
  InterpLang('it', 'Italiano', '義大利文', 'Italian', ['it-IT', 'it-CH']),
  InterpLang('es', 'Español', '西班牙文', 'Spanish', ['es-ES', 'es-MX', 'es-US', 'es-AR', 'es-CO']),
  InterpLang('pt', 'Português', '葡萄牙文', 'Portuguese', ['pt-BR', 'pt-PT']),
  InterpLang('nl', 'Nederlands', '荷蘭文', 'Dutch', ['nl-NL', 'nl-BE']),
  InterpLang('ca', 'Català', '加泰隆尼亞文', 'Catalan', ['ca-ES']),
  InterpLang('el', 'Ελληνικά', '希臘文', 'Greek', ['el-GR']),
  InterpLang('ru', 'Русский', '俄文', 'Russian', ['ru-RU']),
  InterpLang('uk', 'Українська', '烏克蘭文', 'Ukrainian', ['uk-UA']),
  InterpLang('pl', 'Polski', '波蘭文', 'Polish', ['pl-PL']),
  InterpLang('cs', 'Čeština', '捷克文', 'Czech', ['cs-CZ']),
  InterpLang('sk', 'Slovenčina', '斯洛伐克文', 'Slovak', ['sk-SK']),
  InterpLang('hu', 'Magyar', '匈牙利文', 'Hungarian', ['hu-HU']),
  InterpLang('ro', 'Română', '羅馬尼亞文', 'Romanian', ['ro-RO']),
  InterpLang('bg', 'Български', '保加利亞文', 'Bulgarian', ['bg-BG']),
  InterpLang('hr', 'Hrvatski', '克羅埃西亞文', 'Croatian', ['hr-HR']),
  InterpLang('sr', 'Српски', '塞爾維亞文', 'Serbian', ['sr-RS']),
  InterpLang('sl', 'Slovenščina', '斯洛維尼亞文', 'Slovenian', ['sl-SI']),
  InterpLang('sv', 'Svenska', '瑞典文', 'Swedish', ['sv-SE']),
  InterpLang('da', 'Dansk', '丹麥文', 'Danish', ['da-DK']),
  InterpLang('no', 'Norsk', '挪威文', 'Norwegian', ['nb-NO', 'no-NO']),
  InterpLang('fi', 'Suomi', '芬蘭文', 'Finnish', ['fi-FI']),
  InterpLang('et', 'Eesti', '愛沙尼亞文', 'Estonian', ['et-EE']),
  InterpLang('lv', 'Latviešu', '拉脫維亞文', 'Latvian', ['lv-LV']),
  InterpLang('lt', 'Lietuvių', '立陶宛文', 'Lithuanian', ['lt-LT']),
  InterpLang('is', 'Íslenska', '冰島文', 'Icelandic', ['is-IS']),
  InterpLang('tr', 'Türkçe', '土耳其文', 'Turkish', ['tr-TR']),
  InterpLang('ar', 'العربية', '阿拉伯文', 'Arabic', ['ar-SA', 'ar-AE', 'ar-EG']),
  InterpLang('he', 'עברית', '希伯來文', 'Hebrew', ['he-IL', 'iw-IL']),
  InterpLang('fa', 'فارسی', '波斯文', 'Persian', ['fa-IR']),
  InterpLang('sw', 'Kiswahili', '斯瓦希里文', 'Swahili', ['sw-KE', 'sw-TZ']),
  InterpLang('am', 'አማርኛ', '阿姆哈拉文', 'Amharic', ['am-ET']),
  InterpLang('af', 'Afrikaans', '南非荷蘭文', 'Afrikaans', ['af-ZA']),
];

final Map<String, InterpLang> interpLangByCode = {for (final l in interpLangList) l.code: l};

InterpLang interpLang(String code) => interpLangByCode[code] ?? interpLangByCode['en']!;

/// 兩個口譯語言是不是「同一種」（翻譯代碼的主語言相同，例如 zh-Hant 與 zh-Hans、粵語與繁中）
bool interpSameBase(String a, String b) =>
    interpLang(a).translateCode.split('-').first == interpLang(b).translateCode.split('-').first;

/// 偵測到的語言（ChatTranslator.detect 的結果，例如 ja、zh-Hant）是不是這個口譯語言
bool interpMatches(String detected, String code) =>
    detected.split('-').first == interpLang(code).translateCode.split('-').first;

/// 對方預設說什麼：依現在所在地（集合點、行程表的時區；沒入團就看手機的時區）
String interpLangFor(String tz) {
  const m = {
    'Asia/Hong_Kong': 'yue', 'Asia/Macau': 'yue',
    'Europe/Paris': 'fr', 'Europe/Monaco': 'fr', 'Europe/Brussels': 'fr', 'Europe/Luxembourg': 'fr',
    'Europe/Berlin': 'de', 'Europe/Vienna': 'de', 'Europe/Zurich': 'de',
    'Europe/Rome': 'it', 'Europe/Vatican': 'it', 'Europe/San_Marino': 'it', 'Europe/Malta': 'en',
    'Europe/Moscow': 'ru', 'Europe/Minsk': 'ru', 'Europe/Kiev': 'uk', 'Europe/Kyiv': 'uk',
    'Europe/Istanbul': 'tr', 'Asia/Istanbul': 'tr', 'Europe/Amsterdam': 'nl',
    'Europe/Warsaw': 'pl', 'Europe/Prague': 'cs', 'Europe/Bratislava': 'sk', 'Europe/Budapest': 'hu',
    'Europe/Bucharest': 'ro', 'Europe/Sofia': 'bg', 'Europe/Zagreb': 'hr', 'Europe/Belgrade': 'sr', 'Europe/Ljubljana': 'sl',
    'Europe/Athens': 'el', 'Europe/Stockholm': 'sv', 'Europe/Copenhagen': 'da', 'Europe/Oslo': 'no', 'Europe/Helsinki': 'fi',
    'Europe/Tallinn': 'et', 'Europe/Riga': 'lv', 'Europe/Vilnius': 'lt', 'Atlantic/Reykjavik': 'is',
    'Asia/Dubai': 'ar', 'Asia/Riyadh': 'ar', 'Asia/Qatar': 'ar', 'Asia/Kuwait': 'ar', 'Asia/Bahrain': 'ar', 'Asia/Muscat': 'ar',
    'Asia/Amman': 'ar', 'Africa/Cairo': 'ar', 'Africa/Casablanca': 'ar', 'Africa/Tunis': 'ar',
    'Asia/Jerusalem': 'he', 'Asia/Tel_Aviv': 'he', 'Asia/Tehran': 'fa',
    'Asia/Manila': 'fil', 'Asia/Yangon': 'my', 'Asia/Rangoon': 'my', 'Asia/Phnom_Penh': 'km', 'Asia/Vientiane': 'lo',
    'Asia/Ulaanbaatar': 'mn', 'Asia/Dhaka': 'bn', 'Asia/Karachi': 'ur', 'Asia/Kathmandu': 'ne', 'Asia/Katmandu': 'ne',
    'Asia/Colombo': 'si', 'Asia/Almaty': 'kk', 'Asia/Tashkent': 'uz',
    'Africa/Nairobi': 'sw', 'Africa/Dar_es_Salaam': 'sw', 'Africa/Addis_Ababa': 'am',
  };
  return m[tz] ?? localLangFor(tz);
}
