import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/training/presentation/controllers/training_library_thumbnail_controller.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_library_module_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image image;
  final imageCache = PaintingBinding.instance.imageCache;

  setUp(() async {
    image = await createTestImage();
  });
  tearDown(() {
    image.dispose();
    imageCache.clear();
    imageCache.clearLiveImages();
  });

  testWidgets(
    'preloading limits concurrency, deduplicates and advances after errors',
    (tester) async {
      final pending = <String, _ControlledCompleter>{};
      final cache = TrainingLibraryThumbnailController(
        providerFor: (url) => _ControlledProvider(url, pending),
      );
      addTearDown(cache.dispose);
      final urls = List.generate(8, (index) => 'image-$index');
      cache.preload(urls);
      cache.preload(urls);
      expect(pending.keys, urls.take(4));

      pending['image-0']!.complete(image);
      await tester.pump();
      expect(pending.keys, urls.take(5));
      pending['image-1']!.fail();
      await tester.pump();
      expect(pending.keys, urls.take(6));
      cache.preload(urls);
      expect(pending.keys, urls.take(6));

      cache.dispose();
      pending['image-2']!.complete(image);
      await tester.pump();
      expect(pending.keys, urls.take(6));
      expect(imageCache.statusForKey('image-0').live, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps the first page and recent thumbnails live with a bounded window',
    (tester) async {
      final pending = <String, _ControlledCompleter>{};
      final cache = TrainingLibraryThumbnailController(
        providerFor: (url) => _ControlledProvider(url, pending),
      );
      addTearDown(cache.dispose);
      final urls = List.generate(100, (index) => 'image-$index');
      cache.preload(urls.take(50));
      await _completeAll(tester, pending, image);
      expect(imageCache.statusForKey('image-25').live, isTrue);

      cache.preload(urls);
      await _completeAll(tester, pending, image);
      expect(imageCache.liveImageCount, 75);
      for (final url in urls.take(25).followedBy(urls.skip(50))) {
        expect(imageCache.statusForKey(url).live, isTrue, reason: url);
      }
      expect(imageCache.statusForKey('image-25').live, isFalse);
      cache.preload(['new-filter-image']);
      await _completeAll(tester, pending, image);
      expect(imageCache.liveImageCount, 1);
      cache.dispose();
      expect(imageCache.liveImageCount, 0);
    },
  );

  testWidgets(
    'returning to a card shows its cached image immediately without fading',
    (tester) async {
      const url = 'https://example.com/lesson.jpg';
      final provider = TrainingLibraryThumbnailController.imageProvider(url);
      final key = await provider.obtainKey(ImageConfiguration.empty);
      final completer = _ControlledCompleter()..complete(image);
      imageCache.putIfAbsent(key, () => completer);
      final cache = TrainingLibraryThumbnailController()..preload([url]);
      addTearDown(cache.dispose);

      Widget card() => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 200,
              child: TrainingLibraryModuleCard.shared(
                sharedTitle: 'Lesson',
                sharedThumbnailLink: url,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      void expectLoadedImage() {
        final rawImage = tester.widget<RawImage>(
          find.descendant(
            of: find.byType(TrainingLibraryModuleCard),
            matching: find.byType(RawImage),
          ),
        );
        expect(rawImage.image?.isCloneOf(image), isTrue);
        expect(
          find.descendant(
            of: find.byType(TrainingLibraryModuleCard),
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );
      }

      await tester.pumpWidget(card());
      expectLoadedImage();
      await tester.pumpWidget(const SizedBox());
      imageCache.clear();
      expect(imageCache.statusForKey(key).live, isTrue);
      await tester.pumpWidget(card());
      expectLoadedImage();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _completeAll(
  WidgetTester tester,
  Map<String, _ControlledCompleter> requests,
  ui.Image image,
) async {
  while (requests.values.any((request) => !request.isComplete)) {
    for (final request in requests.values.toList()) {
      if (!request.isComplete) request.complete(image);
    }
    await tester.pump();
  }
}

class _ControlledProvider extends ImageProvider<String> {
  const _ControlledProvider(this.url, this.requests);

  final String url;
  final Map<String, _ControlledCompleter> requests;

  @override
  Future<String> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(url);

  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) =>
      requests[key] = _ControlledCompleter();
}

class _ControlledCompleter extends ImageStreamCompleter {
  bool isComplete = false;

  void complete(ui.Image image) {
    isComplete = true;
    setImage(ImageInfo(image: image.clone()));
  }

  void fail() {
    isComplete = true;
    reportError(exception: Exception('image unavailable'), silent: true);
  }
}
