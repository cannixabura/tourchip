import 'package:flutter/material.dart';

import '../l10n.dart';
import '../ui/night.dart';

/// 旅行團的資料（伺服器 geo-service/tourgroup_api.js 的 statusView）

const tourColors = {
  'violet': Color(0xFFB44CFF), 'pink': Color(0xFFFF5FD2), 'blue': Color(0xFF4F8BFF), 'teal': Color(0xFF3FD8E0),
  'green': Color(0xFF4DE3A0), 'gold': Color(0xFFFFD166), 'orange': Color(0xFFFF9F45), 'red': Color(0xFFFF6B7A),
};
Color tourColor(String? c) => tourColors[c] ?? Night.auroraViolet;

int? _int(Object? v) => (v as num?)?.toInt();
double? _dbl(Object? v) => (v as num?)?.toDouble();
String _str(Object? v) => v == null ? '' : '$v';

class TourMember {
  final String uid, name, note;
  final int no;
  final int? sub;
  /// 集合：ack / seen / none；點名：here / 5min / help / none；名單：''
  final String state;
  /// 大頭貼網址（團員自己在設定裡上傳的；沒有就是空字串）
  final String avatar;
  /// 團員自己填的資料（只有團主與共同團主拿得到）
  final MemberData? data;
  TourMember(this.uid, this.no, this.name, this.note, this.sub, this.state, {this.avatar = '', this.data});
  factory TourMember.fromJson(Map j, {String stateKey = ''}) =>
      TourMember(_str(j['uid']), _int(j['no']) ?? 0, _str(j['name']), _str(j['note']), _int(j['sub']), stateKey.isEmpty ? '' : _str(j[stateKey]),
          avatar: _str(j['avatar']), data: MemberData.fromJson(j['data']));
  /// 名單上顯示的稱呼：備註優先，其次暱稱
  String get label => note.isNotEmpty ? note : (name.isNotEmpty ? name : '');
}

class TourStaff {
  final String uid, name, role; // host / cohost
  final int no;
  final String avatar;
  TourStaff(this.uid, this.no, this.name, this.role, {this.avatar = ''});
}

class TourLost {
  final String uid, name, note;
  final int no, at;
  final double lat, lng;
  TourLost(this.uid, this.no, this.name, this.note, this.lat, this.lng, this.at);
}

class TourCall {
  final String id, place, tz;
  final int at;
  final double lat, lng;
  final int? sub;
  final String? mine; // seen / ack
  TourCall(this.id, this.at, this.tz, this.place, this.lat, this.lng, this.sub, this.mine);
}

class TourAnnouncement {
  final String id, text;
  final int at;
  final int? sub;
  TourAnnouncement(this.id, this.text, this.at, this.sub);
}

class TourStop {
  final String id, place, tz;
  final int at;
  final double? lat, lng;
  final int? sub;
  TourStop(this.id, this.at, this.tz, this.place, this.lat, this.lng, this.sub);
  Map<String, dynamic> toJson() => {'id': id, 'at': at, 'tz': tz, 'place': place, 'lat': lat, 'lng': lng, 'sub': sub};
}

/// 3D 地圖上同團的人（同意並開著分享、10 分鐘內有位置）
class TourPerson {
  final String uid, name, avatar, role, bubble;
  final int no, at;
  final double lat, lng;
  /// false：超過 30 分鐘沒有回應（App 被關掉、手機關機）→ 地圖上畫成灰色，位置是最後一次的
  final bool online;
  TourPerson(this.uid, this.no, this.name, this.avatar, this.role, this.bubble, this.lat, this.lng, this.at, {this.online = true});
  factory TourPerson.fromJson(Map j) => TourPerson(_str(j['uid']), _int(j['no']) ?? 0, _str(j['name']), _str(j['avatar']), _str(j['role']), _str(j['bubble']),
      _dbl(j['lat']) ?? 0, _dbl(j['lng']) ?? 0, _int(j['at']) ?? 0, online: j['online'] != false);
  bool get isStaff => role == 'host' || role == 'cohost';
}

