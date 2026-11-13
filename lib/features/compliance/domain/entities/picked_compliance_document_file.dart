class PickedComplianceDocumentFile {
  const PickedComplianceDocumentFile({required this.path, required this.name});

  final String path;
  final String name;

  static final RegExp _generatedNameSuffix = RegExp(
    r'[-_ ]+[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Keeps the original name and extension without a picker-added UUID suffix.
  /// The file's local path remains unchanged for reading its contents.
  String get displayName {
    final pickedName = _baseName(name);
    final fileName = pickedName.isEmpty ? _baseName(path) : pickedName;
    final extensionIndex = fileName.lastIndexOf('.');
    final stem = extensionIndex > 0
        ? fileName.substring(0, extensionIndex)
        : fileName;
    final extension = extensionIndex > 0
        ? fileName.substring(extensionIndex)
        : '';
    final cleanStem = stem.replaceFirst(_generatedNameSuffix, '').trimRight();
    return cleanStem.isEmpty ? fileName : '$cleanStem$extension';
  }

  static String _baseName(String value) =>
      value.replaceAll('\\', '/').split('/').last.trim();
}
