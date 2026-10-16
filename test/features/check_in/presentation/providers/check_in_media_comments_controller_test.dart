import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/audit_description_audit.dart';
import 'package:sparrowkaizen/features/check_in/domain/entities/description_comments_response.dart';
import 'package:sparrowkaizen/features/check_in/domain/repositories/audit_repository.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_media_comments_controller.dart';
import 'package:sparrowkaizen/features/check_in/presentation/providers/check_in_media_upload_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late _Uploads uploads;
  late CheckInMediaCommentsController controller;
  late int mediaChanges;

  setUp(() {
    repository = _Repository();
    uploads = _Uploads();
    mediaChanges = 0;
    controller = CheckInMediaCommentsController(
      selectedMedia: const AuditDescriptionMedia(
        uuid: 'media',
        media: '',
        type: '',
        comment: null,
        unreadCount: 0,
      ),
      onMediaChanged: () async => mediaChanges += 1,
      canReply: true,
      canDelete: true,
      repository: repository,
      uploadController: uploads,
    );
  });
  tearDown(() {
    controller.dispose();
    uploads.dispose();
  });

  test('sending a comment appends it and clears the draft', () async {
    await controller.loadComments();
    controller.messageController.text = '  New observation  ';
    expect(await controller.sendComment(), isTrue);
    expect(repository.sent.single, (comment: 'New observation', parent: null));
    expect(controller.state.comments.map((comment) => comment.comment), [
      'Parent',
      'New observation',
    ]);
    expect(controller.messageController.text, isEmpty);
    expect(controller.state.isSendingComment, isFalse);
  });

  test('a reply uses its parent ID and reloads the thread', () async {
    await controller.loadComments();
    controller.startReply(controller.state.comments.single);
    expect(controller.replyingLabel, 'Replying to Author');
    repository.response = _response([
      _comment(
        replies: [_comment(id: 'reply', text: 'Reply')],
      ),
    ]);
    controller.messageController.text = 'Reply';
    expect(await controller.sendComment(), isTrue);
    expect(repository.sent.single.parent, 'parent');
    expect(controller.state.comments.single.replies.single.uuid, 'reply');
    expect(controller.state.isReplying, isFalse);
    expect(controller.state.replyingTo, isNull);
  });

  test('a failed send retains the draft and reply target for retry', () async {
    controller.startReply(_comment());
    repository.failSend = true;
    controller.messageController.text = 'Keep this draft';
    expect(await controller.sendComment(), isFalse);
    expect(controller.messageController.text, 'Keep this draft');
    expect(controller.state.replyingTo?.uuid, 'parent');
    expect(controller.state.isSendingComment, isFalse);
  });

  test(
    'duplicate sends are blocked while the first request is pending',
    () async {
      final pending = Completer<CommentAdditionResponse>();
      repository.sendResponse = pending.future;
      controller.messageController.text = 'One comment';
      final first = controller.sendComment();
      expect(await controller.sendComment(), isFalse);
      expect(repository.sent, hasLength(1));
      pending.complete(_added('One comment'));
      expect(await first, isTrue);
    },
  );

  test(
    'a stale comments response cannot overwrite a successful send',
    () async {
      final pending = Completer<DescriptionCommentsResponse>();
      repository.loadResponse = pending.future;
      final loading = controller.loadComments();
      controller.messageController.text = 'New comment';
      await controller.sendComment();
      pending.complete(_response([]));
      await loading;
      expect(controller.state.comments.single.comment, 'New comment');
      expect(controller.state.isLoadingComments, isFalse);
    },
  );

  test('the latest load wins when responses complete out of order', () async {
    final oldResponse = Completer<DescriptionCommentsResponse>();
    repository.loadResponse = oldResponse.future;
    final oldLoad = controller.loadComments();
    repository.loadResponse = Future.value(
      _response([_comment(text: 'Current')]),
    );
    await controller.loadComments();
    oldResponse.complete(_response([_comment(text: 'Stale')]));
    await oldLoad;
    expect(controller.state.comments.single.comment, 'Current');
  });

  test(
    'load failures expose the existing error and a retry clears it',
    () async {
      repository.failLoad = true;
      await controller.loadComments();
      expect(controller.state.commentsError, AppStrings.unableToLoadComments);
      expect(controller.state.isLoadingComments, isFalse);
      repository.failLoad = false;
      await controller.loadComments();
      expect(controller.state.commentsError, isNull);
      expect(controller.state.comments, hasLength(1));
    },
  );

  test(
    'deletion refreshes the parent only after the repository succeeds',
    () async {
      repository.failDelete = true;
      expect(await controller.deleteMedia(), isFalse);
      expect(controller.state.isDeleting, isFalse);
      expect(mediaChanges, 0);
      repository.failDelete = false;
      expect(await controller.deleteMedia(), isTrue);
      expect(repository.deletions, 2);
      expect(mediaChanges, 1);
    },
  );

  test(
    'read-only and action permissions block their corresponding writes',
    () async {
      controller.updateConfiguration(
        isReadOnly: true,
        canReply: false,
        canDelete: false,
        onMediaChanged: () async => mediaChanges += 1,
      );
      controller.messageController.text = 'Blocked';
      controller.startReply(_comment());
      expect(await controller.sendComment(), isFalse);
      expect(await controller.deleteMedia(), isFalse);
      await controller.uploadMediaFile(_MediaFile('image.jpg'));
      expect(controller.state.isReplying, isFalse);
      expect(repository.sent, isEmpty);
      expect(repository.deletions, 0);
      expect(repository.uploads, isEmpty);
      expect(uploads.started, 0);
    },
  );

  test(
    'image upload attaches the public URL and updates the selected preview',
    () async {
      await controller.uploadMediaFile(_MediaFile('image.jpg'));
      expect(repository.uploads, ['image.jpg']);
      expect(repository.attachments.single, (
        url: 'https://media.example/image.jpg',
        type: 'image',
      ));
      expect(controller.state.mediaUrl, 'https://media.example/image.jpg');
      expect(controller.state.mediaType, 'image');
      expect(controller.hasSelectedMedia, isTrue);
      expect(controller.state.isUploadingMedia, isFalse);
      expect(mediaChanges, 1);
    },
  );

  test('file size and extension validation stop invalid uploads', () async {
    await controller.uploadMediaFile(
      _MediaFile('image.jpg', size: 80 * 1024 * 1024 + 1),
    );
    expect(
      controller.takeFeedback()?.message,
      AppStrings.auditMediaMaxFileSizeError,
    );
    await controller.uploadMediaFile(_MediaFile('document.pdf'));
    expect(
      controller.takeFeedback()?.message,
      AppStrings.auditMediaUnsupportedFormat,
    );
    expect(repository.uploads, isEmpty);
    expect(uploads.started, 0);
  });

  test(
    'image upload failure clears loading and requests the existing error dialog',
    () async {
      repository.failUpload = true;
      await controller.uploadMediaFile(_MediaFile('image.png'));
      expect(controller.state.isUploadingMedia, isFalse);
      final feedback = controller.takeFeedback();
      expect(feedback?.showAlert, isTrue);
      expect(feedback?.message, AppStrings.auditMediaUploadErrorMessage);
      expect(mediaChanges, 0);
    },
  );

  test(
    'videos use background upload and only matching terminal events refresh the media',
    () async {
      await controller.uploadMediaFile(_MediaFile('clip.mp4'));
      expect(uploads.started, 1);
      expect(repository.uploads, isEmpty);
      expect(controller.state.isUploadingMedia, isTrue);
      uploads.finish('other-media');
      await Future<void>.delayed(Duration.zero);
      expect(mediaChanges, 0);
      repository.response = _response(
        [],
        media: 'https://media.example/clip.mp4',
        type: 'video',
      );
      uploads.finish('media');
      await Future<void>.delayed(Duration.zero);
      expect(mediaChanges, 1);
      expect(controller.state.mediaUrl, 'https://media.example/clip.mp4');
      expect(controller.state.isUploadingMedia, isFalse);
      uploads.emit();
      await Future<void>.delayed(Duration.zero);
      expect(mediaChanges, 1);
    },
  );

  test('failed background enqueue restores the upload action', () async {
    uploads.startSucceeds = false;
    await controller.uploadMediaFile(_MediaFile('clip.mov'));
    expect(controller.state.isUploadingMedia, isFalse);
    expect(controller.canUploadMedia, isTrue);
    expect(
      controller.takeFeedback()?.message,
      AppStrings.auditMediaUploadFailed,
    );
  });

  test(
    'disposed controllers detach upload listeners and ignore late loads',
    () async {
      final other = CheckInMediaCommentsController(
        selectedMedia: const AuditDescriptionMedia(
          uuid: 'other',
          media: '',
          type: '',
          comment: null,
          unreadCount: 0,
        ),
        onMediaChanged: () async {},
        repository: repository,
        uploadController: uploads,
      );
      var notifications = 0;
      other.addListener(() => notifications += 1);
      final pending = Completer<DescriptionCommentsResponse>();
      repository.loadResponse = pending.future;
      final load = other.loadComments();
      other.dispose();
      pending.complete(_response([_comment()]));
      await load;
      expect(notifications, 0);
      expect(other.state.comments, isEmpty);
    },
  );
}

