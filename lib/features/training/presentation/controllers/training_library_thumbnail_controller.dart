import 'dart:async';
import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

/// Warms decoded thumbnails and keeps the first page plus recent pages live.
class TrainingLibraryThumbnailController {
  TrainingLibraryThumbnailController({
    ImageProvider<Object> Function(String url)? providerFor,
  }) : _providerFor = providerFor ?? imageProvider;

  static const int _firstPageSize = 25;
  static const int _recentImages = 50;
  static const int _concurrentLoads = 4;

  // A fixed decode size gives preloads and cards the same image-cache key.
  static ImageProvider<Object> imageProvider(String url) => ResizeImage(
    CachedNetworkImageProvider(url),
    width: 720,
    height: 480,
    policy: ResizeImagePolicy.fit,
  );

  final ImageProvider<Object> Function(String url) _providerFor;
  final Map<String, _ThumbnailRequest> _requests = {};
  final Queue<String> _queue = Queue<String>();
  final Set<String> _failed = {};
  Set<String> _wanted = {};
  bool _isDisposed = false;

  void preload(Iterable<String> imageUrls) {
    if (_isDisposed) return;
    final urls = imageUrls.toSet().toList(growable: false);
    _wanted = {
      ...urls.take(_firstPageSize),
      ...urls.skip((urls.length - _recentImages).clamp(0, urls.length)),
    };
    _failed.removeWhere((url) => !_wanted.contains(url));
    _queue.removeWhere((url) => !_wanted.contains(url));
    for (final url in _requests.keys.toList()) {
      // Let outstanding requests finish so filter changes cannot exceed the
      // concurrency limit. Completed images outside the window are released.
      if (!_wanted.contains(url) && !_requests[url]!.isPending) {
        _release(url);
      }
    }
    for (final url in _wanted) {
      if (!_requests.containsKey(url) &&
          !_queue.contains(url) &&
          !_failed.contains(url)) {
        _queue.add(url);
      }
    }
    _startNext();
  }

  void _startNext() {
    if (_isDisposed) return;
    while (_queue.isNotEmpty &&
        _requests.values.where((request) => request.isPending).length <
            _concurrentLoads) {
      final url = _queue.removeFirst();
      final request = _ThumbnailRequest();
      _requests[url] = request;
      request.listener = ImageStreamListener(
        (image, _) {
          image.dispose();
          _complete(url, request);
        },
        onError: (Object error, StackTrace? stackTrace) {
          _failed.add(url);
          _complete(url, request, failed: true);
        },
      );
      try {
        request.stream = _providerFor(url).resolve(ImageConfiguration.empty);
        request.stream!.addListener(request.listener!);
      } catch (_) {
        _failed.add(url);
        _complete(url, request, failed: true);
      }
    }
  }

  void _complete(String url, _ThumbnailRequest request, {bool failed = false}) {
    if (_isDisposed || !identical(_requests[url], request)) return;
    request.isPending = false;
    if (failed || !_wanted.contains(url)) _release(url);
    scheduleMicrotask(_startNext);
  }

  void _release(String url) {
    final request = _requests.remove(url);
    if (request?.listener != null) {
      request?.stream?.removeListener(request.listener!);
    }
  }

  void dispose() {
    _isDisposed = true;
    _queue.clear();
    _wanted.clear();
    _failed.clear();
    for (final url in _requests.keys.toList()) {
      _release(url);
    }
  }
}

class _ThumbnailRequest {
  ImageStream? stream;
  ImageStreamListener? listener;
  bool isPending = true;
}
