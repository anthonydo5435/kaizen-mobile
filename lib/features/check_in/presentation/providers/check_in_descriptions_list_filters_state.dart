class CheckInDescriptionsListFiltersState {
  const CheckInDescriptionsListFiltersState({
    this.isFilterOptionsVisible = false,
    this.showAuditedOnly = false,
    this.selectedCategories = const <String>{},
    this.selectedMilestones = const <String>{},
    this.selectedAuditTimings = const <String>{},
    this.selectedAuditTypes = const <String>{},
  });

  final bool isFilterOptionsVisible;
  final bool showAuditedOnly;
  final Set<String> selectedCategories;
  final Set<String> selectedMilestones;
  final Set<String> selectedAuditTimings;
  final Set<String> selectedAuditTypes;

  bool get hasActiveFilters =>
      showAuditedOnly ||
      selectedCategories.isNotEmpty ||
      selectedMilestones.isNotEmpty ||
      selectedAuditTimings.isNotEmpty ||
      selectedAuditTypes.isNotEmpty;

  CheckInDescriptionsListFiltersState copyWith({
    bool? isFilterOptionsVisible,
    bool? showAuditedOnly,
    Set<String>? selectedCategories,
    Set<String>? selectedMilestones,
    Set<String>? selectedAuditTimings,
    Set<String>? selectedAuditTypes,
  }) {
    return CheckInDescriptionsListFiltersState(
      isFilterOptionsVisible:
          isFilterOptionsVisible ?? this.isFilterOptionsVisible,
      showAuditedOnly: showAuditedOnly ?? this.showAuditedOnly,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedMilestones: selectedMilestones ?? this.selectedMilestones,
      selectedAuditTimings: selectedAuditTimings ?? this.selectedAuditTimings,
      selectedAuditTypes: selectedAuditTypes ?? this.selectedAuditTypes,
    );
  }

  CheckInDescriptionsListFiltersState toggleCategory(String value) {
    return copyWith(
      selectedCategories: _toggleSetValue(selectedCategories, value),
    );
  }

  CheckInDescriptionsListFiltersState toggleMilestone(String value) {
    return copyWith(
      selectedMilestones: _toggleSetValue(selectedMilestones, value),
    );
  }

  CheckInDescriptionsListFiltersState toggleAuditTiming(String value) {
    return copyWith(
      selectedAuditTimings: _toggleSetValue(selectedAuditTimings, value),
    );
  }

  CheckInDescriptionsListFiltersState toggleAuditType(String value) {
    return copyWith(
      selectedAuditTypes: _toggleSetValue(selectedAuditTypes, value),
    );
  }

  static Set<String> _toggleSetValue(Set<String> values, String value) {
    final updatedValues = Set<String>.from(values);
    if (updatedValues.contains(value)) {
      updatedValues.remove(value);
    } else {
      updatedValues.add(value);
    }
    return updatedValues;
  }
}
