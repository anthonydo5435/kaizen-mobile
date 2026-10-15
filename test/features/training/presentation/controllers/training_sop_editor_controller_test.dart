import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_sop_editor_controller.dart';
import 'package:tiptap_flutter/tiptap_flutter.dart';

void main() {
  late _Editor editor;
  late TrainingSopEditorController controller;
  late List<String> changes;
  const html =
      '<h2>Procedure</h2><p>First<br><br>Second</p><p></p>'
      '<ul><li><p><strong>Check</strong> equipment</p></li></ul>';

  setUp(() {
    editor = _Editor();
    changes = [];
    controller = TrainingSopEditorController(
      initialHtml: html,
      editor: editor,
      onHtmlChanged: changes.add,
    );
  });
  tearDown(() {
    if (!editor.disposed) controller.dispose();
  });

  test('loads original HTML without publishing normalization or selection changes', () async {
    await controller.initialize();
    expect(editor.initialHtml, html);
    expect(controller.isReady, isTrue);
    editor.emit(
      _document('Procedure'),
      selection: const SelectionState(anchor: 2, head: 2, from: 2, to: 2, empty: true),
    );
    await Future<void>.delayed(Duration.zero);
    expect(changes, isEmpty);
    expect(editor.htmlReads, 0);
  });

  test('handles an initial document delivered after readiness without saving it', () async {
    editor.deliverInitialDocument = false;
    await controller.initialize();
    editor.emit(_document('Procedure'));
    await Future<void>.delayed(Duration.zero);
    expect(changes, isEmpty);
    expect(editor.htmlReads, 0);
  });

  test('publishes formatting-only changes as HTML and preserves hard breaks', () async {
    await controller.initialize();
    editor.html = html;
    editor.emit(_document('Procedure', bold: true));
    await Future<void>.delayed(Duration.zero);
    expect(changes, [html]);
    expect(changes.single, contains('<br><br>'));
    expect(changes.single, contains('<p></p>'));
    await controller.format(EditorCommand.toggleHeading, {'level': 2});
    expect(editor.commands.single.$1, EditorCommand.toggleHeading);
    expect(editor.commands.single.$2, {'level': 2});
  });

  test('an older HTML response cannot replace newer typing', () async {
    await controller.initialize();
    final older = Completer<String>();
    editor.nextHtml = older.future;
    editor.emit(_document('Older'));
    await Future<void>.delayed(Duration.zero);
    editor.html = '<p>Newer</p>';
    editor.emit(_document('Newer'));
    await Future<void>.delayed(Duration.zero);
    older.complete('<p>Older</p>');
    await Future<void>.delayed(Duration.zero);
    expect(changes, ['<p>Newer</p>']);
  });

  test('disposal discards pending HTML and releases the engine', () async {
    await controller.initialize();
    final pending = Completer<String>();
    editor.nextHtml = pending.future;
    editor.emit(_document('Edited'));
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    pending.complete('<p>Edited</p>');
    await Future<void>.delayed(Duration.zero);
    expect(editor.disposed, isTrue);
    expect(changes, isEmpty);
  });

  test('initialization failure exposes a user-facing error', () async {
    editor.initializationError = StateError('Engine unavailable');
    await controller.initialize();
    expect(controller.isReady, isFalse);
    expect(controller.errorMessage, AppStrings.trainingSopEditorError);
    expect(changes, isEmpty);
  });

  test('read-only documents cannot format or publish a change', () async {
    await controller.initialize(editable: false);
    expect(editor.editable, isFalse);
    await controller.format(EditorCommand.toggleBold);
    editor.html = '<p>Changed</p>';
    editor.emit(_document('Changed'));
    await Future<void>.delayed(Duration.zero);
    expect(editor.commands, isEmpty);
    expect(editor.htmlReads, 0);
    expect(changes, isEmpty);
  });
}

AnnotatedNode _document(String text, {bool bold = false}) => AnnotatedNode(
  type: 'doc',
  content: [
    AnnotatedNode(
      type: 'paragraph',
      content: [
        AnnotatedNode(
          type: 'text',
          text: text,
          marks: bold ? const [MarkData(type: 'bold')] : null,
        ),
      ],
    ),
  ],
);

class _Editor extends Fake implements EditorController {
  final states = StreamController<EditorStatePayload>.broadcast();
  final commands = <(String, Map<String, dynamic>?)>[];
  String? initialHtml;
  String html = '';
  int htmlReads = 0;
  bool disposed = false;
  bool editable = true;
  bool deliverInitialDocument = true;
  Object? initializationError;
  Future<String>? nextHtml;
  AnnotatedNode? _cachedDocument;

  @override
  Stream<EditorStatePayload> get editorStateStream => states.stream;

  @override
  AnnotatedNode? get document => _cachedDocument;

  @override
  Future<void> initialize({String? content, bool editable = true}) async {
    if (initializationError != null) throw initializationError!;
    initialHtml = content;
    this.editable = editable;
    if (deliverInitialDocument) emit(_document('Procedure'));
    await Future<void>.delayed(Duration.zero);
  }

  void emit(AnnotatedNode document, {SelectionState? selection}) {
    _cachedDocument = document;
    states.add(EditorStatePayload(doc: document, selection: selection, editable: editable));
  }

  @override
  Future<String> getHTML() {
    htmlReads += 1;
    final pending = nextHtml;
    nextHtml = null;
    return pending ?? Future.value(html);
  }

  @override
  Future<void> execCommand(String commandName, [Map<String, dynamic>? args]) async {
    commands.add((commandName, args));
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(states.close());
  }
}
