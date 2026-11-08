import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'service.dart';

/// 我的暱稱與頭像。
/// 頭像上傳到 Firebase Storage 的 `avatars/<uid>.jpg`（沿用城市低語的 Storage 規則：只能傳自己的、5MB 以內的圖片）；
/// 暱稱與頭像網址存在伺服器的 tgroup_profile（旅行團自己的，和城市低語的個人資料各自獨立），
/// 團主、共同團主在名單上看得到。手機上也存一份，打開 App 時不必等伺服器。
class MyProfile {
  final String name, avatar;
  const MyProfile(this.name, this.avatar);
  static const empty = MyProfile('', '');
  bool get isEmpty => name.isEmpty && avatar.isEmpty;
}

class ProfileStore {
  ProfileStore._();
  static final me = ValueNotifier<MyProfile>(MyProfile.empty);
  static const maxName = 10;

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      me.value = MyProfile(p.getString('profile_name') ?? '', p.getString('profile_avatar') ?? '');
    } catch (_) {}
  }

  /// 伺服器回傳的 profile（status、profile 兩個動作都會帶）
  static Future<void> apply(Object? raw) async {
    if (raw is! Map) return;
    final next = MyProfile('${raw['name'] ?? ''}', '${raw['avatar'] ?? ''}');
    // 伺服器還沒有（舊版、剛重裝）但手機上有：補送一次
    if (next.isEmpty && !me.value.isEmpty) {
      TourService.call('profile', {'name': me.value.name, 'avatar': me.value.avatar});
      return;
    }
    await _keep(next);
  }

  static Future<void> _keep(MyProfile p) async {
    me.value = p;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_name', p.name);
      await prefs.setString('profile_avatar', p.avatar);
    } catch (_) {}
  }

  /// 儲存：有新照片先上傳，再把暱稱與網址送到伺服器。回傳錯誤代碼（null 表示成功）
  static Future<String?> save({required String name, File? photo, bool removePhoto = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'auth';
    var avatar = removePhoto ? '' : me.value.avatar;
    final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
    try {
      if (photo != null) {
        await ref.putFile(photo, SettableMetadata(contentType: 'image/jpeg'));
        avatar = await ref.getDownloadURL();
      } else if (removePhoto && me.value.avatar.isNotEmpty) {
        await ref.delete().catchError((_) {});
      }
    } catch (_) {
      return 'upload';
    }
    final r = await TourService.call('profile', {'name': name.trim(), 'avatar': avatar});
    if (r['success'] != true) return '${r['code'] ?? 'busy'}';
    await _keep(MyProfile('${(r['profile'] as Map?)?['name'] ?? name.trim()}', '${(r['profile'] as Map?)?['avatar'] ?? avatar}'));
    return null;
  }
}
