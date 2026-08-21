// アイコンガチャのデータとロジック。抽選・チケット残数・所持アイコンを管理する。
// 運営の共有Supabaseに専用テーブルを追加できないため、所持状況は
// analytics_events の gacha_pulled イベントを台帳代わりにして復元している。

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../core/supabase_client.dart';

// ガチャで当たるアイコン1件ぶん。weight が大きいほど出やすい（合計100）。
class GachaIcon {
  const GachaIcon({
    required this.label,
    required this.assetPath,
    required this.rarity,
    required this.weight,
  });

  final String label;
  final String assetPath;
  final int rarity;
  final int weight;

  String get stars => '★' * rarity;
}

const gachaIcons = [
  GachaIcon(
    label: 'ハローキティ',
    assetPath: 'assets/avatars/gacha/hellokitty.png',
    rarity: 3,
    weight: 5,
  ),
  GachaIcon(
    label: 'シナモロール',
    assetPath: 'assets/avatars/gacha/cinnamoroll.png',
    rarity: 2,
    weight: 15,
  ),
  GachaIcon(
    label: 'マイメロディ',
    assetPath: 'assets/avatars/gacha/mymelody.png',
    rarity: 2,
    weight: 15,
  ),
  GachaIcon(
    label: 'ポムポムプリン',
    assetPath: 'assets/avatars/gacha/pompompurin.png',
    rarity: 1,
    weight: 32,
  ),
  GachaIcon(
    label: 'ポチャッコ',
    assetPath: 'assets/avatars/gacha/pochacco.png',
    rarity: 1,
    weight: 33,
  ),
];

// 最初に配る無料ぶん。以降は動画を1本投稿するごとに1枚たまる。
const gachaBonusTickets = 3;

GachaIcon? gachaIconOf(String? assetPath) {
  for (final icon in gachaIcons) {
    if (icon.assetPath == assetPath) return icon;
  }
  return null;
}

// ガチャ画面の状態。残チケットと所持済みアイコン。
class GachaState {
  const GachaState({required this.tickets, required this.ownedPaths});

  final int tickets;
  final Set<String> ownedPaths;

  bool owns(GachaIcon icon) => ownedPaths.contains(icon.assetPath);
  bool get canDraw => tickets > 0;
}

// 抽選結果。初めて出たアイコンかどうかも返す。
class GachaResult {
  const GachaResult({required this.icon, required this.isNew});

  final GachaIcon icon;
  final bool isNew;
}

final gachaStateProvider = FutureProvider.autoDispose<GachaState>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    throw Exception('ログインしていません');
  }

  final pulls = await supabase
      .from('analytics_events')
      .select('properties')
      .eq('user_id', user.id)
      .eq('event_name', 'gacha_pulled');
  final posts =
      await supabase.from('posts').select('id').eq('user_id', user.id).count();

  final owned = <String>{};
  for (final row in pulls) {
    final properties = row['properties'] as Map<String, dynamic>?;
    final icon = properties?['icon'] as String?;
    if (icon != null) owned.add(icon);
  }

  final tickets = gachaBonusTickets + posts.count - pulls.length;
  return GachaState(
    tickets: tickets < 0 ? 0 : tickets,
    ownedPaths: owned,
  );
});

// 1回ぶん抽選し、結果を analytics_events に記録する（＝所持アイコンとして残る）。
Future<GachaResult> drawGacha(Set<String> ownedPaths) async {
  final total = gachaIcons.fold<int>(0, (sum, icon) => sum + icon.weight);
  var roll = Random().nextInt(total);
  var picked = gachaIcons.last;
  for (final icon in gachaIcons) {
    roll -= icon.weight;
    if (roll < 0) {
      picked = icon;
      break;
    }
  }

  await Analytics.log('gacha_pulled', {
    'icon': picked.assetPath,
    'rarity': picked.rarity,
  });
  return GachaResult(icon: picked, isNew: !ownedPaths.contains(picked.assetPath));
}
