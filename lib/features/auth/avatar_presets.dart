// 初期アイコンのプリセット定義と、アイコン表示・選択の共通ウィジェット。
// users.icon_url にはアセットのパス（assets/avatars/xxx.jpeg）をそのまま保存する。

import 'package:flutter/material.dart';

// 選択できる初期アイコン1件ぶん。
class AvatarPreset {
  const AvatarPreset({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

const avatarPresets = [
  AvatarPreset(label: 'アイアンマン', assetPath: 'assets/avatars/iron_man.jpeg'),
  AvatarPreset(
      label: 'キャプテン・アメリカ',
      assetPath: 'assets/avatars/captain_america.jpeg'),
  AvatarPreset(label: 'ソー', assetPath: 'assets/avatars/thor.jpeg'),
  AvatarPreset(label: 'ハルク', assetPath: 'assets/avatars/hulk.jpeg'),
  AvatarPreset(
      label: 'ブラック・ウィドウ', assetPath: 'assets/avatars/black_widow.jpeg'),
];

// 頭文字アバターの背景色。名前から決まるので同じ人は常に同じ色になる。
const _avatarColors = [
  Color(0xFF4FC3F7),
  Color(0xFF81C784),
  Color(0xFFFFB74D),
  Color(0xFFBA68C8),
  Color(0xFFE57373),
  Color(0xFF4DB6AC),
  Color(0xFF7986CB),
  Color(0xFFF06292),
];

Color avatarColorFor(String key) =>
    _avatarColors[key.hashCode.abs() % _avatarColors.length];

// icon_url の値から画像プロバイダを作る。プリセットはアセット、それ以外はURL扱い。
ImageProvider? avatarImageProvider(String? iconUrl) {
  if (iconUrl == null || iconUrl.isEmpty) return null;
  if (iconUrl.startsWith('assets/')) return AssetImage(iconUrl);
  return NetworkImage(iconUrl);
}

// ユーザーアイコン。icon_url が未設定のときは名前の頭文字を表示する。
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.iconUrl,
    this.radius = 16,
  });

  final String name;
  final String? iconUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = avatarImageProvider(iconUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColorFor(name),
      foregroundColor: Colors.white,
      backgroundImage: image,
      child: image != null
          ? null
          : Text(
              name.isNotEmpty ? name[0] : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}

// プリセットアイコンの選択UI。選択中のアイコンに枠とチェックを付ける。
class AvatarPresetPicker extends StatelessWidget {
  const AvatarPresetPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final String? selected;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final preset in avatarPresets)
          GestureDetector(
            onTap: enabled ? () => onSelected(preset.assetPath) : null,
            child: SizedBox(
              width: 84,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected == preset.assetPath
                            ? accent
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundImage: AssetImage(preset.assetPath),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preset.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected == preset.assetPath
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
