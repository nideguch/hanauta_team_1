// ユーザー情報のデータモデル。Supabaseのusersテーブルと対応。
// ※ DartのUser名はSupabase Authと衝突しやすいため AppUser とする。

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.createdAt,
    this.iconUrl,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  // アイコン画像。プリセットは 'assets/avatars/xxx.jpeg'、それ以外はURL。
  final String? iconUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      iconUrl: json['icon_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'icon_url': iconUrl,
    };
  }
}
