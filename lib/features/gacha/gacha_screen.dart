// アイコンガチャ画面。チケットを消費して抽選し、当たったアイコンを集めて着せ替える。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../auth/avatar_presets.dart';
import '../auth/profile_provider.dart';
import 'gacha_provider.dart';

class GachaScreen extends ConsumerStatefulWidget {
  const GachaScreen({super.key});

  @override
  ConsumerState<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends ConsumerState<GachaScreen> {
  bool _drawing = false;

  Future<void> _draw(GachaState state) async {
    if (_drawing || !state.canDraw) return;
    setState(() => _drawing = true);

    try {
      final result = await drawGacha(state.ownedPaths);
      ref.invalidate(gachaStateProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _GachaResultDialog(result: result),
      );
      if (!mounted) return;
      await _equip(result.icon.assetPath, silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ガチャに失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  Future<void> _equip(String assetPath, {bool silent = false}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await updateProfileIcon(userId: user.id, iconUrl: assetPath);
      ref.invalidate(myProfileProvider);
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アイコンを変更しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アイコンの変更に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gachaAsync = ref.watch(gachaStateProvider);
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('アイコンガチャ')),
      body: gachaAsync.when(
        data: (state) => _buildBody(state, profileAsync.value?.iconUrl),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('ガチャ情報の取得に失敗しました: $e'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(GachaState state, String? currentIcon) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(gachaStateProvider);
        await ref.read(gachaStateProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _TicketCard(tickets: state.tickets),
          const SizedBox(height: 24),
          Center(
            child: _CapsuleButton(
              enabled: state.canDraw && !_drawing,
              spinning: _drawing,
              onTap: () => _draw(state),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              state.canDraw ? 'カプセルをタップして1回引く' : 'Vlogを投稿するとチケットがたまります',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 32),
          Text('コレクション', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${state.ownedPaths.where((p) => gachaIconOf(p) != null).length} / ${gachaIcons.length} 種類',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final icon in gachaIcons)
            _CollectionTile(
              icon: icon,
              owned: state.owns(icon),
              equipped: currentIcon == icon.assetPath,
              onEquip: () => _equip(icon.assetPath),
            ),
        ],
      ),
    );
  }
}

// 残チケットの表示カード。
class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.tickets});

  final int tickets;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('🎫', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ガチャチケット $tickets 枚',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最初に$gachaBonusTickets枚。Vlogを1本投稿するごとに1枚もらえます。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ガチャのカプセル。引ける間はふわふわ揺れ、抽選中はぐるぐる回る。
class _CapsuleButton extends StatefulWidget {
  const _CapsuleButton({
    required this.enabled,
    required this.spinning,
    required this.onTap,
  });

  final bool enabled;
  final bool spinning;
  final VoidCallback onTap;

  @override
  State<_CapsuleButton> createState() => _CapsuleButtonState();
}

class _CapsuleButtonState extends State<_CapsuleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final wobble = widget.spinning
              ? _controller.value * 6.283
              : (_controller.value - 0.5) * 0.2;
          return Transform.rotate(angle: wobble, child: child);
        },
        child: Opacity(
          opacity: widget.enabled || widget.spinning ? 1 : 0.4,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A9B), Color(0xFFFFD166)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Text('🎁', style: TextStyle(fontSize: 64)),
            ),
          ),
        ),
      ),
    );
  }
}

// 抽選結果ダイアログ。少し溜めてからアイコンを見せる。
class _GachaResultDialog extends StatefulWidget {
  const _GachaResultDialog({required this.result});

  final GachaResult result;

  @override
  State<_GachaResultDialog> createState() => _GachaResultDialogState();
}

class _GachaResultDialogState extends State<_GachaResultDialog> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.result.icon;

    return AlertDialog(
      content: SizedBox(
        height: 260,
        child: Center(
          child: _revealed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.5, end: 1),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: AvatarImageCircle(
                        image: AssetImage(icon.assetPath),
                        radius: 64,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      icon.stars,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFFFFA000),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      icon.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.result.isNew ? 'NEW! アイコンに設定しました' : 'ダブり！ アイコンに設定しました',
                      style: TextStyle(
                        color: widget.result.isNew
                            ? const Color(0xFFE91E63)
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎁', style: TextStyle(fontSize: 96)),
                    SizedBox(height: 16),
                    Text('開封中...'),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _revealed ? () => Navigator.of(context).pop() : null,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// コレクション一覧の1行。未所持はシルエット表示にする。
class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.icon,
    required this.owned,
    required this.equipped,
    required this.onEquip,
  });

  final GachaIcon icon;
  final bool owned;
  final bool equipped;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: owned
          ? AvatarImageCircle(image: AssetImage(icon.assetPath), radius: 24)
          : CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade300,
              child: const Text('？', style: TextStyle(fontSize: 20)),
            ),
      title: Text(owned ? icon.label : '？？？'),
      subtitle: Text('${icon.stars}（${icon.weight}%）'),
      trailing: !owned
          ? null
          : equipped
              ? const Chip(label: Text('使用中'))
              : TextButton(onPressed: onEquip, child: const Text('これにする')),
    );
  }
}
