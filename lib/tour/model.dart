import 'package:flutter/material.dart';

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
  TourMember(this.uid, this.no, this.name, this.note, this.sub, this.state, {this.avatar = ''});
  factory TourMember.fromJson(Map j, {String stateKey = ''}) =>
      TourMember(_str(j['uid']), _int(j['no']) ?? 0, _str(j['name']), _str(j['note']), _int(j['sub']), stateKey.isEmpty ? '' : _str(j[stateKey]), avatar: _str(j['avatar']));
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

class TourVoucher {
  final String code, link;
  final int createdAt;
  final bool used;
  TourVoucher(this.code, this.link, this.createdAt, this.used);
  factory TourVoucher.fromJson(Map j) => TourVoucher(_str(j['code']), _str(j['link']), _int(j['createdAt']) ?? 0, j['used'] == true);
}

class TourGroup {
  final String code, name, color, role, hostName, tz, startDate, endDate;
  final int endsAt, limit, count;
  final int? myNo, mySub;
  final bool paid, lostSent;
  final String? qr;
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

  TourGroup.fromJson(Map<String, dynamic> j)
      : code = _str(j['code']), name = _str(j['name']), color = _str(j['color']), role = _str(j['role']), hostName = _str(j['hostName']),
        tz = _str(j['tz']), startDate = _str(j['startDate']), endDate = _str(j['endDate']),
        endsAt = _int(j['endsAt']) ?? 0, limit = _int(j['limit']) ?? 20, count = _int(j['count']) ?? 0,
        myNo = _int(j['myNo']), mySub = _int(j['mySub']), paid = j['paid'] == true, lostSent = j['lostSent'] == true,
        qr = j['qr'] as String?,
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
        ];

  bool get isHost => role == 'host';
  /// 團主或共同團主：可以集合、點名、公告、改行程
  bool get isStaff => role == 'host' || role == 'cohost';
  Color get tint => tourColor(color);
  String subName(int? i) => i == null || i < 0 || i >= subs.length ? '' : subs[i];
}
