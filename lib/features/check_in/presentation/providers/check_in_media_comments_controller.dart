import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../data/datasources/audit_remote_data_source.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../../domain/entities/description_comments_response.dart';
import '../../domain/repositories/audit_repository.dart';
import 'check_in_media_comments_state.dart';
import 'check_in_media_upload_controller.dart';

class CheckInMediaCommentsController extends ChangeNotifier {
  CheckInMediaCommentsController({
    required AuditDescriptionMedia selectedMedia,
    required Future<void> Function() onMediaChanged,
    bool isReadOnly = false,
    bool canReply = false,
    bool canDelete = false,
    AuditRepository? repository,
    ImagePicker? imagePicker,
    CheckInMediaUploadController? uploadController,
  }) : auditMediaId = selectedMedia.uuid,
       _onMediaChanged = onMediaChanged,
       _isReadOnly = isReadOnly,
       _canReply = canReply,
       _canDelete = canDelete,
       _repository = repository ?? AuditRepositoryImpl(AuditRemoteDataSource()),
       _imagePicker = imagePicker ?? ImagePicker(),
       _uploadController =
           uploadController ?? CheckInMediaUploadController.instance,
       _state = CheckInMediaCommentsState(
         mediaUrl: selectedMedia.media,
         mediaType: selectedMedia.type,
       ) {
    _lastHandledUploadEventSequence =
        _uploadController.latestTerminalEventSequence;
    _state = _state.copyWith(
      isUploadingMedia: _uploadController.isUploadActiveForAuditMedia(
        auditMediaId,
      ),
    );
    _uploadController.addListener(_handleUploadChanged);
  }

  static const int _maxUploadBytes = 80 * 1024 * 1024;
  static const Set<String> _allowedImageExtensions = {'jpg', 'jpeg', 'png'};
  static const Set<String> _allowedVideoExtensions = {'mp4', 'mov', 'h264'};

  final String auditMediaId;
  final AuditRepository _repository;
  final ImagePicker _imagePicker;
  final CheckInMediaUploadController _uploadController;
  final TextEditingController messageController = TextEditingController();
  Future<void> Function() _onMediaChanged;
  bool _isReadOnly;
  bool _canReply;
  bool _canDelete;
  bool _isDisposed = false;
  int _commentsRequest = 0;
  int _lastHandledUploadEventSequence = 0;
  CheckInMediaCommentsState _state;
  CheckInMediaCommentsFeedback? _feedback;

  CheckInMediaCommentsState get state => _state;
  bool get canReply => _canReply;
  bool get canDelete => _canDelete;
  bool get isReadOnly => _isReadOnly;
  bool get canUploadMedia =>
      !_isReadOnly && !_state.isUploadingMedia && !_state.isDeleting;
  bool get hasSelectedMedia =>
      const {
        'image',
        'video',
        'screen_recording',
      }.contains(_state.mediaType.trim().toLowerCase()) &&
      _state.mediaUrl.trim().isNotEmpty;
  List<CheckInMediaCommentViewData> get commentItems => _state.comments
      .map(CheckInMediaCommentViewData.new)
      .toList(growable: false);

  String get replyingLabel {
    final name = _state.replyingTo?.author?.name.trim();
    return name != null && name.isNotEmpty
        ? AppStrings.auditMediaReplyingTo(name)
        : AppStrings.auditMediaReplyingToComment;
  }

  void updateConfiguration({
    required bool isReadOnly,
    required bool canReply,
    required bool canDelete,
    required Future<void> Function() onMediaChanged,
  }) {
    _isReadOnly = isReadOnly;
    _canReply = canReply;
    _canDelete = canDelete;
    _onMediaChanged = onMediaChanged;
  }

  void updateMedia(String mediaUrl, String mediaType) {
    _setState(_state.copyWith(mediaUrl: mediaUrl, mediaType: mediaType));
  }

  CheckInMediaCommentsFeedback? takeFeedback() {
    final feedback = _feedback;
    _feedback = null;
    return feedback;
  }

  Future<void> loadComments({bool silently = false}) async {
    final request = ++_commentsRequest;
    try {
      final response = await _repository.getDescriptionComments(
        auditMediaId: auditMediaId,
      );
      if (_isDisposed || request != _commentsRequest) return;
      _setState(
        _state.copyWith(
          comments: List.unmodifiable(response.comments),
          isLoadingComments: false,
          clearCommentsError: true,
          mediaUrl: response.media,
          mediaType: response.type,
        ),
      );
    } catch (_) {
      if (_isDisposed || request != _commentsRequest) return;
      _setState(
        _state.copyWith(
          isLoadingComments: silently ? _state.isLoadingComments : false,
          commentsError: AppStrings.unableToLoadComments,
        ),
      );
    }
  }

  void startReply(DescriptionComment comment) {
    if (!_canReply) return;
    _setState(_state.copyWith(isReplying: true, replyingTo: comment));
  }

  void cancelReply() {
    _setState(_state.copyWith(isReplying: false, clearReplyingTo: true));
  }

  Future<bool> sendComment() async {
    final comment = messageController.text.trim();
    if (_isDisposed ||
        !_canReply ||
        comment.isEmpty ||
        _state.isSendingComment) {
      return false;
    }
    final parent = _state.replyingTo?.uuid;
    _setState(_state.copyWith(isSendingComment: true));
    try {
      final added = await _repository.addComment(
        auditMediaId: auditMediaId,
        comment: comment,
        parent: parent,
      );
      if (_isDisposed) return false;
      // A load started before this write must not replace the new comment.
      _commentsRequest += 1;
      _setState(
        _state.copyWith(
          isSendingComment: false,
          isLoadingComments: false,
          isReplying: false,
          clearReplyingTo: true,
          comments: parent == null
              ? [..._state.comments, added]
              : _state.comments,
        ),
      );
      messageController.clear();
      if (parent != null) await loadComments(silently: true);
      return !_isDisposed;
    } catch (_) {
      _setState(_state.copyWith(isSendingComment: false));
      return false;
    }
  }

