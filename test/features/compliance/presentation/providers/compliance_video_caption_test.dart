// ignore_for_file: depend_on_referenced_packages

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/compliance/presentation/providers/compliance_video_controller.dart';

void main() {
  test('paces whole words over the cue while retaining spacing and breaks', () {
    final controller = ComplianceVideoController(
      '[00:00 --> 00:04] Hello,  🌍!\nNext line',
    );
    addTearDown(controller.dispose);
    controller.updatePlaybackPosition(Duration.zero);
    expect(controller.activeTranscriptText, 'Hello,');
    expect(controller.activeTranscriptLine?.text, 'Hello,  🌍!\nNext line');

    controller.updatePlaybackPosition(const Duration(milliseconds: 999));
    expect(controller.activeTranscriptText, 'Hello,');
    controller.updatePlaybackPosition(const Duration(seconds: 1));
    expect(controller.activeTranscriptText, 'Hello,  🌍!');
    controller.updatePlaybackPosition(const Duration(seconds: 2));
    expect(controller.activeTranscriptText, 'Hello,  🌍!\nNext');
    controller.updatePlaybackPosition(const Duration(seconds: 3));
    expect(controller.activeTranscriptText, 'Hello,  🌍!\nNext line');
  });

  test('pausing playback stops writing even as wall time advances', () {
    fakeAsync((clock) {
      final controller = ComplianceVideoController(
        '[00:00 --> 00:03] One two three',
      );
      controller.updatePlaybackPosition(Duration.zero);
      clock.elapse(const Duration(seconds: 5));
      expect(controller.activeTranscriptText, 'One');
      controller.updatePlaybackPosition(const Duration(seconds: 1));
      expect(controller.activeTranscriptText, 'One two');
      clock.elapse(const Duration(seconds: 5));
      expect(controller.activeTranscriptText, 'One two');
      controller.updatePlaybackPosition(const Duration(seconds: 2));
      expect(controller.activeTranscriptText, 'One two three');
      controller.dispose();
    });
  });

  test('new cues replace words and timing gaps clear the caption', () {
    final controller = ComplianceVideoController(
      '[00:00 --> 00:04] First second third\n'
      '[00:05 --> 00:06] Next caption',
    );
    addTearDown(controller.dispose);
    controller.updatePlaybackPosition(const Duration(seconds: 2));
    expect(controller.activeTranscriptText, 'First second');
    controller.updatePlaybackPosition(const Duration(seconds: 5));
    expect(controller.activeTranscriptText, 'Next');
    controller.updatePlaybackPosition(const Duration(milliseconds: 5500));
    expect(controller.activeTranscriptText, 'Next caption');
    controller.updatePlaybackPosition(const Duration(seconds: 4));
    expect(controller.activeTranscriptText, isNull);
    expect(controller.hasVisibleActiveTranscript, isFalse);
  });

  test('forward and backward seeks reveal words for the playback position', () {
    final controller = ComplianceVideoController(
      '[00:00 --> 00:04] One two three four',
    );
    addTearDown(controller.dispose);
    controller.updatePlaybackPosition(const Duration(seconds: 2));
    expect(controller.activeTranscriptText, 'One two three');
    controller.updatePlaybackPosition(Duration.zero);
    expect(controller.activeTranscriptText, 'One');
    controller.updatePlaybackPosition(const Duration(seconds: 1));
    expect(controller.activeTranscriptText, 'One two');
    controller.updatePlaybackPosition(const Duration(seconds: 3));
    expect(controller.activeTranscriptText, 'One two three four');
  });

  test('restoring CC uses the current position without restarting the cue', () {
    final controller = ComplianceVideoController(
      '[00:00 --> 00:04] One two three four\n[00:05] Next caption',
    );
    addTearDown(controller.dispose);
    controller.updatePlaybackPosition(Duration.zero);
    controller.toggleCc();
    expect(controller.hasVisibleActiveTranscript, isFalse);
    controller.updatePlaybackPosition(const Duration(seconds: 2));
    controller.toggleCc();
    expect(controller.hasVisibleActiveTranscript, isTrue);
    expect(controller.activeTranscriptText, 'One two three');
    controller.toggleCc();
    controller.updatePlaybackPosition(const Duration(seconds: 5));
    controller.toggleCc();
    expect(controller.activeTranscriptText, 'Next');
  });

  test('disabled animations show the full cue immediately', () {
    final controller = ComplianceVideoController('[00:00] One two three');
    addTearDown(controller.dispose);
    controller.updatePlaybackPosition(Duration.zero);
    controller.updatePlaybackPosition(
      const Duration(milliseconds: 100),
      animate: false,
    );
    expect(controller.activeTranscriptText, 'One two three');
    controller.toggleCc();
    controller.toggleCc();
    expect(controller.activeTranscriptText, 'One two three');
    controller.updatePlaybackPosition(Duration.zero);
    expect(controller.activeTranscriptText, 'One');
  });

  test(
    'long cues use their full timing and short cues finish before ending',
    () {
      final words = List.generate(40, (index) => 'word$index');
      final controller = ComplianceVideoController(
        '[00:00 --> 00:10] ${words.join(' ')}\n'
        '[00:10.000 --> 00:10.500] One two three four five six',
      );
      addTearDown(controller.dispose);
      controller.updatePlaybackPosition(const Duration(seconds: 3));
      expect(controller.activeTranscriptText, words.take(13).join(' '));
      controller.updatePlaybackPosition(const Duration(milliseconds: 9750));
      expect(controller.activeTranscriptText, words.join(' '));
      controller.updatePlaybackPosition(const Duration(seconds: 10));
      expect(controller.activeTranscriptText, 'One');
      controller.updatePlaybackPosition(const Duration(milliseconds: 10417));
      expect(controller.activeTranscriptText, 'One two three four five six');
      controller.updatePlaybackPosition(const Duration(milliseconds: 10500));
      expect(controller.activeTranscriptText, isNull);
    },
  );

  test('cues without an end reveal one word every 450 ms of playback', () {
    final controller = ComplianceVideoController('[00:05] One two three');
    addTearDown(controller.dispose);
    controller.updatePlaybackPosition(const Duration(seconds: 5));
    expect(controller.activeTranscriptText, 'One');
    controller.updatePlaybackPosition(const Duration(milliseconds: 5449));
    expect(controller.activeTranscriptText, 'One');
    controller.updatePlaybackPosition(const Duration(milliseconds: 5450));
    expect(controller.activeTranscriptText, 'One two');
    controller.updatePlaybackPosition(const Duration(milliseconds: 5900));
    expect(controller.activeTranscriptText, 'One two three');
  });

  test('single-line paging keeps playback progress with reduced motion', () {
    final controller = ComplianceVideoController(
      '[00:00 --> 00:03] One two three',
    );
    addTearDown(controller.dispose);
    controller.updatePlaybackPosition(Duration.zero, animate: false);
    expect(controller.activeTranscriptText, 'One two three');
    expect(controller.activeTranscriptProgressText, 'One');
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.updatePlaybackPosition(
      const Duration(seconds: 1),
      animate: false,
    );
    expect(controller.activeTranscriptProgressText, 'One two');
    expect(controller.activeTranscriptText, 'One two three');
    expect(notifications, 1);
    controller.updatePlaybackPosition(Duration.zero, animate: false);
    expect(controller.activeTranscriptProgressText, 'One');
  });

  test('only notifies when the visible text or active cue changes', () {
    final controller = ComplianceVideoController(
      '[00:00 --> 00:03] One two three',
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.updatePlaybackPosition(Duration.zero);
    controller.updatePlaybackPosition(const Duration(milliseconds: 200));
    controller.updatePlaybackPosition(const Duration(milliseconds: 500));
    expect(notifications, 1);
    controller.updatePlaybackPosition(const Duration(seconds: 1));
    expect(notifications, 2);
  });

  test('disposal ignores subsequent playback updates', () {
    final controller = ComplianceVideoController('[00:00] One two three');
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.updatePlaybackPosition(Duration.zero);
    controller.dispose();
    controller.updatePlaybackPosition(const Duration(seconds: 3));
    expect(notifications, 1);
  });
}