/// 團裡的私訊
class TourMsg {
  final String id, from, to, text;
  final int at;
  final bool mine;
  TourMsg(this.id, this.from, this.to, this.text, this.at, this.mine);
  factory TourMsg.fromJson(Map j) => TourMsg(_str(j['id']), _str(j['from']), _str(j['to']), _str(j['text']), _int(j['at']) ?? 0, j['mine'] == true);
  /// 對話的另一方
  String get other => mine ? to : from;
}

/// 團員的稱呼（私訊、名單用）：團號、暱稱、大頭貼、身分
class TourWho {
  final int no;
  final String name, avatar, role;
  const TourWho(this.no, this.name, this.avatar, this.role);
}

class TourVoucher {
  final String code, link;
  final int createdAt;
  final bool used;
  /// people：人數券；days：天數券
  final String kind;
  TourVoucher(this.code, this.link, this.createdAt, this.used, this.kind);
  factory TourVoucher.fromJson(Map j) =>
      TourVoucher(_str(j['code']), _str(j['link']), _int(j['createdAt']) ?? 0, j['used'] == true, j['kind'] == 'days' ? 'days' : 'people');
  bool get isDays => kind == 'days';
}

/// 團員資料：飲食禁忌、健康狀況、緊急聯絡人稱呼（團員自己填，只有團主與共同團主看得到；不收電話）
class MemberData {
  final String diet, health, contact;
  const MemberData(this.diet, this.health, this.contact);
  static MemberData? fromJson(Object? j) => j is Map ? MemberData(_str(j['diet']), _str(j['health']), _str(j['contact'])) : null;
  bool get isEmpty => diet.isEmpty && health.isEmpty && contact.isEmpty;
}

/// 每日資訊卡的飯店
class TourHotel {
  final String name, addr, phone;
  final double? lat, lng;
  const TourHotel(this.name, this.addr, this.phone, this.lat, this.lng);
  static TourHotel? fromJson(Object? j) => j is Map ? TourHotel(_str(j['name']), _str(j['addr']), _str(j['phone']), _dbl(j['lat']), _dbl(j['lng'])) : null;
  Map<String, dynamic> toJson() => {'name': name, 'addr': addr, 'phone': phone, 'lat': lat, 'lng': lng};
  bool get hasCoord => lat != null && lng != null;
}

class GuideLink {
  final String title, url;
  const GuideLink(this.title, this.url);
  Map<String, dynamic> toJson() => {'title': title, 'url': url};
}

/// 每日資訊卡：日期（YYYY-MM-DD）、說明、今晚的飯店、攻略連結
class DayCard {
  final String date, note;
  final TourHotel? hotel;
  final List<GuideLink> links;
  const DayCard(this.date, this.note, this.hotel, this.links);
  factory DayCard.fromJson(Map j) => DayCard(_str(j['date']), _str(j['note']), TourHotel.fromJson(j['hotel']),
      [for (final l in (j['links'] as List? ?? const [])) GuideLink(_str(l['title']), _str(l['url']))]);
}

/// 車輛（全團或某一組）
class TourBus {
  final int? sub;
  final String plate, desc, driver, phone, note;
  const TourBus(this.sub, this.plate, this.desc, this.driver, this.phone, this.note);
  factory TourBus.fromJson(Map j) => TourBus(_int(j['sub']), _str(j['plate']), _str(j['desc']), _str(j['driver']), _str(j['phone']), _str(j['note']));
  Map<String, dynamic> toJson() => {'sub': sub, 'plate': plate, 'desc': desc, 'driver': driver, 'phone': phone, 'note': note};
}