  Future<bool> deleteMedia() async {
    if (_isDisposed || !_canDelete || _state.isDeleting) return false;
    _setState(_state.copyWith(isDeleting: true));
    try {
      await _repository.deleteAuditMedia(auditMediaId: auditMediaId);
      await _onMediaChanged();
      return !_isDisposed;
    } catch (error) {
      debugPrint('Unable to delete audit media: $error');
      _setState(_state.copyWith(isDeleting: false));
      return false;
    }
  }

  Future<void> pickAndUploadMedia({required bool pickImage}) async {
    if (_isDisposed || !canUploadMedia) return;
    try {
      final pickedFile = pickImage
          ? await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 90,
            )
          : await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (_isDisposed || pickedFile == null) return;
      await uploadMediaFile(File(pickedFile.path));
    } catch (error) {
      debugPrint('Unable to pick audit media file: $error');
      _showFeedback(AppStrings.auditMediaPickError);
    }
  }

  Future<void> uploadMediaFile(File file) async {
    if (_isDisposed || !canUploadMedia) return;
    final size = await file.length();
    if (_isDisposed || !canUploadMedia) return;
    if (size > _maxUploadBytes) {
      _showFeedback(AppStrings.auditMediaMaxFileSizeError);
      return;
    }
    final extension = CustomFunctions.fileNameFromPath(
      file.path,
    ).split('.').last.trim().toLowerCase();
    final isImage = _allowedImageExtensions.contains(extension);
    if (!isImage && !_allowedVideoExtensions.contains(extension)) {
      _showFeedback(AppStrings.auditMediaUnsupportedFormat);
      return;
    }
    if (isImage) {
      await _uploadImage(file);
    } else {
      await _enqueueVideo(file);
    }
  }

  Future<void> _uploadImage(File file) async {
    _setState(_state.copyWith(isUploadingMedia: true));
    try {
      final fileName = CustomFunctions.fileNameFromPath(file.path);
      final uploadUrl = await _repository
          .generateAuditDescriptionMediaUploadUrl(fileName: fileName);
      await _repository.uploadAuditDescriptionMediaFile(
        uploadUrl: uploadUrl,
        fileName: fileName,
        fileBytes: await file.readAsBytes(),
        contentType: CustomFunctions.contentTypeFromPath(file.path),
      );
      final separator = uploadUrl.indexOf('?');
      final mediaUrl = separator == -1
          ? uploadUrl
          : uploadUrl.substring(0, separator);
      await _repository.updateAuditMedia(
        auditMediaId: auditMediaId,
        mediaUrl: mediaUrl,
        mediaType: 'image',
      );
      updateMedia(mediaUrl, 'image');
      await _onMediaChanged();
      _setState(_state.copyWith(isUploadingMedia: false));
    } catch (error) {
      debugPrint('Unable to upload audit media file: $error');
      _setState(_state.copyWith(isUploadingMedia: false));
      _showFeedback(AppStrings.auditMediaUploadErrorMessage, showAlert: true);
    }
  }

  Future<void> _enqueueVideo(File file) async {
    _setState(_state.copyWith(isUploadingMedia: true));
    final didStart = await _uploadController.startUploadForAuditMediaAttachment(
      auditMediaId: auditMediaId,
      sourceFile: file,
      mediaType: 'video',
    );
    if (didStart || _isDisposed) return;
    _setState(_state.copyWith(isUploadingMedia: false));
    final message = _uploadController.startErrorMessage?.trim();
    _showFeedback(
      message != null && message.isNotEmpty
          ? message
          : AppStrings.auditMediaUploadFailed,
    );
  }

  void _handleUploadChanged() => unawaited(_syncUploadState());

  Future<void> _syncUploadState() async {
    if (_isDisposed) return;
    final isUploading = _uploadController.isUploadActiveForAuditMedia(
      auditMediaId,
    );
    if (_state.isUploadingMedia != isUploading) {
      _setState(_state.copyWith(isUploadingMedia: isUploading));
    }
    final terminalTasks = _uploadController.terminalTasksSince(
      _lastHandledUploadEventSequence,
    );
    if (terminalTasks.isEmpty) return;
    _lastHandledUploadEventSequence = terminalTasks.last.terminalEventSequence;
    CheckInMediaUploadResult? completedResult;
    String? failureMessage;
    for (final task in terminalTasks) {
      if (task.flow != CheckInMediaUploadFlow.mediaAttachment ||
          task.auditMediaId != auditMediaId) {
        continue;
      }
      if (task.isCompleted) {
        completedResult ??= task.resultPayload;
      } else if (task.isFailed && failureMessage == null) {
        final message = task.errorMessage?.trim();
        if (message != null && message.isNotEmpty) failureMessage = message;
      }
    }
    if (completedResult != null) {
      updateMedia(completedResult.mediaUrl, completedResult.mediaType);
      try {
        await _onMediaChanged();
        if (!_isDisposed) await loadComments(silently: true);
      } catch (error) {
        debugPrint('Unable to refresh uploaded audit media: $error');
      }
    }
    if (failureMessage != null) _showFeedback(failureMessage);
  }

  void _showFeedback(String message, {bool showAlert = false}) {
    if (_isDisposed) return;
    _feedback = CheckInMediaCommentsFeedback(message, showAlert: showAlert);
    notifyListeners();
  }

  void _setState(CheckInMediaCommentsState state) {
    if (_isDisposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _uploadController.removeListener(_handleUploadChanged);
    messageController.dispose();
    super.dispose();
  }
}
