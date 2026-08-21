// グループ脱退の引き止めダイアログ。10段階の確認をすべて突破したときだけ脱退を許可する。
// すべて「はい」で true、途中で「いいえ」を選ぶと false を返す。

import 'package:flutter/material.dart';

import '../../core/analytics.dart';

// 引き止め1段階ぶんの文言。
class _LeaveStep {
  const _LeaveStep({
    required this.emoji,
    required this.title,
    required this.message,
    required this.yesLabel,
    required this.noLabel,
  });

  final String emoji;
  final String title;
  final String message;
  final String yesLabel;
  final String noLabel;
}

const _steps = [
  _LeaveStep(
    emoji: '😢',
    title: '本当に脱退するの？',
    message: '脱退すると、このグループの投稿はもう見られなくなります。',
    yesLabel: '脱退する',
    noLabel: 'やめておく',
  ),
  _LeaveStep(
    emoji: '🥺',
    title: 'え、まって？',
    message: 'ほんとに？ ほんとにほんとに？',
    yesLabel: 'ほんとに',
    noLabel: 'やっぱやめる',
  ),
  _LeaveStep(
    emoji: '🥺🥺',
    title: '寂しくない？',
    message: 'みんな、あなたのVlogが上がるのを待ってるよ。',
    yesLabel: '寂しくない',
    noLabel: 'ちょっと寂しいかも',
  ),
  _LeaveStep(
    emoji: '😭',
    title: '後悔しない？',
    message: '撮ってきた思い出、ぜんぶ置いていくことになるよ。',
    yesLabel: '後悔しない',
    noLabel: '後悔するかも',
  ),
  _LeaveStep(
    emoji: '😮‍💨',
    title: 'ひとまず深呼吸しよ？',
    message: 'すぅ……はぁ……。どう、落ち着いた？',
    yesLabel: '落ち着いてる',
    noLabel: 'たしかに落ち着いた',
  ),
  _LeaveStep(
    emoji: '🥺🥺🥺',
    title: 'みんなに聞いてみた',
    message: '「行かないで」だってさ。',
    yesLabel: 'それでも抜ける',
    noLabel: '残ってあげる',
  ),
  _LeaveStep(
    emoji: '🐘',
    title: 'ぴえん🥺',
    message: 'ぴえんをこえてぱおん。もう言葉が出ない。',
    yesLabel: 'ぱおん（脱退）',
    noLabel: 'ぱおん（残る）',
  ),
  _LeaveStep(
    emoji: '😇',
    title: 'これで最後のチャンス……',
    message: 'ではありません。まだ聞きます。',
    yesLabel: 'しつこい',
    noLabel: 'もういいや、残る',
  ),
  _LeaveStep(
    emoji: '😳',
    title: 'ここまで来たら本気だね',
    message: 'その意志の強さ、ちょっと尊敬した。',
    yesLabel: '本気です',
    noLabel: '照れるから残る',
  ),
  _LeaveStep(
    emoji: '👋',
    title: '今度こそ本当に最後',
    message: 'このボタンを押したら、さよならです。',
    yesLabel: 'さよなら',
    noLabel: 'やっぱりここにいる',
  ),
];

// 引き止めダイアログを順番に表示する。すべて突破できたら true。
Future<bool> showLeaveGauntlet(BuildContext context) async {
  for (var i = 0; i < _steps.length; i++) {
    if (!context.mounted) return false;
    final answer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LeaveStepDialog(step: _steps[i], index: i),
    );
    if (answer != true) {
      Analytics.log('leave_gauntlet_cancelled', {'step': i + 1});
      return false;
    }
  }
  Analytics.log('leave_gauntlet_cleared', {'steps': _steps.length});
  return true;
}

// 引き止め1段階ぶんのダイアログ。段階が進むほど残るボタンが強調される。
class _LeaveStepDialog extends StatelessWidget {
  const _LeaveStepDialog({required this.step, required this.index});

  final _LeaveStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final progress = (index + 1) / _steps.length;
    final remaining = _steps.length - index - 1;

    final yesButton = TextButton(
      onPressed: () => Navigator.of(context).pop(true),
      child: Opacity(
        opacity: 1.0 - progress * 0.6,
        child: Text(
          step.yesLabel,
          style: TextStyle(color: Colors.red, fontSize: 14 - progress * 2),
        ),
      ),
    );
    final noButton = FilledButton(
      onPressed: () => Navigator.of(context).pop(false),
      child: Text(
        step.noLabel,
        style: TextStyle(fontSize: 14 + progress * 4),
      ),
    );

    return AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WobblingEmoji(emoji: step.emoji, scale: 1.0 + progress * 0.6),
          const SizedBox(height: 12),
          Text(step.title, textAlign: TextAlign.center),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(step.message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              color: Colors.red.shade300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remaining == 0 ? '確認は以上です' : 'あと $remaining 回聞きます',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      // 後半は「残る」を右（押しやすい位置）に置いて、うっかり脱退を防ぐ。
      actions: progress < 0.5 ? [noButton, yesButton] : [yesButton, noButton],
    );
  }
}

// ゆらゆら揺れる絵文字。段階が進むほど大きくなる。
class _WobblingEmoji extends StatefulWidget {
  const _WobblingEmoji({required this.emoji, required this.scale});

  final String emoji;
  final double scale;

  @override
  State<_WobblingEmoji> createState() => _WobblingEmojiState();
}

class _WobblingEmojiState extends State<_WobblingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: (_controller.value - 0.5) * 0.25,
        child: child,
      ),
      child: Text(
        widget.emoji,
        style: TextStyle(fontSize: 40 * widget.scale),
      ),
    );
  }
}
