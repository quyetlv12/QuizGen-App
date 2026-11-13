import 'package:flutter/material.dart';

import 'theme.dart';

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
  final VoidCallback onTap;
  const StudyRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
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
  const StatusPill(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFDDFDE3),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF006B16),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class StudyNavigation extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const StudyNavigation({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: line)),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        child: Row(
          children: [
            for (int i = 0; i < 4; i++)
              Expanded(
                child: Semantics(
                  selected: selected == i,
                  button: true,
                  child: Material(
                    color: selected == i ? mint : Colors.white,
                    animationDuration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onChanged(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
                              size: 25,
                              color: selected == i ? green : muted,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ['Trang chủ', 'Tài liệu', 'Bộ đề', 'Cá nhân'][i],
                              style: TextStyle(
                                fontSize: 11,
                                color: selected == i ? green : muted,
                                fontWeight: selected == i
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
        ),
      ),
    ),
  );
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
  final VoidCallback? onTap;
  const ChoicePill(
    this.label, {
    super.key,
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
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
