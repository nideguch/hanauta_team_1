// ログイン画面の訪問者カウンター。ブラウザ（端末）ごとにローカルへ保存し、
// このブラウザで何回目のアクセスかを表示する。他端末とは共有しない。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _visitCountKey = 'visit_count';

final visitCounterProvider = FutureProvider.autoDispose<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final count = (prefs.getInt(_visitCountKey) ?? 0) + 1;
  await prefs.setInt(_visitCountKey, count);
  return count;
});