DescriptionComment _comment({
  String id = 'parent',
  String text = 'Parent',
  List<DescriptionComment> replies = const [],
}) => DescriptionComment(
  uuid: id,
  comment: text,
  createdAt: '',
  parent: null,
  author: const DescriptionCommentAuthor(
    uuid: 'author',
    name: 'Author',
    email: '',
    image: null,
    onboarded: true,
  ),
  replies: replies,
  isRead: true,
);

CommentAdditionResponse _added(String text) => CommentAdditionResponse(
  uuid: 'added',
  comment: text,
  createdAt: '',
  parent: null,
  author: null,
);

DescriptionCommentsResponse _response(
  List<DescriptionComment> comments, {
  String media = '',
  String type = '',
}) => DescriptionCommentsResponse(
  uuid: 'media',
  media: media,
  type: type,
  comments: comments,
  totalComments: comments.length,
);

class _Repository extends Fake implements AuditRepository {
  DescriptionCommentsResponse response = _response([_comment()]);
  Future<DescriptionCommentsResponse>? loadResponse;
  Future<CommentAdditionResponse>? sendResponse;
  final sent = <({String comment, String? parent})>[];
  final uploads = <String>[];
  final attachments = <({String url, String type})>[];
  var deletions = 0;
  var failLoad = false;
  var failSend = false;
  var failDelete = false;
  var failUpload = false;