/// 緊急聯絡：領隊電話、旅行社、旅行社 24 小時電話、其他說明
class TourEmergency {
  final String phone, agency, agencyPhone, note;
  const TourEmergency(this.phone, this.agency, this.agencyPhone, this.note);
  factory TourEmergency.fromJson(Object? j) => j is Map
      ? TourEmergency(_str(j['phone']), _str(j['agency']), _str(j['agencyPhone']), _str(j['note']))
      : const TourEmergency('', '', '', '');
  Map<String, dynamic> toJson() => {'phone': phone, 'agency': agency, 'agencyPhone': agencyPhone, 'note': note};
  bool get isEmpty => phone.isEmpty && agency.isEmpty && agencyPhone.isEmpty && note.isEmpty;
}

class TourGroup {
  final String code, name, color, role, hostName, tz, startDate, endDate;
  final int endsAt, limit, count;
  /// 想要的天數、目前能用的天數（免費 3 天＋天數券）、還要買幾張天數券
  final int days, allowedDays, daysNeeded;
  final List<DayCard> dayCards;
  final List<TourBus> buses;
  final TourEmergency emergency;
  final MemberData? myData;
  final int? myNo, mySub;
  final bool paid, lostSent;
  final String? qr;
  /// 8 位數邀請碼（只有團主與共同團主拿得到）
  final String? invite;
  final List<String> subs;
  final List<TourStaff> staff;
  final TourCall? call;
  final String? rollId, rollMine;
  final int? rollSub;
  final List<TourMember> members, callRoster, rollRoster;
  final int acked, callTotal, here, late, help, rollTotal;
  final List<TourLost> lost;
  final List<TourAnnouncement> announcements;
  final List<TourStop> stops;
  final List<TourPerson> people;
  final List<TourMsg> messages;
  final Map<String, TourWho> names;
  final List<String> blocked;
  final String myBubble;
  /// 分享位置：同意過（已滿 18 歲或家長同意）、開著
  final bool shareConsent, shareOn;

