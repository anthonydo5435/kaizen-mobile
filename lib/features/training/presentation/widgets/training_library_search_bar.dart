import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_listing_search_bar.dart';
import '../controllers/training_library_controller.dart';

class TrainingLibrarySearchBar extends StatefulWidget {
  const TrainingLibrarySearchBar({
    super.key,
    required this.controller,
    required this.onSelectSeat,
  });

  final TrainingLibraryController controller;
  final VoidCallback? onSelectSeat;

  @override
  State<TrainingLibrarySearchBar> createState() =>
      _TrainingLibrarySearchBarState();
}

class _TrainingLibrarySearchBarState extends State<TrainingLibrarySearchBar> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.searchQuery);
  }

  @override
  void didUpdateWidget(covariant TrainingLibrarySearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQuery = widget.controller.searchQuery;
    if (_textController.text == nextQuery) {
      return;
    }

    _textController.value = TextEditingValue(
      text: nextQuery,
      selection: TextSelection.collapsed(offset: nextQuery.length),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppListingSearchBar(
      controller: _textController,
      onChanged: widget.controller.updateSearchQuery,
      hintText: AppStrings.trainingLibrarySearchLesson,
      onClearTap: widget.controller.clearSearch,
      onFilterTap: widget.onSelectSeat,
      filterTooltip: AppStrings.trainingSetupSelectSeat,
    );
  }
}
