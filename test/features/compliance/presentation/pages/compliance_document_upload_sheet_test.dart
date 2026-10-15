import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/widgets/app_overlay_close_button.dart';
import 'package:sparrowkaizen/features/compliance/data/models/compliance_document_model.dart';
import 'package:sparrowkaizen/features/compliance/domain/entities/compliance_document.dart';
import 'package:sparrowkaizen/features/compliance/domain/entities/compliance_presigned_upload.dart';
import 'package:sparrowkaizen/features/compliance/domain/repositories/compliance_document_media_repository.dart';
import 'package:sparrowkaizen/features/compliance/domain/repositories/compliance_repository.dart';
import 'package:sparrowkaizen/features/compliance/domain/usecases/upload_compliance_document_usecase.dart';
import 'package:sparrowkaizen/features/compliance/domain/usecases/pick_compliance_document_file_usecase.dart';
import 'package:sparrowkaizen/features/compliance/presentation/pages/document/compliance_document_upload_sheet.dart';
import 'package:sparrowkaizen/features/compliance/presentation/widgets/document_card.dart';

void main() {
  final documentMappers = <String, ComplianceDocument Function(bool)>{
    'document definition': (requiresExpiry) =>
        ComplianceDocumentModel.fromApiJson({
          'uuid': 'document',
          'name': 'Compliance Document',
          'expiry': requiresExpiry,
        }),
    'assigned document': (requiresExpiry) =>
        ComplianceDocumentModal.fromApiJson({
          'uuid': 'document',
          'name': 'Compliance Document',
          'status': 'pending_submission',
          'has_expiry': requiresExpiry,
        }),
  };

  for (final mapper in documentMappers.entries) {
    testWidgets(
      '${mapper.key} allows entering expiry immediately after opening upload',
      (tester) async {
        await _openUploadSheet(tester, mapper.value(true));

        final expiryField = find.byType(TextField);
        expect(find.text(AppStrings.enterExpiryDate), findsOneWidget);
        expect(find.text(AppStrings.clickToUploadDocument), findsOneWidget);
        await tester.enterText(expiryField, '2027-12-10');
        expect(
          tester.widget<TextField>(expiryField).controller!.text,
          'Dec 10, 2027',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${mapper.key} hides expiry when it is not required', (
      tester,
    ) async {
      await _openUploadSheet(tester, mapper.value(false));

      expect(find.text(AppStrings.clickToUploadDocument), findsOneWidget);
      expect(find.text(AppStrings.enterExpiryDate), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Camera is first and a captured photo uploads with the expiry', (
    tester,
  ) async {
    final photo = File('lib/assets/images/google_g.png').absolute;
    final media = _MediaRepository()..load = (_) async => photo.path;
    final upload = _UploadRepository();
    await _openUploadSheet(
      tester,
      documentMappers['assigned document']!(true),
      mediaRepository: media,
      uploadRepository: upload,
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.clickToUploadDocument));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isFalse,
    );
    expect(
      tester.getTopLeft(find.text(AppStrings.complianceCamera)).dy,
      lessThan(
        tester.getTopLeft(find.text(AppStrings.complianceSelectImage)).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.text(AppStrings.complianceSelectImage)).dy,
      lessThan(tester.getTopLeft(find.text(AppStrings.complianceSelectPdf)).dy),
    );
    await tester.tap(find.text(AppStrings.complianceCamera));
    await tester.pumpAndSettle();
    expect(media.sources, [ComplianceDocumentFileSource.camera]);
    final preview = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is FileImage,
    );
    expect(preview, findsOneWidget);
    expect(
      (tester.widget<Image>(preview).image as FileImage).file.path,
      photo.path,
    );
    expect(tester.widget<Image>(preview).fit, BoxFit.contain);
    expect(find.text(AppStrings.clickToUploadDocument), findsNothing);
    await tester.tap(find.text(AppStrings.submit));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.expiryDateRequired), findsOneWidget);
    expect(upload.operations, isEmpty);

    await tester.enterText(find.byType(TextField), '2027-04-05');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final bytes = await tester.runAsync(() => photo.readAsBytes());
    final submitButton = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text(AppStrings.submit),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    await tester.runAsync(submitButton.onPressed! as Future<void> Function());
    await tester.pumpAndSettle();
    expect(upload.operations, ['presign', 'file', 'record']);
    expect(upload.fileBytes, bytes);
    expect(upload.contentType, 'image/png');
    expect(upload.documentId, 'document');
    expect(upload.expiryDate, '2027-04-05');
    expect(find.byType(ComplianceDocumentUploadSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  final sourceTitles = {
    ComplianceDocumentFileSource.camera: AppStrings.complianceCamera,
    ComplianceDocumentFileSource.gallery: AppStrings.complianceSelectImage,
    ComplianceDocumentFileSource.pdf: AppStrings.complianceSelectPdf,
  };
  for (final entry in sourceTitles.entries) {
    testWidgets('cancelling ${entry.value} keeps the upload sheet ready', (
      tester,
    ) async {
      final media = _MediaRepository();
      await _openUploadSheet(
        tester,
        documentMappers['assigned document']!(false),
        mediaRepository: media,
      );
      await tester.tap(find.text(AppStrings.clickToUploadDocument));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.value));
      await tester.pumpAndSettle();
      expect(media.sources, [entry.key]);
      expect(find.text(AppStrings.clickToUploadDocument), findsOneWidget);
      expect(find.text(AppStrings.cancelUpload), findsOneWidget);
      expect(find.text(AppStrings.complianceCamera), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('camera denial shows a visible permission error', (tester) async {
    final media = _MediaRepository()
      ..load = (_) async =>
          throw PlatformException(code: 'camera_access_denied');
    await _openUploadSheet(
      tester,
      documentMappers['assigned document']!(false),
      mediaRepository: media,
    );
    await tester.tap(find.text(AppStrings.clickToUploadDocument));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.complianceCamera));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.complianceCameraPermissionRequired).hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(ComplianceDocumentUploadSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'upload options remain scrollable on compact screens with larger text',
    (tester) async {
      await _openUploadSheet(
        tester,
        documentMappers['assigned document']!(false),
        viewport: const Size(360, 740),
        textScale: 2,
      );
      await tester.tap(find.text(AppStrings.clickToUploadDocument));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(AppStrings.complianceSelectPdf));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.complianceSelectPdf));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.clickToUploadDocument), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('existing document expiry prefills the field and calendar', (
    tester,
  ) async {
    final document = ComplianceDocumentModal.fromApiJson({
      'uuid': 'document',
      'name': 'Compliance Document',
      'has_expiry': true,
      'status': 'compliant',
      'latest_document': {'expiry_date': '2027-04-05', 'status': 'approved'},
    });
    await _openUploadSheet(tester, document);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Apr 05, 2027',
    );
    await tester.tap(find.byTooltip(AppStrings.selectExpiryDate));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .initialDate,
      DateTime(2027, 4, 5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expiry shown on a rejected card is visible when its sheet opens',
    (tester) async {
      await _openUploadSheet(
        tester,
        _rejectedDocument(
          'Please upload a signed copy of every page.',
          expiryDate: '05 Apr, 2027',
        ),
        viewport: const Size(414, 740),
        fromCard: true,
      );
      expect(find.text('05 Apr, 2027'), findsOneWidget);
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).controller!.text, 'Apr 05, 2027');
      expect(field.hitTestable(), findsOneWidget);
      expect(
        find.byTooltip(AppStrings.selectExpiryDate).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rejection preview truncates and its full dialog closes with OK or cross',
    (tester) async {
      final reason = List.filled(
        30,
        'The uploaded document is missing signed pages. Please include every page and ensure the text is readable.',
      ).join(' ');
      await _openUploadSheet(tester, _rejectedDocument(reason));
      final showMore = find.text(AppStrings.complianceShowMore);
      final preview = tester.renderObject<RenderParagraph>(
        find.ancestor(of: showMore, matching: find.byType(RichText)).first,
      );
      expect(preview.maxLines, 2);
      expect(preview.didExceedMaxLines, isFalse);
      expect(preview.text.toPlainText().length, lessThan(reason.length));
      final ellipsis = find.text(AppStrings.complianceRejectionPreviewEllipsis);
      expect(ellipsis, findsOneWidget);
      expect(
        tester.getTopLeft(showMore).dx,
        closeTo(tester.getTopRight(ellipsis).dx, 0.01),
      );

      await tester.tap(find.text(AppStrings.complianceShowMore));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final fullReason = find.descendant(
        of: dialog,
        matching: find.text(reason),
      );
      expect(fullReason, findsOneWidget);
      expect(tester.widget<Text>(fullReason).maxLines, isNull);
      final dialogScroll = find.descendant(
        of: dialog,
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(dialogScroll, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.complianceRejectionReasonOk));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.byType(ComplianceDocumentUploadSheet), findsOneWidget);

      await tester.tap(find.text(AppStrings.complianceShowMore));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.byType(AppOverlayCloseButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.byType(ComplianceDocumentUploadSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final reason in [
    'Page missing.',
    'Please upload the signed document.',
  ]) {
    testWidgets('a complete rejection reason has no Show More: $reason', (
      tester,
    ) async {
      await _openUploadSheet(tester, _rejectedDocument(reason));
      expect(find.text(reason), findsOneWidget);
      expect(find.text(AppStrings.complianceShowMore), findsNothing);
      expect(
        find.text(AppStrings.complianceRejectionPreviewEllipsis),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in [const Size(390, 844), const Size(360, 740)]) {
    testWidgets('No Expiry sheet has compact gaps on $viewport', (
      tester,
    ) async {
      const reason = 'Page missing.';
      await _openUploadSheet(
        tester,
        _rejectedDocument(reason, requiresExpiry: false),
        viewport: viewport,
      );
      final reasonCard = find
          .ancestor(of: find.text(reason), matching: find.byType(Container))
          .first;
      final uploadArea = find
          .ancestor(
            of: find.text(AppStrings.clickToUploadDocument),
            matching: find.byType(GestureDetector),
          )
          .first;
      final button = find
          .ancestor(
            of: find.text(AppStrings.cancelUpload),
            matching: find.byType(FilledButton),
          )
          .first;
      await tester.ensureVisible(uploadArea);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(uploadArea).dy - tester.getBottomLeft(reasonCard).dy,
        closeTo(16, 0.01),
      );
      expect(
        tester.getTopLeft(button).dy - tester.getBottomLeft(uploadArea).dy,
        closeTo(20, 0.01),
      );
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final requiresExpiry in [true, false]) {
    testWidgets(
      'rejection dialog fits larger text with expiry $requiresExpiry',
      (tester) async {
        const reason =
            'Please upload a signed copy of all required document pages.';
        await _openUploadSheet(
          tester,
          _rejectedDocument(reason, requiresExpiry: requiresExpiry),
          viewport: const Size(360, 740),
          textScale: 2,
        );
        await tester.ensureVisible(find.text(AppStrings.complianceShowMore));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.complianceShowMore));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(reason),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(AppStrings.complianceRejectionReasonOk));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('expiry-required upload fits a compact mobile viewport', (
    tester,
  ) async {
    await _openUploadSheet(
      tester,
      documentMappers['assigned document']!(true),
      viewport: const Size(360, 740),
    );

    expect(find.text(AppStrings.enterExpiryDate), findsOneWidget);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar starts today and returns a formatted expiration date', (
    tester,
  ) async {
    await _openUploadSheet(tester, documentMappers['assigned document']!(true));
    await tester.tap(find.byTooltip(AppStrings.selectExpiryDate));
    await tester.pumpAndSettle();

    final today = DateUtils.dateOnly(DateTime.now());
    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.firstDate, today);
    expect(calendar.initialDate, today);
    final selectedDay = find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('${today.day}'),
    );
    final selectedDecoration =
        tester
                .widget<Ink>(
                  find
                      .ancestor(of: selectedDay, matching: find.byType(Ink))
                      .first,
                )
                .decoration
            as ShapeDecoration;
    expect(selectedDecoration.color, AppColors.secondaryColor);
    expect(selectedDecoration.shape, isA<RoundedRectangleBorder>());
    expect(
      (selectedDecoration.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(8),
    );
    if (today.day > 1) {
      final yesterday = find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('${today.day - 1}'),
      );
      await tester.tap(yesterday);
      await tester.pump();
      expect(
        find.text(
          MaterialLocalizations.of(
            tester.element(find.byType(CalendarDatePicker)),
          ).formatMediumDate(today),
        ),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.text(
        MaterialLocalizations.of(
          tester.element(find.byType(CalendarDatePicker)),
        ).okButtonLabel,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '${AppStrings.expiryDateMonths[today.month - 1]} '
      '${today.day.toString().padLeft(2, '0')}, ${today.year}',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('typed numeric dates format and past dates show feedback', (
    tester,
  ) async {
    await _openUploadSheet(tester, documentMappers['assigned document']!(true));
    final field = find.byType(TextField);
    await tester.enterText(field, '04/05/2027');
    expect(tester.widget<TextField>(field).controller!.text, 'Apr 05, 2027');
    await tester.enterText(field, '04/32/2027');
    expect(tester.widget<TextField>(field).controller!.text, 'Apr 05, 2027');

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await tester.enterText(
      field,
      '${yesterday.month}/${yesterday.day}/${yesterday.year}',
    );
    await tester.pump();
    expect(find.text(AppStrings.expiryDateInPast), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'month digit typing updates the displayed month before DD entry',
    (tester) async {
      await _openUploadSheet(
        tester,
        documentMappers['assigned document']!(true),
      );
      final field = find.byType(TextField);
      await tester.enterText(field, '1');
      expect(tester.widget<TextField>(field).controller!.text, 'Jan DD, YYYY');
      expect(
        tester
            .widget<TextField>(field)
            .controller!
            .selection
            .textInside(tester.widget<TextField>(field).controller!.text),
        'DD',
      );

      void typeCharacter(String character) {
        final value = tester.widget<TextField>(field).controller!.value;
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: value.text.replaceRange(
              value.selection.start,
              value.selection.end,
              character,
            ),
            selection: TextSelection.collapsed(
              offset: value.selection.start + character.length,
            ),
          ),
        );
      }

      typeCharacter('2');
      expect(tester.widget<TextField>(field).controller!.text, 'Dec DD, YYYY');
      expect(
        tester
            .widget<TextField>(field)
            .controller!
            .selection
            .textInside(tester.widget<TextField>(field).controller!.text),
        'DD',
      );
      await tester.enterText(field, '3');
      expect(tester.widget<TextField>(field).controller!.text, 'Mar DD, YYYY');
      typeCharacter('9');
      expect(tester.widget<TextField>(field).controller!.text, 'Sep DD, YYYY');
      typeCharacter('0');
      typeCharacter('5');
      expect(
        tester
            .widget<TextField>(field)
            .controller!
            .selection
            .textInside(tester.widget<TextField>(field).controller!.text),
        'YYYY',
      );
      expect(find.text(AppStrings.enterExpirationDate), findsOneWidget);
      for (final character in '2027'.split('')) {
        typeCharacter(character);
      }
      expect(tester.widget<TextField>(field).controller!.text, 'Sep 05, 2027');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expiration input remains above the keyboard on mobile', (
    tester,
  ) async {
    await _openUploadSheet(
      tester,
      documentMappers['assigned document']!(true),
      viewport: const Size(360, 740),
    );
    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();

    expect(tester.getBottomRight(field).dy, lessThanOrEqualTo(440));
    await tester.enterText(field, '04/05/2027');
    expect(tester.widget<TextField>(field).controller!.text, 'Apr 05, 2027');
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus selects MMMM and tapping DD starts day entry', (
    tester,
  ) async {
    await _openUploadSheet(tester, documentMappers['assigned document']!(true));
    final field = find.byType(TextField);
    expect(find.text(AppStrings.expirationDateWithFormat), findsOneWidget);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.enterExpirationDate), findsOneWidget);
    expect(find.text(AppStrings.expirationDateWithFormat), findsNothing);
    final textController = tester.widget<TextField>(field).controller!;
    expect(textController.text, AppStrings.enterExpiryDate);
    expect(textController.selection.textInside(textController.text), 'MMMM');

    void typeCharacter(String character) {
      final value = textController.value;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: value.text.replaceRange(
            value.selection.start,
            value.selection.end,
            character,
          ),
          selection: TextSelection.collapsed(
            offset: value.selection.start + character.length,
          ),
        ),
      );
    }

    typeCharacter('2');
    await tester.pump();
    expect(textController.text, 'Feb DD, YYYY');
    expect(textController.selection.textInside(textController.text), 'DD');
    final RenderEditable editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final caret = editable.getLocalRectForCaret(const TextPosition(offset: 5));
    await tester.tapAt(editable.localToGlobal(caret.center));
    await tester.pumpAndSettle();
    expect(textController.selection.textInside(textController.text), 'DD');
    typeCharacter('1');
    expect(textController.text, 'Feb 1D, YYYY');
    typeCharacter('5');
    expect(textController.text, 'Feb 15, YYYY');
    expect(textController.selection.textInside(textController.text), 'YYYY');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openUploadSheet(
  WidgetTester tester,
  ComplianceDocument document, {
  Size viewport = const Size(390, 844),
  double textScale = 1,
  bool fromCard = false,
  ComplianceDocumentMediaRepository? mediaRepository,
  ComplianceRepository? uploadRepository,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppManager>.value(value: AppManager.instance),
        Provider<UploadComplianceDocumentUseCase>.value(
          value: UploadComplianceDocumentUseCase(
            uploadRepository ?? _Repository(),
          ),
        ),
        Provider<PickComplianceDocumentFileUseCase>.value(
          value: PickComplianceDocumentFileUseCase(
            mediaRepository ?? _MediaRepository(),
          ),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: fromCard
              ? DocumentCard(document: document)
              : Builder(
                  builder: (context) => FilledButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ComplianceDocumentUploadSheet(
                        document: document,
                        uploadComplianceDocumentUseCase: context
                            .read<UploadComplianceDocumentUseCase>(),
                        pickComplianceDocumentFileUseCase: context
                            .read<PickComplianceDocumentFileUseCase>(),
                      ),
                    ),
                    child: const Text(AppStrings.uploadDoc),
                  ),
                ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(AppStrings.uploadDoc));
  await tester.pumpAndSettle();
}

ComplianceDocument _rejectedDocument(
  String reason, {
  String? expiryDate,
  bool requiresExpiry = true,
}) => ComplianceDocumentModal.fromApiJson({
  'uuid': 'document',
  'name': 'Compliance Document',
  'has_expiry': requiresExpiry,
  'status': 'rejected',
  'latest_document': {
    'status': 'rejected',
    'reason': reason,
    if (expiryDate != null) 'expiry_date': expiryDate,
  },
});

class _Repository implements ComplianceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MediaRepository implements ComplianceDocumentMediaRepository {
  final sources = <ComplianceDocumentFileSource>[];
  Future<String?> Function(ComplianceDocumentFileSource) load = (_) async =>
      null;

  @override
  Future<String?> pickFile(ComplianceDocumentFileSource source) {
    sources.add(source);
    return load(source);
  }
}

class _UploadRepository extends _Repository {
  final operations = <String>[];
  List<int>? fileBytes;
  String? contentType;
  String? documentId;
  String? expiryDate;

  @override
  Future<CompliancePresignedUpload> generateComplianceDocumentUploadUrl({
    required String fileName,
  }) async {
    operations.add('presign');
    return const CompliancePresignedUpload(
      uploadUrl: 'https://example.com/photo.png?signature=test',
    );
  }

  @override
  Future<void> uploadComplianceDocumentFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
    ValueChanged<double>? onProgress,
  }) async {
    operations.add('file');
    this.fileBytes = fileBytes;
    this.contentType = contentType;
    onProgress?.call(1);
  }

  @override
  Future<void> uploadComplianceDocumentRecord({
    required String complianceDocumentId,
    required String fileName,
    required String documentUrl,
    String? expiryDate,
  }) async {
    operations.add('record');
    documentId = complianceDocumentId;
    this.expiryDate = expiryDate;
  }
}
