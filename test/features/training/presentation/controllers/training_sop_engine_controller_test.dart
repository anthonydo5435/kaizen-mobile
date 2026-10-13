import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_sop_editor_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_sop_engine_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_tab_navigation_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_tab_view.dart';
import 'package:webview_flutter/webview_flutter.dart';
// The WebView package's platform test API is already installed transitively.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporaryDirectory;
  late _WebViewPlatform platform;
  late TrainingSopEditorController controller;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('kaizen-sop-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temporaryDirectory.path,
    );
    platform = _WebViewPlatform();
    WebViewPlatform.instance = platform;
    controller = TrainingSopEditorController(
      initialHtml: '<p>Native SOP</p>',
      editor: TrainingSopEngineController(),
      onHtmlChanged: (_) => fail('Initialization must not save the document'),
    );
  });

  tearDown(() async {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'the first native document is initialized by the SOP engine without a bootstrap editor',
    () async {
      await controller.initialize(editable: false);
      expect(controller.isReady, isTrue);
      expect(controller.errorMessage, isNull);
      expect(platform.controller.commands.map((command) => command['name']), ['init']);
      expect(platform.controller.commands.single['payload'], {
        'content': '<p>Native SOP</p>',
        'editable': false,
      });
      expect(controller.editor.document!.content!.single.content!.single.text, 'Native SOP');
    },
  );

  test('a native init failure ends loading even when no document or ready event arrives', () async {
    platform.controller.failInit = true;
    await controller.initialize().timeout(const Duration(seconds: 2));
    expect(controller.isReady, isFalse);
    expect(controller.errorMessage, AppStrings.trainingSopEditorError);
  });

  Future<TrainingTabNavigationController> mountTabs(WidgetTester tester) async {
    await tester.runAsync(() => controller.initialize());
    final navigation = TrainingTabNavigationController()..selectTab(1);
    addTearDown(navigation.dispose);
    final surface = controller.editor as TrainingSopEngineController;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 480,
            child: TrainingTabView(
              navigation: navigation,
              maxTabIndex: 2,
              pageBuilder: (_, index) => index == 1
                  ? surface.buildDocument(width: 344, textScale: 1)
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    return navigation;
  }

  void expectSopPage(WidgetTester tester, TrainingTabNavigationController navigation) {
    expect(navigation.selectedIndex, 1);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'selection handles keep horizontal drags in SOP and deselection restores tab swipes',
    (tester) async {
      final navigation = await mountTabs(tester);
      platform.controller.sendSurfaceMessage({'hasSelection': true});
      for (final direction in [-1.0, 1.0]) {
        platform.controller.pointerTarget.events.clear();
        await tester.drag(find.byType(WebViewWidget), Offset(direction * 240, 0));
        await tester.pumpAndSettle();
        expectSopPage(tester, navigation);
        expect(platform.controller.pointerTarget.events.whereType<PointerMoveEvent>(), isNotEmpty);
      }

      platform.controller.sendSurfaceMessage({'hasSelection': false});
      await tester.drag(find.byType(WebViewWidget), const Offset(-240, 0));
      await tester.pumpAndSettle();
      expect(navigation.selectedIndex, 2);
      navigation.selectTab(1);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(WebViewWidget), const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(navigation.selectedIndex, 0);
    },
  );

  testWidgets(
    'long presses and pinches retain native gestures through selection and zoom updates',
    (tester) async {
      final navigation = await mountTabs(tester);
      final center = tester.getCenter(find.byType(WebViewWidget));
      final selection = await tester.startGesture(center);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      platform.controller.sendSurfaceMessage({'hasSelection': true});
      await tester.pump();
      await selection.moveBy(const Offset(-160, 0));
      platform.controller.sendSurfaceMessage({'hasSelection': false});
      await selection.moveBy(const Offset(100, 0));
      await selection.up();
      await tester.pumpAndSettle();
      expectSopPage(tester, navigation);
      expect(platform.controller.pointerTarget.events.whereType<PointerMoveEvent>(), hasLength(2));
      expect(platform.controller.pointerTarget.events.whereType<PointerCancelEvent>(), isEmpty);

      platform.controller.pointerTarget.events.clear();
      final first = await tester.startGesture(center - const Offset(40, 0), pointer: 1);
      final second = await tester.startGesture(center + const Offset(40, 0), pointer: 2);
      platform.controller.sendSurfaceMessage({'zoomed': true});
      await tester.pump();
      await first.moveBy(const Offset(-40, 0));
      await second.moveBy(const Offset(40, 0));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expectSopPage(tester, navigation);
      expect(platform.controller.pointerTarget.events.whereType<PointerDownEvent>(), hasLength(2));
      expect(platform.controller.pointerTarget.events.whereType<PointerMoveEvent>(), hasLength(2));
      expect(platform.controller.pointerTarget.events.whereType<PointerCancelEvent>(), isEmpty);
      await tester.drag(find.byType(WebViewWidget), const Offset(-240, 0));
      await tester.pumpAndSettle();
      expectSopPage(tester, navigation);
      platform.controller.sendSurfaceMessage({'zoomed': false});
      await tester.drag(find.byType(WebViewWidget), const Offset(-240, 0));
      await tester.pumpAndSettle();
      expect(navigation.selectedIndex, 2);
    },
  );
}

class _WebViewPlatform extends WebViewPlatform {
  late _WebViewController controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _WebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      _WebViewWidget(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _NavigationDelegate(params);
}

class _WebViewController extends PlatformWebViewController {
  _WebViewController(super.params) : super.implementation();

  final commands = <Map<String, dynamic>>[];
  final _channels = <String, JavaScriptChannelParams>{};
  late _NavigationDelegate _navigation;
  bool _sopInstalled = false;
  bool failInit = false;
  final pointerTarget = _SopPlatformViewController();

  void sendSurfaceMessage(Map<String, bool> message) => _channels['TrainingSopLinks']!
      .onMessageReceived(JavaScriptMessage(message: jsonEncode(message)));

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    _channels[params.name] = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {
    _navigation = handler as _NavigationDelegate;
  }

  @override
  Future<void> loadFile(String absoluteFilePath) async {
    _navigation.onPageFinished(absoluteFilePath);
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    if (javaScript.contains('Adapter injected successfully')) {
      _send({'type': 'engineGlobalReady'});
    } else if (javaScript.contains('window.TrainingSopDocument=')) {
      _sopInstalled = true;
    } else if (javaScript.startsWith('TiptapEngine.handleCommand(')) {
      final json = javaScript
          .substring("TiptapEngine.handleCommand('".length, javaScript.length - 2)
          .replaceAll(r"\'", "'")
          .replaceAll(r'\\', r'\');
      final command = jsonDecode(json) as Map<String, dynamic>;
      commands.add(command);
      if (command['name'] == 'init') {
        if (!_sopInstalled) throw StateError('Document initialized with the wrong engine');
        if (failInit) throw StateError('Native init failed');
        _send({'type': 'event', 'name': 'schemaReady', 'payload': <String, dynamic>{}});
        _send({'type': 'event', 'name': 'ready', 'payload': <String, dynamic>{}});
        _send({
          'type': 'event',
          'name': 'stateChanged',
          'payload': {
            'editable': (command['payload'] as Map<String, dynamic>)['editable'],
            'doc': {
              'type': 'doc',
              'content': [
                {
                  'type': 'paragraph',
                  'content': [
                    {'type': 'text', 'text': 'Native SOP'},
                  ],
                },
              ],
            },
          },
        });
      }
      _send({'type': 'response', 'id': command['id'], 'success': true});
    }
  }

  void _send(Map<String, dynamic> message) =>
      _channels['TiptapBridge']!.onMessageReceived(JavaScriptMessage(message: jsonEncode(message)));
}

class _WebViewWidget extends PlatformWebViewWidget {
  _WebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => PlatformViewSurface(
    controller: (params.controller as _WebViewController).pointerTarget,
    gestureRecognizers: params.gestureRecognizers,
    hitTestBehavior: PlatformViewHitTestBehavior.opaque,
  );
}

class _SopPlatformViewController extends PlatformViewController {
  final events = <PointerEvent>[];

  @override
  int get viewId => 1;

  @override
  Future<void> dispatchPointerEvent(PointerEvent event) async => events.add(event);

  @override
  Future<void> clearFocus() async {}

  @override
  Future<void> dispose() async {}
}

class _NavigationDelegate extends PlatformNavigationDelegate {
  _NavigationDelegate(super.params) : super.implementation();

  late PageEventCallback onPageFinished;

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async => onPageFinished = callback;

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}

  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback callback) async {}
}
