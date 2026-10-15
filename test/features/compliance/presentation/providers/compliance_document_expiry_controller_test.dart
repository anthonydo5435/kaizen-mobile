import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_document_expiry_controller.dart';

void main() {
  late ComplianceDocumentExpiryController controller;
  setUp(() {
    controller = ComplianceDocumentExpiryController(
      currentDate: () => DateTime(2026, 10, 12, 15, 30),
    );
  });
  tearDown(() => controller.dispose());

  TextEditingValue replace(String text) {
    final value = controller.formatEditUpdate(
      controller.textController.value.copyWith(
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: controller.textController.text.length,
        ),
      ),
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
    controller.textController.value = value;
    return value;
  }

  TextEditingValue type(String text) {
    final old = controller.textController.value;
    final selection = old.selection;
    final value = controller.formatEditUpdate(
      old,
      TextEditingValue(
        text: old.text.replaceRange(selection.start, selection.end, text),
        selection: TextSelection.collapsed(
          offset: selection.start + text.length,
        ),
      ),
    );
    controller.textController.value = value;
    return value;
  }

  String selectedText() {
    final value = controller.textController.value;
    return value.selection.textInside(value.text);
  }

  test(
    'prefills an existing expiry in display format and retains its API value',
    () {
      for (final value in [
        '2027-04-05',
        '2027-04-05T00:00:00Z',
        '2027-04-05 00:00:00',
        'Apr 05, 2027',
        '05 Apr, 2027',
        '5 April 2027',
        '04/05/2027',
        '${DateTime(2027, 4, 5).millisecondsSinceEpoch}',
        '${DateTime(2027, 4, 5).millisecondsSinceEpoch ~/ 1000}',
      ]) {
        final seeded = ComplianceDocumentExpiryController(
          currentDate: () => DateTime(2026, 10, 12),
          initialExpiryDate: value,
        );
        expect(seeded.textController.text, 'Apr 05, 2027');
        expect(seeded.apiExpiryDate, '2027-04-05');
        expect(seeded.validate(), isTrue);
        seeded.dispose();
      }
    },
  );

  test(
    'prefills an expired date and retains the today-or-later validation',
    () {
      final seeded = ComplianceDocumentExpiryController(
        currentDate: () => DateTime(2026, 10, 12),
        initialExpiryDate: '2020-04-05',
      );
      expect(seeded.textController.text, 'Apr 05, 2020');
      expect(seeded.errorText, AppStrings.expiryDateInPast);
      expect(seeded.validate(), isFalse);
      expect(seeded.apiExpiryDate, isNull);
      seeded.selectDate(DateTime(2027, 4, 5));
      expect(seeded.errorText, isNull);
      expect(seeded.apiExpiryDate, '2027-04-05');
      seeded.dispose();
    },
  );

  test('missing or invalid saved dates leave the initial field empty', () {
    for (final value in [
      null,
      '',
      'not-a-date',
      '2027-02-30',
      '30 Feb, 2027',
    ]) {
      final seeded = ComplianceDocumentExpiryController(
        initialExpiryDate: value,
      );
      expect(seeded.textController.text, isEmpty);
      expect(seeded.errorText, isNull);
      seeded.dispose();
    }
  });

  test(
    'month preview highlights DD and the second digit completes the month',
    () {
      expect(replace('1').text, 'Jan DD, YYYY');
      expect(selectedText(), 'DD');
      expect(type('2').text, 'Dec DD, YYYY');
      expect(selectedText(), 'DD');
      expect(type('0').text, 'Dec 0D, YYYY');
      expect(selectedText(), 'D');
      expect(type('5').text, 'Dec 05, YYYY');
      expect(selectedText(), 'YYYY');
      expect(type('2').text, 'Dec 05, 2YYY');
      expect(selectedText(), 'YYY');
      expect(type('0').text, 'Dec 05, 20YY');
      expect(type('2').text, 'Dec 05, 202Y');
      expect(type('7').text, 'Dec 05, 2027');
      expect(controller.textController.selection.isCollapsed, isTrue);
      expect(controller.validate(), isTrue);
      expect(controller.apiExpiryDate, '2027-12-05');
    },
  );

  test('all single digits preview months and 10, 11, 12 combine correctly', () {
    for (var digit = 1; digit <= 9; digit++) {
      expect(
        replace('$digit').text,
        '${AppStrings.expiryDateMonths[digit - 1]} DD, YYYY',
      );
      expect(selectedText(), 'DD');
    }
    for (final pair in {'0': 'Oct', '1': 'Nov', '2': 'Dec'}.entries) {
      replace('1');
      expect(type(pair.key).text, '${pair.value} DD, YYYY');
      expect(selectedText(), 'DD');
    }
  });

  test('invalid month pairs use the latest digit and padded months work', () {
    expect(replace('3').text, 'Mar DD, YYYY');
    expect(type('9').text, 'Sep DD, YYYY');
    expect(selectedText(), 'DD');
    expect(type('0').text, 'Sep 0D, YYYY');
    expect(type('5').text, 'Sep 05, YYYY');
    expect(replace('0').text, 'MMMM DD, YYYY');
    expect(selectedText(), 'MMMM');
    expect(type('4').text, 'Apr DD, YYYY');
    expect(type('1').text, 'Apr 1D, YYYY');
    expect(type('5').text, 'Apr 15, YYYY');
    expect(selectedText(), 'YYYY');
  });

  test('tapping DD commits a one-digit month and begins day entry', () {
    replace('4');
    controller.selectSegmentAtCursor();
    expect(selectedText(), 'DD');
    expect(type('1').text, 'Apr 1D, YYYY');
    expect(type('5').text, 'Apr 15, YYYY');
    expect(selectedText(), 'YYYY');
    for (final digit in '2027'.split('')) {
      type(digit);
    }
    expect(controller.apiExpiryDate, '2027-04-15');
  });

  test('a separator can also commit a one-digit month', () {
    replace('4');
    expect(type('/').text, 'Apr DD, YYYY');
    expect(type('5').text, 'Apr 05, YYYY');
    expect(selectedText(), 'YYYY');
  });

  test(
    'days over 31 are rejected without moving selection or losing input',
    () {
      replace('12');
      expect(type('3').text, 'Dec 3D, YYYY');
      final before = controller.textController.value;
      expect(type('2'), before);
      expect(type('1').text, 'Dec 31, YYYY');
      expect(selectedText(), 'YYYY');
      for (final digit in '2027'.split('')) {
        type(digit);
      }
      expect(controller.apiExpiryDate, '2027-12-31');
      for (final input in ['Dec 99', '12/32/2027', '2027-12-32', '12322027']) {
        expect(replace(input).text, 'Dec 31, 2027');
      }
      controller.textController.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 6,
      );
      controller.selectSegmentAtCursor();
      expect(type('310').text, 'Dec 31, 2027');
    },
  );

  test('editing selected segments preserves the other date values', () {
    controller.selectDate(DateTime(2027, 3, 5));
    controller.textController.selection = const TextSelection.collapsed(
      offset: 1,
    );
    controller.selectSegmentAtCursor();
    expect(selectedText(), 'Mar');
    expect(type('1').text, 'Jan 05, 2027');
    expect(selectedText(), '05');
    expect(type('2').text, 'Dec 05, 2027');
    expect(type('3').text, 'Dec 3D, 2027');
    expect(type('1').text, 'Dec 31, 2027');
    expect(selectedText(), '2027');
    for (final digit in '2028'.split('')) {
      type(digit);
    }
    expect(controller.apiExpiryDate, '2028-12-31');
  });

  test('backspace preserves separators and restores placeholders', () {
    controller.selectDate(DateTime(2027, 4, 5));
    final old = controller.textController.value;
    final value = controller.formatEditUpdate(
      old,
      const TextEditingValue(
        text: 'Apr 05, 202',
        selection: TextSelection.collapsed(offset: 11),
      ),
    );
    controller.textController.value = value;
    expect(value.text, 'Apr 05, 202Y');
    expect(selectedText(), 'Y');
    expect(type('8').text, 'Apr 05, 2028');
    controller.textController.selection = const TextSelection(
      baseOffset: 4,
      extentOffset: 6,
    );
    controller.selectSegmentAtCursor();
    expect(type('').text, 'Apr DD, 2028');
    expect(selectedText(), 'DD');
    expect(type('0').text, 'Apr 0D, 2028');
    expect(type('7').text, 'Apr 07, 2028');
    expect(controller.apiExpiryDate, '2028-04-07');
    expect(replace('').text, '');
    expect(controller.validate(), isFalse);
    expect(controller.errorText, AppStrings.expiryDateRequired);
  });

  test('pasted numeric and named dates retain the display and API formats', () {
    for (final input in [
      '4/5/2027',
      '04-05-2027',
      '04052027',
      '2027-04-05',
      'April 5, 2027',
      'apr 05, 2027',
    ]) {
      expect(replace(input).text, 'Apr 05, 2027', reason: input);
      expect(controller.apiExpiryDate, '2027-04-05');
    }
  });

  test('requires a real complete date and handles leap years', () {
    for (final input in [
      '13/5/2027',
      '04/31/2027',
      '02/29/2027',
      '04/0/2027',
      '4/5/27',
    ]) {
      replace(input);
      expect(controller.validate(), isFalse, reason: input);
      expect(controller.errorText, AppStrings.expiryDateInvalid);
      expect(controller.apiExpiryDate, isNull);
    }
    replace('2/29/2028');
    expect(controller.validate(), isTrue);
    expect(controller.apiExpiryDate, '2028-02-29');
    replace('4');
    expect(controller.validate(), isFalse);
    expect(controller.apiExpiryDate, isNull);
  });

  test(
    'rejects yesterday while allowing today and future calendar selections',
    () {
      replace('10/11/2026');
      expect(controller.errorText, AppStrings.expiryDateInPast);
      expect(controller.validate(), isFalse);
      expect(controller.apiExpiryDate, isNull);
      controller.selectDate(DateTime(2026, 10, 11));
      expect(controller.apiExpiryDate, isNull);
      controller.selectDate(DateTime(2026, 10, 12));
      expect(controller.validate(), isTrue);
      expect(controller.textController.text, 'Oct 12, 2026');
      expect(controller.apiExpiryDate, '2026-10-12');
      controller.selectDate(DateTime(2027, 4, 5));
      expect(controller.apiExpiryDate, '2027-04-05');
    },
  );
}
