// プロフィール画面。ログイン中ユーザーの表示名とアイコンを編集して保存する。
// users テーブルの name / icon_url を更新する（初回登録は profile_setup_screen.dart）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics.dart';
import '../../core/navigation.dart';
import '../../core/supabase_client.dart';
import '../gacha/gacha_provider.dart';
import 'avatar_presets.dart';
import 'profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedIcon;
  bool _isSaving = false;
  // 取得済みの名前をフォームへ流し込むのは最初の1回だけ。
  // 再取得のたびに上書きすると、編集中の入力が消えてしまうため。
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) context.backOrHome();
      return;
    }

    setState(() => _isSaving = true);
    try {
      await updateProfileName(
        userId: user.id,
        name: _nameController.text.trim(),
        iconUrl: _selectedIcon,
      );
      Analytics.log('profile_updated');
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存しました')),
      );
      context.backOrHome();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました。もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ガチャで当てたアイコンも、ここから選べるようにする。
  Widget _buildGachaIcons() {
    final owned = ref.watch(gachaStateProvider).value?.ownedPaths ?? {};
    final presets = [
      for (final icon in gachaIcons)
        if (owned.contains(icon.assetPath))
          AvatarPreset(label: icon.label, assetPath: icon.assetPath),
    ];

    return Column(
      children: [
        const Text('ガチャで当てたアイコン', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        if (presets.isEmpty)
          Text(
            'まだ1つも持っていません',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          AvatarPresetPicker(
            selected: _selectedIcon,
            enabled: !_isSaving,
            presets: presets,
            onSelected: (path) => setState(() => _selectedIcon = path),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isSaving ? null : () => context.push('/gacha'),
          icon: const Icon(Icons.casino_outlined),
          label: const Text('ガチャを引く'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: profileAsync.when(
        data: (user) {
          if (!_prefilled) {
            _prefilled = true;
            _nameController.text = user.name;
            _selectedIcon = user.iconUrl;
          }
          return _buildForm();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('プロフィールの取得に失敗しました: $e'),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: UserAvatar(
                    name: _nameController.text,
                    iconUrl: _selectedIcon,
                    radius: 48,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: '名前',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? '名前を入力してください'
                      : null,
                ),
                const SizedBox(height: 28),
                const Text('アイコン', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                AvatarPresetPicker(
                  selected: _selectedIcon,
                  enabled: !_isSaving,
                  onSelected: (path) => setState(() => _selectedIcon = path),
                ),
                const SizedBox(height: 28),
                _buildGachaIcons(),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
