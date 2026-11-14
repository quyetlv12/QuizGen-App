import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

final _activeToasts = Expando<VoidCallback>();

void showAppToast(
  BuildContext context,
  String message, {
  bool success = false,
  Duration duration = const Duration(seconds: 6),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _activeToasts[overlay]?.call();
  late final OverlayEntry entry;
  Timer? timer;
  var dismissed = false;
  void dismiss() {
    if (dismissed) return;
    dismissed = true;
    timer?.cancel();
    entry.remove();
    entry.dispose();
    _activeToasts[overlay] = null;
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 608,
                maxHeight: MediaQuery.sizeOf(context).height * .35,
              ),
              child: Semantics(
                liveRegion: true,
                child: Material(
                  key: const ValueKey('app-toast'),
                  color: success ? forest : Colors.deepOrange.shade800,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                      child: Row(
                        children: [
                          Icon(
                            success
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Đóng thông báo',
                            onPressed: dismiss,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _activeToasts[overlay] = dismiss;
  overlay.insert(entry);
  timer = Timer(duration, dismiss);
}

class AiThinkingIndicator extends StatefulWidget {
  const AiThinkingIndicator({super.key});

  @override
  State<AiThinkingIndicator> createState() => _AiThinkingIndicatorState();
}

class _AiThinkingIndicatorState extends State<AiThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'AI đang xử lý',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RobotArt(size: 40),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(4, (index) {
                    final pulse = reducedMotion
                        ? 0.0
                        : max(0.0, sin((_motion.value - index * .15) * 2 * pi));
                    return Transform.translate(
                      offset: Offset(0, -4 * pulse),
                      child: Opacity(
                        opacity: reducedMotion ? 1 : .4 + .6 * pulse,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: forest,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onNotifications;
  const BrandBar({super.key, required this.onNotifications});
  @override
  Size get preferredSize => const Size.fromHeight(66);
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    titleSpacing: 18,
    toolbarHeight: 66,
    title: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: greenGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.menu_book_rounded, color: Colors.white, size: 25),
              Positioned(
                top: 3,
                right: 4,
                child: Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFFFE330),
                  size: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'QuizGen ',
                    style: TextStyle(color: ink),
                  ),
                  TextSpan(
                    text: 'AI',
                    style: TextStyle(color: green),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -.7,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Container(
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(13),
          ),
          child: IconButton(
            tooltip: 'Thông báo hệ thống',
            onPressed: onNotifications,
            icon: const Icon(
              Icons.notifications_none_rounded,
              size: 27,
              color: ink,
            ),
          ),
        ),
      ),
    ],
  );
}

class RobotArt extends StatelessWidget {
  final double size;
  const RobotArt({super.key, this.size = 112});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/robot.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  );
}

class AiChatLauncher extends StatefulWidget {
  const AiChatLauncher({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<AiChatLauncher> createState() => _AiChatLauncherState();
}

class _AiChatLauncherState extends State<AiChatLauncher>
    with WidgetsBindingObserver {
  static const messages = [
    'Hỏi AI nhé!',
    'Mình giúp bạn\ntạo bộ đề nhé?',
    'Bạn muốn ôn\nchủ đề nào?',
    'Cùng ôn tập\nmột chút nhé!',
  ];
  final random = Random();
  Timer? timer;
  bool visible = false;
  int message = 0;
  bool greeted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer(const Duration(milliseconds: 800), showMessage);
  }

  void scheduleNext() {
    timer?.cancel();
    timer = Timer(Duration(seconds: 25 + random.nextInt(21)), showMessage);
  }

  void showMessage() {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) {
      scheduleNext();
      return;
    }
    setState(() {
      if (greeted) {
        message =
            (message + 1 + random.nextInt(messages.length - 1)) %
            messages.length;
      }
      greeted = true;
      visible = true;
    });
    timer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => visible = false);
      scheduleNext();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    timer?.cancel();
    if (mounted) setState(() => visible = false);
    if (state == AppLifecycleState.resumed) scheduleNext();
  }

  void openChat() {
    setState(() => visible = false);
    timer?.cancel();
    scheduleNext();
    widget.onPressed();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320);
    return SizedBox(
      width: 206,
      height: 78,
      child: Stack(
        children: [
          Positioned(
            right: 75,
            top: 10,
            width: 129,
            height: 55,
            child: IgnorePointer(
              ignoring: !visible,
              child: ExcludeSemantics(
                excluding: !visible,
                child: AnimatedSlide(
                  offset: visible ? Offset.zero : const Offset(.08, .08),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    key: const ValueKey('ai-hint'),
                    opacity: visible ? 1 : 0,
                    duration: duration,
                    curve: Curves.easeInOut,
                    child: CustomPaint(
                      painter: const _ChatBubblePainter(),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: openChat,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 15),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                messages[message],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            width: 68,
            height: 78,
            child: FloatingActionButton(
              tooltip: 'Chat với AI',
              onPressed: openChat,
              backgroundColor: Colors.transparent,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              shape: const CircleBorder(),
              child: const FittedBox(child: _AiRobotBadge()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiRobotBadge extends StatelessWidget {
  const _AiRobotBadge();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 94,
    height: 106,
    child: Stack(
      children: [
        Positioned(
          right: 4,
          bottom: 5,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB7FF85), Colors.white, Color(0xFF73EB43)],
              ),
              border: Border.all(color: const Color(0xFF0AC525), width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26006C39),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxWidth: 105,
                maxHeight: 105,
                child: const RobotArt(size: 105),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 19,
          child: Transform.rotate(
            angle: .3,
            child: Container(width: 3, height: 19, color: forest),
          ),
        ),
        Positioned(
          top: 0,
          right: 13,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFF44F), Color(0xFFFFBD00)],
              ),
            ),
          ),
        ),
        const Positioned(
          top: 12,
          right: 80,
          child: Icon(Icons.auto_awesome, size: 17, color: Color(0xFFFFD42A)),
        ),
      ],
    ),
  );
}

class _ChatBubblePainter extends CustomPainter {
  const _ChatBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - 12;
    final path = Path()
      ..moveTo(20, 1)
      ..lineTo(size.width - 20, 1)
      ..quadraticBezierTo(size.width - 1, 1, size.width - 1, 20)
      ..quadraticBezierTo(
        size.width - 1,
        bottom - 6,
        size.width - 14,
        bottom - 2,
      )
      ..lineTo(size.width - 12, size.height - 2)
      ..lineTo(size.width - 29, bottom)
      ..lineTo(20, bottom)
      ..quadraticBezierTo(1, bottom, 1, 20)
      ..quadraticBezierTo(1, 1, 20, 1)
      ..close();
    canvas.drawShadow(path, const Color(0x55071C14), 5, false);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFEF3));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF88E83F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_ChatBubblePainter oldDelegate) => false;
}

class PageTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const PageTitle(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: forest),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      ?trailing,
    ],
  );
}

class GradientAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon, trailing;
  const GradientAction(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: onPressed == null ? null : greenGradient,
      color: onPressed == null ? line : null,
      borderRadius: BorderRadius.circular(16),
    ),
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24),
            const SizedBox(width: 10),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Icon(trailing, size: 24),
          ],
        ],
      ),
    ),
  );
}

/// Shared sheet surface keeps every modal aligned with the selection design.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  barrierColor: Colors.black54,
  constraints: const BoxConstraints(maxWidth: 640),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: builder,
);

class AppSheetBody extends StatelessWidget {
  const AppSheetBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: 20,
        right: 0,
        child: ExcludeSemantics(
          child: CustomPaint(size: const Size(300, 100), painter: _SheetWave()),
        ),
      ),
      SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CA6A1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _SheetWave extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = green.withValues(alpha: .035);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..cubicTo(100, 90, 140, 5, 300, 28)
        ..lineTo(300, 100)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(75, size.height)
        ..cubicTo(170, 75, 220, 0, 300, 5)
        ..lineTo(300, 100)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SheetWave oldDelegate) => false;
}

class SheetOptionCard extends StatelessWidget {
  const SheetOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.isChoice = false,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected, isChoice;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: selected
          ? const Color(0xFFE7FAED)
          : Colors.white.withValues(alpha: .85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? const Color(0xFFA5DDB5) : line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        selected: selected,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minLeadingWidth: 38,
        horizontalTitleGap: 14,
        leading: Container(
          width: 38,
          height: 40,
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: green, size: 25),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? green : ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(color: muted, fontSize: 13, height: 1.4),
          ),
        ),
        trailing: Icon(
          isChoice
              ? (selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked)
              : Icons.chevron_right_rounded,
          color: selected ? green : const Color(0xFF99AAA3),
          size: 24,
        ),
        onTap: onTap,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onAll;
  const SectionTitle(this.title, {super.key, required this.icon, this.onAll});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: green, size: 23),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (onAll != null)
        TextButton(
          onPressed: onAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 8),
            minimumSize: const Size(48, 44),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Xem tất cả', style: TextStyle(fontSize: 12)),
              Icon(Icons.chevron_right, size: 19),
            ],
          ),
        ),
    ],
  );
}

class MintIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const MintIcon(this.icon, {super.key, this.size = 42});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: mint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: green, size: size * .58),
  );
}

class FileBadge extends StatelessWidget {
  final String name;
  const FileBadge(this.name, {super.key});
  @override
  Widget build(BuildContext context) {
    final ext = name.split('.').last.toUpperCase();
    final isPdf = ext == 'PDF', isImage = ['JPG', 'JPEG', 'PNG'].contains(ext);
    final label = ['PDF', 'TXT', 'MD', 'DOCX', 'PPTX'].contains(ext)
        ? ext
        : null;
    final color = isPdf
        ? const Color(0xFFED493F)
        : isImage
        ? green
        : const Color(0xFF1681EB);
    return Container(
      width: 40,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
            size: 36,
            color: color,
          ),
          if (label != null)
            Positioned(
              bottom: 8,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StudyRow extends StatelessWidget {
  final Widget leading;
  final String title, subtitle;
  final Widget? badge;
  final Widget? footer;
  final VoidCallback onTap;
  const StudyRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.footer,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line.withValues(alpha: .8)),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: forest.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 8),
                        footer!,
                      ],
                    ],
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 6), badge!],
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right, size: 21, color: muted),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color backgroundColor, textColor;
  const StatusPill(
    this.text, {
    super.key,
    this.backgroundColor = const Color(0xFFDDFDE3),
    this.textColor = const Color(0xFF006B16),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class StudyNavigation extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final VoidCallback onScan;
  const StudyNavigation({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onScan,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: CustomPaint(
              painter: const _NavigationBarPainter(),
              child: ClipPath(
                clipper: const _NavigationBarClipper(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      for (int i = 0; i < 4; i++) ...[
                        if (i == 2) const SizedBox(width: 72),
                        Expanded(
                          child: Semantics(
                            selected: selected == i,
                            button: true,
                            child: Material(
                              color: selected == i ? mint : Colors.transparent,
                              animationDuration:
                                  MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              borderRadius: BorderRadius.circular(22),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () => onChanged(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        [
                                          Icons.home_outlined,
                                          Icons.description_outlined,
                                          Icons.assignment_outlined,
                                          Icons.person_outline_rounded,
                                        ][i],
                                        size: 24,
                                        color: selected == i ? green : muted,
                                      ),
                                      const SizedBox(height: 3),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          [
                                            'Trang chủ',
                                            'Tài liệu',
                                            'Bộ đề',
                                            'Cá nhân',
                                          ][i],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: selected == i
                                                ? green
                                                : muted,
                                            fontWeight: selected == i
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: line),
                  boxShadow: [
                    BoxShadow(
                      color: forest.withValues(alpha: .16),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF05B600), green],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      key: const ValueKey('navigation-scan'),
                      tooltip: 'Quét tài liệu',
                      onPressed: onScan,
                      icon: const _NavigationScanIcon(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NavigationBarPainter extends CustomPainter {
  const _NavigationBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = const _NavigationBarClipper().getClip(size);
    // Paint the same silhouette for the shadow and border, including the recess.
    canvas.drawPath(
      path.shift(const Offset(0, 12)),
      Paint()
        ..color = green.withValues(alpha: .15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = forest.withValues(alpha: .07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_NavigationBarPainter oldDelegate) => false;
}

class _NavigationBarClipper extends CustomClipper<Path> {
  const _NavigationBarClipper();

  @override
  Path getClip(Size size) {
    const radius = 28.0;
    final center = size.width / 2;
    return Path()
      ..moveTo(radius, 0)
      ..lineTo(center - 48, 0)
      ..cubicTo(center - 36, 0, center - 44, 51, center, 51)
      ..cubicTo(center + 44, 51, center + 36, 0, center + 48, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
  }

  @override
  bool shouldReclip(_NavigationBarClipper oldClipper) => false;
}

class _NavigationScanIcon extends StatelessWidget {
  const _NavigationScanIcon();

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(reducedMotion),
        tween: Tween(begin: 0, end: 1),
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 2200),
        builder: (context, progress, child) => SizedBox.square(
          dimension: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              child!,
              Transform.translate(
                key: const ValueKey('navigation-scan-line'),
                offset: Offset(0, sin(progress * 2 * pi) * 10),
                child: Container(
                  width: 23,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: .45),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        child: const Icon(
          Icons.crop_free_rounded,
          size: 34,
          color: Colors.white,
        ),
      ),
    );
  }
}

class UploadZone extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final bool showFileHints;
  const UploadZone({
    super.key,
    required this.onTap,
    this.label = 'Tải tài liệu lên',
    this.showFileHints = false,
  });
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _UploadBorder(),
    child: Material(
      color: mint.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Icon(Icons.cloud_upload_rounded, color: green, size: 48),
                const SizedBox(height: 7),
                Text(label, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                const Text(
                  'Chọn tệp từ thiết bị hoặc kéo thả vào đây',
                  style: TextStyle(fontSize: 14, color: muted),
                ),
                if (showFileHints) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _FormatPreview(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDF',
                        color: Color(0xFFE9443A),
                        angle: -.08,
                      ),
                      SizedBox(width: 10),
                      _FormatPreview(
                        icon: Icons.description_rounded,
                        label: 'DOC',
                        color: Color(0xFF1677E8),
                        angle: .02,
                      ),
                      SizedBox(width: 10),
                      _FormatPreview(
                        icon: Icons.image_rounded,
                        label: 'IMG',
                        color: green,
                        angle: .08,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FormatPreview extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double angle;
  const _FormatPreview({
    required this.icon,
    required this.label,
    required this.color,
    required this.angle,
  });
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 62,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: forest.withValues(alpha: .06),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 25),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _UploadBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      );
    final paint = Paint()
      ..color = green
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 10) {
        canvas.drawPath(metric.extractPath(start, start + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FileTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const FileTypeChip(this.label, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: mint,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: label == 'PDF' ? const Color(0xFFE9443A) : green,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: ink, fontSize: 12)),
      ],
    ),
  );
}

class ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;
  const ChoicePill(
    this.label, {
    super.key,
    this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: onTap != null,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: selected ? greenGradient : null,
        color: selected ? null : mint,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          foregroundColor: selected ? Colors.white : ink,
          disabledForegroundColor: selected ? Colors.white : ink,
        ),
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ConfigCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget child;
  const ConfigCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(17),
      boxShadow: [
        BoxShadow(
          color: forest.withValues(alpha: .06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MintIcon(icon, size: 35),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        child,
      ],
    ),
  );
}

class BottomActions extends StatelessWidget {
  final Widget child;
  const BottomActions({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 684),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Sequential fade-through with a small vertical offset. The IndexedStack keeps
/// each tab alive; a new selection always retargets the current transition.
class SmoothTabBody extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const SmoothTabBody({super.key, required this.index, required this.children});

  @override
  State<SmoothTabBody> createState() => _SmoothTabBodyState();
}

class _SmoothTabBodyState extends State<SmoothTabBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 60),
  )..addStatusListener(onMotionStatus);
  late final CurvedAnimation opacity = CurvedAnimation(
    parent: motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInQuad,
  );
  late int visibleIndex = widget.index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) revealLatestTab();
  }

  @override
  void didUpdateWidget(covariant SmoothTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) changeTab();
  }

  void changeTab() {
    if (MediaQuery.disableAnimationsOf(context)) {
      revealLatestTab();
      return;
    }
    if (visibleIndex == widget.index) {
      motion.forward();
    } else if (motion.isDismissed) {
      revealLatestTab(animate: true);
    } else {
      motion.reverse();
    }
  }

  void revealLatestTab({bool animate = false}) {
    visibleIndex = widget.index;
    if (animate) {
      motion.forward();
    } else {
      motion.value = 1;
    }
  }

  void onMotionStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      setState(() => revealLatestTab(animate: true));
    }
  }

  @override
  void dispose() {
    opacity.dispose();
    motion.removeStatusListener(onMotionStatus);
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: motion,
    builder: (context, child) {
      final blocked = motion.status != AnimationStatus.completed;
      return IgnorePointer(
        ignoring: blocked,
        child: ExcludeFocus(
          excluding: blocked,
          child: ExcludeSemantics(
            excluding: blocked,
            child: Opacity(
              opacity: opacity.value,
              child: Transform.translate(
                offset: Offset(0, 6 * (1 - opacity.value)),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
    child: IndexedStack(
      index: visibleIndex,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          ExcludeFocus(
            excluding: i != visibleIndex,
            child: RepaintBoundary(child: widget.children[i]),
          ),
      ],
    ),
  );
}
