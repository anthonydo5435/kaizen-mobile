import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tiptap_flutter/tiptap_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// The document surface is replaceable without changing Tiptap's save contract.
abstract interface class TrainingSopSurface {
  Stream<String> get linkTaps;
  Widget buildDocument({required double width, required double textScale});
  Future<void> dismissKeyboard();
}

/// Uses the package's public bridge with the SOP-specific Tiptap extension set.
/// The browser renders the A4 document so table spans and HTML styles stay intact.
class TrainingSopEngineController extends EditorController implements TrainingSopSurface {
  static const _assets = 'lib/features/training/presentation/assets/sop_editor';
  static const _nativeEditing = MethodChannel('kaizenteams/training_sop_webview');
  late final WebViewController _view = WebViewController.fromPlatform(
    (super.webViewWidget as WebViewWidget).platform.params.controller,
  );
  final _links = StreamController<String>.broadcast();
  bool _isZoomed = false;
  bool _hasSelection = false;
  bool _disposed = false;
  bool _documentReady = false;
  double _width = 320;
  double _textScale = 1;
  String _sourceStyles = '';

  @override
  Stream<String> get linkTaps => _links.stream;

  @override
  Future<void> initialize({String? content, bool editable = true}) async {
    // Register channels before navigation, then install the SOP schema before
    // initializing any document. Replacing an initialized engine loses replies.
    await _view.addJavaScriptChannel('TrainingSopLinks', onMessageReceived: _handleSurfaceMessage);
    if (_disposed) return;
    final engineGlobal = bridge.engineStateStream
        .firstWhere((state) => state == EngineState.engineGlobalReady || state == EngineState.error)
        .timeout(const Duration(seconds: 15));
    await Future.wait<Object?>([bridge.initialize(), engineGlobal], eagerError: true);
    if (bridge.engineState == EngineState.error) {
      throw StateError(bridge.errorMessage ?? 'SOP engine startup failed');
    }
    if (_disposed) return;
    final assets = await Future.wait([
      rootBundle.loadString('$_assets/sop-engine.js'),
      rootBundle.loadString('$_assets/sop-document.css'),
    ]);
    if (_disposed) return;
    final styles = RegExp(
      r'<style\b[^>]*>([\s\S]*?)</style>',
      caseSensitive: false,
    ).allMatches(content ?? '').toList();
    _sourceStyles = styles.map((match) => match.group(0)!).join('\n');
    final sourceCss = styles.map((match) => match.group(1)!).join('\n');
    await _view.runJavaScript(assets[0]);
    await _view.runJavaScript(
      'window.TrainingSopDocument.installStyles(${jsonEncode(assets[1])}, ${jsonEncode(sourceCss)});',
    );
    await _configureViewport();
    // Attach the controller to the prepared bridge and initialize it once.
    final controllerReady = super.initialize(content: content, editable: editable);
    final initialDocument = editorStateStream
        .firstWhere((state) => state.doc != null)
        .timeout(const Duration(seconds: 10));
    await Future.wait([
      bridge.initEditor(content: content, editable: editable),
      controllerReady,
      initialDocument,
    ], eagerError: true);
    if (_disposed) return;
    _documentReady = true;
    await _configureViewport();
    if (editable && defaultTargetPlatform == TargetPlatform.iOS) {
      if (_view.platform case final WebKitWebViewController platform) {
        await _nativeEditing.invokeMethod<void>('configureEditing', {
          'webViewIdentifier': platform.webViewIdentifier,
        });
      }
    }
  }

  void _handleSurfaceMessage(JavaScriptMessage message) {
    if (_disposed) return;
    final data = jsonDecode(message.message) as Map<String, dynamic>;
    if (data['href'] case final String href) {
      _links.add(href);
    } else if (data['zoomed'] case final bool zoomed) {
      _isZoomed = zoomed;
    } else if (data['hasSelection'] case final bool hasSelection) {
      _hasSelection = hasSelection;
    }
  }

  @override
  Future<String> getHTML() async => '$_sourceStyles${await super.getHTML()}';

  @override
  Widget buildDocument({required double width, required double textScale}) {
    if (_width != width || _textScale != textScale) {
      _width = width;
      _textScale = textScale;
      if (_documentReady) unawaited(_configureViewport());
    }
    return WebViewWidget(
      controller: _view,
      gestureRecognizers: {
        Factory<VerticalDragGestureRecognizer>(VerticalDragGestureRecognizer.new),
        Factory<LongPressGestureRecognizer>(LongPressGestureRecognizer.new),
        Factory<_SopDocumentGestureRecognizer>(
          () => _SopDocumentGestureRecognizer(claimSinglePointer: () => _isZoomed || _hasSelection),
        ),
      },
    );
  }

  Future<void> _configureViewport() => _view.runJavaScript(
    'window.TrainingSopDocument.configure(${jsonEncode({'width': _width, 'textScale': _textScale})});',
  );

  @override
  Future<void> dismissKeyboard() async {
    if (_documentReady && !_disposed) {
      await _view.runJavaScript('window.TrainingSopDocument.blur();');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_links.close());
    super.dispose();
  }
}

/// Keeps native selection and zoom drags in the SOP. Read live state on pointer
/// down instead of rebuilding recognizers, which would cancel an ongoing drag.
class _SopDocumentGestureRecognizer extends OneSequenceGestureRecognizer {
  _SopDocumentGestureRecognizer({required this.claimSinglePointer});

  final bool Function() claimSinglePointer;
  final _pointers = <int>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer);
    _pointers.add(event.pointer);
    if (_pointers.length >= 2 || claimSinglePointer()) resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) => resolve(GestureDisposition.rejected);

  @override
  String get debugDescription => 'SOP selection and zoom';
}
