import '../entities/audit_description_audit.dart';
import '../repositories/audit_repository.dart';

class SubmitDescriptionAuditUseCase {
  SubmitDescriptionAuditUseCase(this._repository, {this.beforeSubmit});

  final AuditRepository _repository;
  final void Function()? beforeSubmit;
  final Map<String, Future<void>> _pendingSubmissions = {};

  Future<AuditDescriptionAudit> call({
    required String descriptionId,
    required Map<String, int> audit,
  }) {
    final counts = Map<String, int>.unmodifiable(audit);
    return _enqueue(descriptionId, () {
      return _repository.submitDescriptionAudit(
        descriptionId: descriptionId,
        audit: counts,
      );
    });
  }

  Future<void> assign({
    required String descriptionId,
    required List<String> profileJobIds,
  }) {
    final ids = List<String>.unmodifiable(profileJobIds);
    return _enqueue(
      descriptionId,
      () => _repository.assignDescriptionAudit(
        descriptionId: descriptionId,
        profileJobIds: ids,
      ),
    );
  }

  Future<T> _enqueue<T>(String descriptionId, Future<T> Function() action) {
    final previous = _pendingSubmissions[descriptionId] ?? Future<void>.value();
    final submission = previous.then((_) {
      beforeSubmit?.call();
      return action();
    });

    // Keep writes to one description ordered, even if an earlier write fails.
    final completion = submission.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    _pendingSubmissions[descriptionId] = completion;
    return submission.whenComplete(() {
      if (identical(_pendingSubmissions[descriptionId], completion)) {
        _pendingSubmissions.remove(descriptionId);
      }
    });
  }
}
