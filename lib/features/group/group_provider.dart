// グループ機能の状態とデータ取得を管理するProvider群。
// グループの作成・参加、グループ情報・メンバー・投稿一覧の取得を担当。
// 方針に従い、Supabaseを直接呼ぶ（共有リポジトリ層は作らない）。

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../core/supabase_client.dart';
import '../../models/app_user.dart';
import '../../models/group.dart';

// グループ詳細画面で1件の投稿を表示するためのビューモデル。
// post_shares・posts・users を結合した表示用データ。
class GroupPost {
  const GroupPost({
    required this.postId,
    required this.userId,
    required this.videoUrl,
    required this.userName,
    required this.createdAt,
    this.needsFlip = false,
    this.platform = 'mobile',
  });

  final String postId;
  final String userId;
  final String videoUrl;
  final String userName;
  final DateTime createdAt;
  // ファイル自体が上下逆に記録された動画(Android前面カメラ等)の補正フラグ。
  final bool needsFlip;
  final String platform;
}

// 投稿一覧取得の引数（グループ・日付・時間帯）。FutureProvider.family のキー。
class GroupPostsArgs {
  const GroupPostsArgs({
    required this.groupId,
    required this.date,
    required this.hour,
  });

  final String groupId;
  // 日付（時刻は無視し YYYY-MM-DD として扱う）。
  final DateTime date;
  final int hour;

  // post_shares.shared_date（DATE型）に渡す 'YYYY-MM-DD' 文字列。
  String get sharedDate =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is GroupPostsArgs &&
      other.groupId == groupId &&
      other.sharedDate == sharedDate &&
      other.hour == hour;

  @override
  int get hashCode => Object.hash(groupId, sharedDate, hour);
}

// グループ関連のSupabase操作をまとめたサービス。
class GroupService {
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  // 運営の共有Supabaseに新しいカラムを追加できないため、
  // ランダム部屋かどうかはグループ名の前方一致だけで判別する。
  static const _randomRoomPrefix = 'ランダム部屋';
  static const _randomRoomCapacity = 4;

