import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'theme.dart';
import 'ui.dart';

class ScanScreen extends StatefulWidget {
  final Future<bool> Function(ImageSource) onPhoto;
  final Future<bool> Function(XFile) onCapture;
  const ScanScreen({super.key, required this.onPhoto, required this.onCapture});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? camera;
  bool busy = false;
  bool opening = false;
  bool requested = false;
  bool foreground = true;
  int session = 0;
  String? cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(openCamera());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session++;
    unawaited(camera?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      // The system permission prompt makes iOS inactive during initialization.
      if (opening && state == AppLifecycleState.inactive) return;
      session++;
      final previous = camera;
      setState(() {
        camera = null;
        opening = false;
      });
      unawaited(previous?.dispose());
    } else if (requested && !busy) {
      unawaited(openCamera());
    }
  }

  Future<void> openCamera() async {
    if (opening || camera != null || !foreground) return;
    final current = ++session;
    setState(() {
      requested = true;
      opening = true;
      cameraError = null;
    });
    CameraController? candidate;
    try {
      final cameras = await availableCameras();
      if (!mounted || current != session) return;
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'Không tìm thấy camera.');
      }
      candidate = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.high,
        enableAudio: false,
      );
      await candidate.initialize();
      if (!mounted || current != session) return;
      if (!foreground) {
        setState(() => opening = false);
        return;
      }
      setState(() {
        camera = candidate;
        opening = false;
      });
      candidate = null;
    } catch (e) {
      if (!mounted || current != session) return;
      final denied =
          e is CameraException &&
          const [
            'CameraAccessDenied',
            'CameraAccessDeniedWithoutPrompt',
            'CameraAccessRestricted',
          ].contains(e.code);
      setState(() {
        opening = false;
        cameraError = denied
            ? 'Chưa có quyền camera. Hãy bật quyền trong Cài đặt hoặc chọn ảnh từ thư viện.'
            : 'Camera chưa khả dụng trên thiết bị này. Hãy chọn ảnh từ thư viện hoặc thử lại.';
      });
    } finally {
      await candidate?.dispose();
    }
  }

  Future<void> capture({bool gallery = false}) async {
    if (busy || opening) return;
    final activeCamera = camera;
    if (!gallery && activeCamera == null) {
      await openCamera();
      return;
    }
    setState(() => busy = true);
    bool added = false;
    try {
      if (gallery) {
        added = await widget.onPhoto(ImageSource.gallery);
      } else {
        final image = await activeCamera!.takePicture();
        try {
          if (mounted) added = await widget.onCapture(image);
        } finally {
          // The importer owns the bytes; discard the temporary camera file.
          try {
            final temporary = File(image.path);
            if (await temporary.exists()) await temporary.delete();
          } on FileSystemException {
            // A cache cleanup failure must not discard an imported image.
          }
        }
      }
      if (mounted && added) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thêm được ảnh. Hãy thử lại hoặc chọn ảnh từ thư viện.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (!added && requested && foreground && camera == null) {
          unawaited(openCamera());
        }
      }
    }
  }

  void help() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chụp tài liệu rõ chữ'),
      content: const Text(
        'Camera tự bật khi mở màn hình này. Hãy cho phép truy cập camera nếu được hỏi. Đặt trang giấy trên nền phẳng, đủ sáng, giữ toàn bộ trang trong khung rồi nhấn nút chụp. Bạn có thể thêm tối đa 10 ảnh và đổi thứ tự trước khi đọc. Nếu camera không khả dụng, hãy chọn Thư viện.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF29CB50), Color(0xFF008359), mint, Colors.white],
            stops: [0, .29, .72, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final frameHeight = (viewport.maxHeight - 312).clamp(
                260.0,
                650.0,
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _headerButton(
                              Icons.arrow_back_rounded,
                              'Quay lại',
                              () => Navigator.pop(context),
                            ),
                            const Expanded(
                              child: Text(
                                'Quét tài liệu',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _headerButton(
                              Icons.help_outline_rounded,
                              'Hướng dẫn chụp',
                              help,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Chụp hoặc quét tài liệu để tạo câu hỏi với AI',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        _frame(frameHeight),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .96),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x150B6945),
                                blurRadius: 24,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _action(
                                  Icons.photo_library_outlined,
                                  'Thư viện',
                                  busy || opening
                                      ? null
                                      : () => capture(gallery: true),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFBEF7CE),
                                    width: 4,
                                  ),
                                ),
                                child: IconButton(
                                  tooltip: camera == null
                                      ? 'Bật camera'
                                      : 'Chụp tài liệu',
                                  onPressed: busy || opening
                                      ? null
                                      : () => capture(),
                                  style: IconButton.styleFrom(
                                    backgroundColor: green,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: green,
                                    fixedSize: const Size(72, 72),
                                  ),
                                  icon: busy || opening
                                      ? const SizedBox(
                                          width: 26,
                                          height: 26,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 34,
                                        ),
                                ),
                              ),
                              Expanded(
                                child: _action(
                                  Icons.lightbulb_outline_rounded,
                                  'Mẹo chụp',
                                  help,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: mint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const MintIcon(
                                Icons.description_outlined,
                                size: 40,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tài liệu hỗ trợ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'PDF, TXT/MD, JPG, PNG',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC8F7D8),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Text(
                                    'Tối đa 10 ảnh',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: green,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _headerButton(IconData icon, String label, VoidCallback onPressed) =>
      IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: .17),
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
        ),
      );

  Widget _action(IconData icon, String label, VoidCallback? onPressed) =>
      TextButton(
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MintIcon(icon, size: 40),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ink, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _frame(double height) {
    final active = camera;
    return Container(
      height: height,
      width: double.infinity,
      key: const ValueKey('scan-frame'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFB4FFB7), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x663AFF6B), blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF087B40),
                    Color(0xFF00563F),
                    Color(0xFF127853),
                  ],
                ),
              ),
            ),
            if (active != null)
              ValueListenableBuilder<CameraValue>(
                valueListenable: active,
                builder: (context, value, _) {
                  final orientation =
                      value.previewPauseOrientation ??
                      value.lockedCaptureOrientation ??
                      value.deviceOrientation;
                  final landscape =
                      orientation == DeviceOrientation.landscapeLeft ||
                      orientation == DeviceOrientation.landscapeRight;
                  final size = value.previewSize!;
                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: landscape ? size.width : size.height,
                      height: landscape ? size.height : size.width,
                      child: CameraPreview(active),
                    ),
                  );
                },
              ),
            IgnorePointer(
              child: CustomPaint(painter: _ScanGuides(grid: active == null)),
            ),
            if (active == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (opening)
                          const CircularProgressIndicator(color: Colors.white)
                        else ...[
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.document_scanner_outlined,
                                size: 92,
                                color: Color(0xFFE4FFEA),
                              ),
                              Container(
                                width: 128,
                                height: 2,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF86FF9E),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF32FF6C),
                                      blurRadius: 15,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 22),
                        Text(
                          opening
                              ? 'Đang mở camera…'
                              : cameraError != null
                              ? 'Chưa mở được camera'
                              : 'Đặt tài liệu trong khung và chụp',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          cameraError ??
                              (opening
                                  ? 'Hình camera sẽ hiển thị ngay trong khung này'
                                  : 'Camera sẽ tự mở khi màn hình sẵn sàng'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFDAF3E2),
                          ),
                        ),
                        if (cameraError != null)
                          TextButton(
                            onPressed: opening ? null : openCamera,
                            child: const Text(
                              'Thử lại',
                              style: TextStyle(
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanGuides extends CustomPainter {
  final bool grid;
  const _ScanGuides({required this.grid});
  @override
  void paint(Canvas canvas, Size size) {
    if (grid) {
      final line = Paint()
        ..color = Colors.white.withValues(alpha: .08)
        ..strokeWidth = 1;
      for (int i = 1; i < 3; i++) {
        canvas.drawLine(
          Offset(size.width * i / 3, 0),
          Offset(size.width * i / 3, size.height),
          line,
        );
        canvas.drawLine(
          Offset(0, size.height * i / 3),
          Offset(size.width, size.height * i / 3),
          line,
        );
      }
    }
    final paint = Paint()
      ..color = const Color(0xFFE9FFF0)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const inset = 16.0;
    const arm = 26.0;
    const radius = 15.0;
    final corner = Path()
      ..moveTo(inset, inset + arm)
      ..lineTo(inset, inset + radius)
      ..quadraticBezierTo(inset, inset, inset + radius, inset)
      ..lineTo(inset + arm, inset);
    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(i.isOdd ? size.width : 0, i >= 2 ? size.height : 0);
      canvas.scale(i.isOdd ? -1 : 1, i >= 2 ? -1 : 1);
      canvas.drawPath(corner, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ScanGuides oldDelegate) => oldDelegate.grid != grid;
}
