import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizmind/scan_screen.dart';

class TestCamera extends CameraPlatform {
  bool noCamera = false;
  bool denied = false;
  bool audio = true;
  int captures = 0;
  int creations = 0;
  int disposals = 0;
  Completer<void>? initializeGate;
  final initialized = StreamController<CameraInitializedEvent>.broadcast();
  final errors = StreamController<CameraErrorEvent>.broadcast();
  final orientations =
      StreamController<DeviceOrientationChangedEvent>.broadcast();
  late File photo;

  @override
  Future<List<CameraDescription>> availableCameras() async => noCamera
      ? []
      : const [
          CameraDescription(
            name: 'rear',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 90,
          ),
        ];
  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? preset, {
    bool enableAudio = false,
  }) async {
    creations++;
    if (denied) throw CameraException('CameraAccessDenied', 'Denied');
    audio = enableAudio;
    return 1;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      initialized.stream;
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => errors.stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      orientations.stream;
  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    await initializeGate?.future;
    initialized.add(
      const CameraInitializedEvent(
        1,
        1280,
        720,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
  }

  @override
  Widget buildPreview(int cameraId) =>
      const ColoredBox(key: ValueKey('camera-feed'), color: Colors.blue);
  @override
  Future<XFile> takePicture(int cameraId) async {
    captures++;
    return XFile(photo.path);
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposals++;
  }

  Future<void> close() async {
    await initialized.close();
    errors.add(const CameraErrorEvent(1, 'Test disposed'));
    await errors.close();
    await orientations.close();
  }
}

void main() {
  late TestCamera platform;
  late CameraPlatform original;
  setUp(() {
    original = CameraPlatform.instance;
    platform = TestCamera();
    CameraPlatform.instance = platform;
  });
  tearDown(() async {
    CameraPlatform.instance = original;
    await platform.close();
  });

  Future<void> showScanner(
    WidgetTester tester, {
    Future<bool> Function(XFile)? onCapture,
    VoidCallback? onGallery,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          onPhoto: (_) async {
            onGallery?.call();
            return false;
          },
          onCapture: onCapture ?? (_) async => false,
        ),
      ),
    );
  }

  testWidgets(
    'camera opens automatically and covers frame; shutter imports and cleans up',
    (tester) async {
      final folder = Directory.systemTemp.createTempSync(
        'quizmind-camera-test',
      );
      addTearDown(() => folder.deleteSync(recursive: true));
      platform.photo = File('${folder.path}/page.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      List<int>? imported;
      await showScanner(
        tester,
        onCapture: (image) async {
          imported = await image.readAsBytes();
          return false;
        },
      );
      await tester.pumpAndSettle();
      expect(platform.creations, 1);
      expect(platform.audio, isFalse);
      expect(platform.captures, 0);
      final frame = tester.getRect(find.byKey(const ValueKey('scan-frame')));
      final feed = tester.getRect(find.byKey(const ValueKey('camera-feed')));
      final inside = frame.deflate(3);
      expect(feed.left, lessThanOrEqualTo(inside.left + .001));
      expect(feed.right, greaterThanOrEqualTo(inside.right - .001));
      expect(feed.top, lessThanOrEqualTo(inside.top + .001));
      expect(feed.bottom, greaterThanOrEqualTo(inside.bottom - .001));
      expect(feed.center, inside.center);
      expect(feed.width / feed.height, closeTo(720 / 1280, .001));
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Chụp tài liệu'));
        for (int i = 0; i < 100 && platform.photo.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(imported, [1, 2, 3]);
      expect(platform.captures, 1);
      expect(platform.photo.existsSync(), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(platform.disposals, 1);
    },
  );

  testWidgets('no camera and permission denial keep gallery available', (
    tester,
  ) async {
    platform.noCamera = true;
    int galleries = 0;
    await showScanner(tester, onGallery: () => galleries++);
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera chưa khả dụng'), findsOneWidget);
    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();
    expect(galleries, 1);
    platform.noCamera = false;
    platform.denied = true;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có quyền camera'), findsOneWidget);
    expect(find.byType(CameraPreview), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background releases camera; resume recreates it', (
    tester,
  ) async {
    await showScanner(tester);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreview), findsNothing);
    expect(platform.disposals, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreview), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'leaving during initialization disposes late camera without UI update',
    (tester) async {
      platform.initializeGate = Completer<void>();
      await showScanner(tester);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      platform.initializeGate!.complete();
      await tester.pumpAndSettle();
      expect(platform.disposals, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('permission is requested on entry and denial allows gallery', (
    tester,
  ) async {
    platform.denied = true;
    int galleries = 0;
    await showScanner(tester, onGallery: () => galleries++);
    await tester.pumpAndSettle();
    expect(platform.creations, 1);
    expect(find.textContaining('Chưa có quyền camera'), findsOneWidget);
    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();
    expect(galleries, 1);
    expect(platform.captures, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('permission prompt does not start overlapping camera sessions', (
    tester,
  ) async {
    platform.initializeGate = Completer<void>();
    await showScanner(tester);
    await tester.pump();
    expect(platform.creations, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.creations, 1);
    platform.initializeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreview), findsOneWidget);
    expect(platform.captures, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(platform.disposals, 1);
  });

  testWidgets('preview covers landscape frame without stretching', (
    tester,
  ) async {
    await showScanner(tester);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(874, 402);
    platform.orientations.add(
      const DeviceOrientationChangedEvent(DeviceOrientation.landscapeLeft),
    );
    await tester.pumpAndSettle();
    final inside = tester
        .getRect(find.byKey(const ValueKey('scan-frame')))
        .deflate(3);
    final feed = tester.getRect(find.byKey(const ValueKey('camera-feed')));
    expect(feed.left, lessThanOrEqualTo(inside.left + .001));
    expect(feed.right, greaterThanOrEqualTo(inside.right - .001));
    expect(feed.top, lessThanOrEqualTo(inside.top + .001));
    expect(feed.bottom, greaterThanOrEqualTo(inside.bottom - .001));
    expect(feed.width / feed.height, closeTo(1280 / 720, .001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