  TourGroup.fromJson(Map<String, dynamic> j)
      : code = _str(j['code']), name = _str(j['name']), color = _str(j['color']), role = _str(j['role']), hostName = _str(j['hostName']),
        tz = _str(j['tz']), startDate = _str(j['startDate']), endDate = _str(j['endDate']),
        endsAt = _int(j['endsAt']) ?? 0, limit = _int(j['limit']) ?? 20, count = _int(j['count']) ?? 0,
        days = _int(j['days']) ?? 1, allowedDays = _int(j['allowedDays']) ?? 3, daysNeeded = _int(j['daysNeeded']) ?? 0,
        dayCards = [for (final d in (j['dayCards'] as List? ?? const [])) DayCard.fromJson(d)],
        buses = [for (final b in ((j['info'] as Map?)?['buses'] as List? ?? const [])) TourBus.fromJson(b)],
        emergency = TourEmergency.fromJson((j['info'] as Map?)?['emergency']),
        myData = MemberData.fromJson(j['myData']),
        myNo = _int(j['myNo']), mySub = _int(j['mySub']), paid = j['paid'] == true, lostSent = j['lostSent'] == true,
        qr = j['qr'] as String?,
        invite = j['invite'] as String?,
        subs = [for (final s in (j['subs'] as List? ?? const [])) '$s'],
        staff = [for (final s in (j['staff'] as List? ?? const [])) TourStaff(_str(s['uid']), _int(s['no']) ?? 0, _str(s['name']), _str(s['role']), avatar: _str(s['avatar']))],
        call = j['call'] is Map
            ? TourCall(_str(j['call']['id']), _int(j['call']['at']) ?? 0, _str(j['call']['tz']), _str(j['call']['place']),
                _dbl(j['call']['lat']) ?? 0, _dbl(j['call']['lng']) ?? 0, _int(j['call']['sub']), j['call']['mine'] as String?)
            : null,
        rollId = j['roll'] is Map ? _str(j['roll']['id']) : null,
        rollMine = j['roll'] is Map ? j['roll']['mine'] as String? : null,
        rollSub = j['roll'] is Map ? _int(j['roll']['sub']) : null,
        members = [for (final m in (j['members'] as List? ?? const [])) TourMember.fromJson(m)],
        callRoster = [for (final m in ((j['callRoster'] as Map?)?['rows'] as List? ?? const [])) TourMember.fromJson(m, stateKey: 'state')],
        rollRoster = [for (final m in ((j['rollRoster'] as Map?)?['rows'] as List? ?? const [])) TourMember.fromJson(m, stateKey: 'answer')],
        acked = _int((j['callRoster'] as Map?)?['acked']) ?? 0,
        callTotal = _int((j['callRoster'] as Map?)?['total']) ?? 0,
        here = _int((j['rollRoster'] as Map?)?['here']) ?? 0,
        late = _int((j['rollRoster'] as Map?)?['late']) ?? 0,
        help = _int((j['rollRoster'] as Map?)?['help']) ?? 0,
        rollTotal = _int((j['rollRoster'] as Map?)?['total']) ?? 0,
        lost = [
          for (final m in (j['lost'] as List? ?? const []))
            TourLost(_str(m['uid']), _int(m['no']) ?? 0, _str(m['name']), _str(m['note']), _dbl(m['lat']) ?? 0, _dbl(m['lng']) ?? 0, _int(m['at']) ?? 0)
        ],
        announcements = [for (final a in (j['announcements'] as List? ?? const [])) TourAnnouncement(_str(a['id']), _str(a['text']), _int(a['at']) ?? 0, _int(a['sub']))],
        stops = [
          for (final s in (j['stops'] as List? ?? const []))
            TourStop(_str(s['id']), _int(s['at']) ?? 0, _str(s['tz']), _str(s['place']), _dbl(s['lat']), _dbl(s['lng']), _int(s['sub']))
        ],
        people = [for (final p in (j['people'] as List? ?? const [])) TourPerson.fromJson(p)],
        messages = [for (final m in (j['messages'] as List? ?? const [])) TourMsg.fromJson(m)],
        names = {
          for (final e in ((j['names'] as Map?) ?? const {}).entries)
            '${e.key}': TourWho(_int(e.value['no']) ?? 0, _str(e.value['name']), _str(e.value['avatar']), _str(e.value['role']))
        },
        blocked = [for (final b in (j['blocked'] as List? ?? const [])) '$b'],
        myBubble = _str(j['myBubble']),
        shareConsent = (j['share'] as Map?)?['consent'] == true,
        shareOn = (j['share'] as Map?)?['on'] == true;

  /// 怎麼稱呼某個人：暱稱，沒有就「3 號」；團主、共同團主加身分
  String whoLabel(String uid) {
    final w = names[uid];
    if (w == null) return tx('已離團', 'Left the group');
    final base = w.name.isNotEmpty ? w.name : tx('${w.no} 號', 'No. ${w.no}');
    return switch (w.role) { 'host' => tx('團主 · $base', 'Leader · $base'), 'cohost' => tx('共同團主 · $base', 'Co-leader · $base'), _ => base };
  }

  bool get isHost => role == 'host';
  /// 團主或共同團主：可以集合、點名、公告、改行程
  bool get isStaff => role == 'host' || role == 'cohost';
  Color get tint => tourColor(color);
  String subName(int? i) => i == null || i < 0 || i >= subs.length ? '' : subs[i];
  DayCard? dayCard(String date) => dayCards.where((d) => d.date == date).firstOrNull;
  /// 我坐的車：自己那一組的車，沒有就用全團的車（團主、共同團主看全部）
  List<TourBus> get myBuses {
    if (isStaff) return buses;
    final mine = buses.where((b) => b.sub != null && b.sub == mySub).toList();
    return mine.isNotEmpty ? mine : buses.where((b) => b.sub == null).toList();
  }
}