  String get _currentUserId {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('ログインしていません');
    }
    return user.id;
  }

  String _generateInviteCode() {
    final rand = Random.secure();
    return List.generate(6, (_) => _codeChars[rand.nextInt(_codeChars.length)])
        .join();
  }

  // グループを作成し、作成者を自動的にメンバーへ追加する。
  Future<Group> createGroup(String name) async {
    final userId = _currentUserId;

    // 招待コードの重複（UNIQUE違反）に備えて数回リトライする。
    Map<String, dynamic>? inserted;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        inserted = await supabase
            .from('groups')
            .insert({
              'name': name,
              'invite_code': _generateInviteCode(),
              'owner_id': userId,
            })
            .select()
            .single();
        break;
      } on Exception {
        if (attempt == 4) rethrow;
      }
    }

    final group = Group.fromJson(inserted!);
    await supabase.from('group_members').insert({
      'group_id': group.id,
      'user_id': userId,
    });
    // ⚠️ 計測用イベント。この行だけを削除しないこと（createGroup機能ごと消すのはOK）
    Analytics.log('group_created', {'group_id': group.id});
    return group;
  }

  // 招待コードからグループを探して参加する。
  Future<Group> joinGroup(String inviteCode) async {
    final userId = _currentUserId;
    final code = inviteCode.trim().toUpperCase();

    final found = await supabase
        .from('groups')
        .select()
        .eq('invite_code', code)
        .maybeSingle();
    if (found == null) {
      throw Exception('招待コードが見つかりません');
    }
    final group = Group.fromJson(found);

    final already = await supabase
        .from('group_members')
        .select('id')
        .eq('group_id', group.id)
        .eq('user_id', userId)
        .maybeSingle();
    if (already != null) {
      throw Exception('すでに参加しています');
    }

    await supabase.from('group_members').insert({
      'group_id': group.id,
      'user_id': userId,
    });
    // ⚠️ 計測用イベント。この行だけを削除しないこと（joinGroup機能ごと消すのはOK）
    Analytics.log('group_joined', {'group_id': group.id});
    return group;
  }

  // 空きのあるランダム部屋に参加する。無ければ新しい部屋を作って最初のメンバーになる。
  Future<Group> joinRandomGroup() async {
    final userId = _currentUserId;

    final rows = await supabase
        .from('groups')
        .select()
        .ilike('name', '$_randomRoomPrefix%')
        .order('created_at');
    final rooms = rows.map(Group.fromJson).toList();

    final counts = <String, int>{};
    final joinedRoomIds = <String>{};
    if (rooms.isNotEmpty) {
      final members = await supabase
          .from('group_members')
          .select('group_id, user_id')
          .inFilter('group_id', rooms.map((room) => room.id).toList());
      for (final member in members) {
        final groupId = member['group_id'] as String;
        counts[groupId] = (counts[groupId] ?? 0) + 1;
        if (member['user_id'] == userId) {
          joinedRoomIds.add(groupId);
        }
      }
    }

    Group? target;
    var targetCount = -1;
    var maxNumber = 0;
    for (final room in rooms) {
      maxNumber = max(maxNumber, _randomRoomNumber(room.name));
      final count = counts[room.id] ?? 0;
      if (joinedRoomIds.contains(room.id) || count >= _randomRoomCapacity) {
        continue;
      }
      // 部屋を1つずつ埋めていくため、空きのある中で最も人数が多い部屋を選ぶ。
      if (count > targetCount) {
        target = room;
        targetCount = count;
      }
    }

    // 人数の確認と参加を1つのトランザクションにできないため、
    // 複数人が同時に最後の枠へ入ると定員4人を超えることがある。
    // ハッカソン用途では許容し、多少の超過はそのままにする。
    if (target == null) {
      final created =
          await createGroup('$_randomRoomPrefix #${maxNumber + 1}');
      Analytics.log('random_room_joined', {
        'group_id': created.id,
        'created_room': true,
        'member_count': 1,
      });
      return created;
    }

    await supabase.from('group_members').insert({
      'group_id': target.id,
      'user_id': userId,
    });
    Analytics.log('random_room_joined', {
      'group_id': target.id,
      'created_room': false,
      'member_count': targetCount + 1,
    });
    return target;
  }

  // 「ランダム部屋 #12」から番号12を取り出す。取れなければ0。
  int _randomRoomNumber(String name) {
    final match = RegExp(r'#\s*(\d+)').firstMatch(name);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!) ?? 0;
  }

  // 参加中のグループから脱退する。自分の group_members の行を削除する。
  // オーナーも一般メンバーと同じ扱いで抜けられる（owner_id は参照しない）。
  Future<void> leaveGroup(String groupId) async {
    final userId = _currentUserId;

    // RLSのDELETEポリシーが無い場合はエラーにならず0行削除になるため、
    // select() で実際に削除された行を確認する。
    final deleted = await supabase
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .select();
    if (deleted.isEmpty) {
      throw Exception('参加情報が見つかりませんでした');
    }
    // ⚠️ 計測用イベント。この行だけを削除しないこと（leaveGroup機能ごと消すのはOK）
    Analytics.log('group_left', {'group_id': groupId});
  }

  Future<Group> fetchGroup(String groupId) async {
    final json =
        await supabase.from('groups').select().eq('id', groupId).maybeSingle();
    if (json == null) {
      throw Exception('グループが見つかりません');
    }
    return Group.fromJson(json);
  }

  Future<List<AppUser>> fetchMembers(String groupId) async {
    final rows = await supabase
        .from('group_members')
        .select('users(id, name, created_at)')
        .eq('group_id', groupId)
        .order('joined_at');
    return rows
        .map((row) => AppUser.fromJson(row['users'] as Map<String, dynamic>))
        .toList();
  }

  // 指定グループ・日付・時間帯の投稿一覧を取得する。
  Future<List<GroupPost>> fetchPosts(GroupPostsArgs args) async {
    final rows = await supabase
        .from('post_shares')
        .select(
            'created_at, posts!inner(id, user_id, video_url, needs_flip, platform, created_at, users(name))')
        .eq('group_id', args.groupId)
        .eq('shared_date', args.sharedDate)
        .eq('shared_hour', args.hour)
        .order('created_at');

    return rows.map((row) {
      final post = row['posts'] as Map<String, dynamic>;
      final user = post['users'] as Map<String, dynamic>?;
      return GroupPost(
        postId: post['id'] as String,
        userId: post['user_id'] as String,
        videoUrl: post['video_url'] as String,
        userName: (user?['name'] as String?) ?? '名無し',
        createdAt: DateTime.parse(post['created_at'] as String),
        needsFlip: post['needs_flip'] as bool? ?? false,
        platform: post['platform'] as String? ?? 'mobile',
      );
    }).toList();
  }
}

final groupServiceProvider = Provider<GroupService>((ref) => GroupService());

// グループ基本情報を取得するProvider。
// autoDispose: 画面を開くたびに最新を取得する（古いキャッシュを残さない）。
final groupProvider =
    FutureProvider.autoDispose.family<Group, String>((ref, groupId) {
  return ref.read(groupServiceProvider).fetchGroup(groupId);
});

// グループのメンバー一覧を取得するProvider。
final groupMembersProvider =
    FutureProvider.autoDispose.family<List<AppUser>, String>((ref, groupId) {
  return ref.read(groupServiceProvider).fetchMembers(groupId);
});

// 指定した日付・時間帯のグループ投稿一覧を取得するProvider。
// autoDispose にすることで、送信後に開き直すと投稿が反映される。
final groupPostsProvider =
    FutureProvider.autoDispose.family<List<GroupPost>, GroupPostsArgs>(
        (ref, args) {
  return ref.read(groupServiceProvider).fetchPosts(args);
});
