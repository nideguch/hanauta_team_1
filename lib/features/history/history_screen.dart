// アプリの（架空の）歴史を見せるオープニング画面。ログイン直後に一度だけ流れる。
// 章を自動送りし、タップで次へ、スキップで終了する。

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 明朝系を優先して渋く見せる。端末に無ければsans-serifへ落ちる。
const _serif = [
  'Hiragino Mincho ProN',
  'YuMincho',
  'Noto Serif JP',
  'Georgia',
  'serif',
];

const _gold = Color(0xFFC9A227);
const _paleGold = Color(0xFFF3E3C3);

// 歴史の1章ぶん。year は大きく表示する年号（最初の章だけ空）。
class _Chapter {
  const _Chapter({this.year, required this.lines, this.isFinale = false});

  final String? year;
  final List<String> lines;
  final bool isFinale;
}

const _chapters = [
  _Chapter(
    lines: [
      'このアプリの歴史は、',
      '130年前に遡る。',
    ],
  ),
  _Chapter(
    year: '1896',
    lines: [
      '明治二十九年、京都・鴨川のほとり。',
      '一台の活動写真機が、川べりに据えられた。',
    ],
  ),
  _Chapter(
    year: '1901',
    lines: [
      '人々が撮ったのは、名場面ではなかった。',
      '朝の支度。昼の弁当。夕暮れの帰り道。',
      'ただの一日を、誰かに手渡すために。',
    ],
  ),
  _Chapter(
    year: '1923',
    lines: [
      '震災。フィルムは灰になった。',
      'それでも、人々は翌朝また回した。',
    ],
  ),
  _Chapter(
    year: '1945',
    lines: [
      '焼け跡から、一本だけ見つかった。',
      '写っていたのは、笑っている家族の一分間。',
    ],
  ),
  _Chapter(
    year: '1968',
    lines: [
      '誰かがそれに名前をつけた。',
      '——「花唄」。',
      '日々に口ずさむ、名もない歌のこと。',
    ],
  ),
  _Chapter(
    year: '2026',
    lines: [
      'フィルムはガラスの板に変わった。',
      'けれど、やっていることは何も変わらない。',
    ],
  ),
  _Chapter(
    isFinale: true,
    lines: [
      'その一分は、まだ終わっていない。',
    ],
  ),
];

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  static const _chapterDuration = Duration(milliseconds: 5200);

  late final AnimationController _chapter = AnimationController(
    vsync: this,
    duration: _chapterDuration,
  )..addStatusListener(_onChapterEnd);

  // フィルムのざらつき用。章の進行とは別に回し続ける。
  late final AnimationController _grain = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  )..repeat();

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _chapter.forward();
  }

  @override
  void dispose() {
    _chapter.dispose();
    _grain.dispose();
    super.dispose();
  }

  void _onChapterEnd(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_chapters[_index].isFinale) return;
    _next();
  }

  void _next() {
    if (_index >= _chapters.length - 1) return;
    setState(() => _index++);
    _chapter.forward(from: 0);
  }

  void _finish() {
    // ログイン直後は履歴が無いので、その場合だけ振り分け画面へ送る。
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/splash');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapters[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: chapter.isFinale ? _finish : _next,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _Spotlight(),
            AnimatedBuilder(
              animation: _grain,
              builder: (context, _) => CustomPaint(painter: _FilmGrainPainter()),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: AnimatedBuilder(
                  animation: _chapter,
                  builder: (context, _) => _ChapterView(
                    chapter: chapter,
                    progress: _chapter.value,
                    onStart: _finish,
                  ),
                ),
              ),
            ),
            const _Vignette(),
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: Row(
                children: [
                  _ProgressBar(index: _index, total: _chapters.length),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'スキップ',
                      style: TextStyle(
                        color: Color(0x99F3E3C3),
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
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

// 1章ぶんの本文。フェードイン→保持→フェードアウトしながら、ゆっくり浮き上がる。
class _ChapterView extends StatelessWidget {
  const _ChapterView({
    required this.chapter,
    required this.progress,
    required this.onStart,
  });

  final _Chapter chapter;
  final double progress;
  final VoidCallback onStart;

  double get _opacity {
    if (progress < 0.18) return Curves.easeOut.transform(progress / 0.18);
    if (chapter.isFinale || progress < 0.86) return 1;
    return 1 - Curves.easeIn.transform((progress - 0.86) / 0.14);
  }

  @override
  Widget build(BuildContext context) {
    final rise = (1 - Curves.easeOut.transform(min(progress / 0.5, 1))) * 16;

    return Opacity(
      opacity: _opacity,
      child: Transform.translate(
        offset: Offset(0, rise),
        child: Center(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_paleGold, _gold],
            ).createShader(rect),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chapter.year != null) ...[
                  const _HairLine(),
                  const SizedBox(height: 20),
                  Text(
                    chapter.year!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 68,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 14 - progress * 4,
                      height: 1,
                      fontFamilyFallback: _serif,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _HairLine(),
                  const SizedBox(height: 36),
                ],
                if (chapter.isFinale) ...[
                  const Text(
                    'HANALOG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 16,
                      fontFamilyFallback: _serif,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'EST. 1896  ·  KYOTO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 6,
                      fontFamilyFallback: _serif,
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
                for (final line in chapter.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      line,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.9,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w300,
                        fontFamilyFallback: _serif,
                      ),
                    ),
                  ),
                if (chapter.isFinale) ...[
                  const SizedBox(height: 48),
                  OutlinedButton(
                    onPressed: onStart,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: _gold),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 18,
                      ),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: const Text(
                      '一 分 を は じ め る',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 4,
                        fontFamilyFallback: _serif,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 年号を挟む細い金の罫線。
class _HairLine extends StatelessWidget {
  const _HairLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, _gold, Colors.transparent],
        ),
      ),
    );
  }
}

// 画面中央のほのかな照明。映写機の光のつもり。
class _Spotlight extends StatelessWidget {
  const _Spotlight();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.15),
          radius: 0.9,
          colors: [Color(0xFF241D12), Colors.black],
        ),
      ),
    );
  }
}

// 四隅を落とすビネット。
class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.95,
            colors: [Colors.transparent, Color(0xCC000000)],
            stops: [0.55, 1],
          ),
        ),
      ),
    );
  }
}

// フィルムのざらつきと縦キズ。毎フレーム描き直して古い映写機っぽく見せる。
class _FilmGrainPainter extends CustomPainter {
  final Random _random = Random();

  @override
  void paint(Canvas canvas, Size size) {
    final speck = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0; i < 240; i++) {
      canvas.drawCircle(
        Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        ),
        _random.nextDouble() * 0.9,
        speck,
      );
    }

    if (_random.nextDouble() < 0.35) {
      final scratch = Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = _random.nextDouble() * 1.2;
      final x = _random.nextDouble() * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x + 6, size.height), scratch);
    }
  }

  @override
  bool shouldRepaint(covariant _FilmGrainPainter oldDelegate) => true;
}

// 何章目かを示す細いバー。
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                color: i <= index ? _gold : const Color(0x33F3E3C3),
              ),
            ),
        ],
      ),
    );
  }
}