  @override
  Future<DescriptionCommentsResponse> getDescriptionComments({
    required String auditMediaId,
  }) async {
    if (failLoad) throw StateError('Load failed');
    return loadResponse ?? response;
  }

  @override
  Future<CommentAdditionResponse> addComment({
    required String auditMediaId,
    required String comment,
    String? parent,
  }) async {
    sent.add((comment: comment, parent: parent));
    if (failSend) throw StateError('Send failed');
    return sendResponse ?? _added(comment);
  }

  @override
  Future<void> deleteAuditMedia({required String auditMediaId}) async {
    deletions += 1;
    if (failDelete) throw StateError('Delete failed');
  }

  @override
  Future<String> generateAuditDescriptionMediaUploadUrl({
    required String fileName,
  }) async => 'https://media.example/image.jpg?signature=private';
  @override
  Future<void> uploadAuditDescriptionMediaFile({
    required String uploadUrl,
    required String fileName,
    required List<int> fileBytes,
    required String contentType,
  }) async {
    if (failUpload) throw StateError('Upload failed');
    uploads.add(fileName);
  }

  @override
  Future<void> updateAuditMedia({
    required String auditMediaId,
    required String mediaUrl,
    required String mediaType,
  }) async {
    attachments.add((url: mediaUrl, type: mediaType));
  }
}

class _MediaFile extends Fake implements File {
  _MediaFile(this.path, {this.size = 3});
  @override
  final String path;
  final int size;
  @override
  Future<int> length() async => size;
  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList([1, 2, 3]);
}

class _Uploads extends ChangeNotifier implements CheckInMediaUploadController {
  var started = 0;
  var active = false;
  var startSucceeds = true;
  final tasks = <CheckInMediaUploadTask>[];
  @override
  int get latestTerminalEventSequence => tasks.length;
  @override
  String? get startErrorMessage => null;
  @override
  bool isUploadActiveForAuditMedia(String auditMediaId) => active;
  @override
  List<CheckInMediaUploadTask> terminalTasksSince(int eventSequence) => tasks
      .where((task) => task.terminalEventSequence > eventSequence)
      .toList();
  @override
  Future<bool> startUploadForAuditMediaAttachment({
    required String auditMediaId,
    required File sourceFile,
    required String mediaType,
  }) async {
    started += 1;
    active = startSucceeds;
    return startSucceeds;
  }

  void finish(String id) {
    active = false;
    tasks.add(_Task(id, tasks.length + 1));
    notifyListeners();
  }

  void emit() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Task extends Fake implements CheckInMediaUploadTask {
  _Task(this.auditMediaId, this.terminalEventSequence);
  @override
  final String auditMediaId;
  @override
  final int terminalEventSequence;
  @override
  CheckInMediaUploadFlow get flow => CheckInMediaUploadFlow.mediaAttachment;
  @override
  bool get isCompleted => true;
  @override
  CheckInMediaUploadResult? get resultPayload => const CheckInMediaUploadResult(
    mediaUrl: 'https://media.example/clip.mp4',
    mediaType: 'video',
  );
}
