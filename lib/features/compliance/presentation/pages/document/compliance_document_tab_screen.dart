import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/widgets/fast_circular_progress.dart';

import '../../../../../core/constants/app_strings.dart';
import '../../providers/compliance_document_controller.dart';
import '../../widgets/compliance_empty_state.dart';
import '../../widgets/compliance_search_bar.dart';
import '../../widgets/document_card.dart';
import '../compliance_learning_track_filter_sheet.dart';

class ComplianceDocumentTabScreen extends StatefulWidget {
  const ComplianceDocumentTabScreen({super.key});

  @override
  State<ComplianceDocumentTabScreen> createState() => _ComplianceDocumentTabScreenState();
}

class _ComplianceDocumentTabScreenState extends State<ComplianceDocumentTabScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<ComplianceDocumentController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ComplianceDocumentController>();
    final documents = controller.filteredDocuments;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: ComplianceSearchBar(
              controller: controller.searchController,
              onChanged: controller.updateSearchQuery,
              onClearTap: controller.clearSearch,
              showClearButton: true,
              onFilterTap: () => _showFilterSheet(context, controller),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (controller.isLoading || controller.isSearchLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: FastCircularProgressIndicator()),
            )
          else if (controller.searchError != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ComplianceEmptyState(message: controller.searchError!),
            )
          else if (documents.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ComplianceEmptyState(message: AppStrings.complianceNoDocumentsFound),
            )
          else
            SliverList.separated(
              itemCount: documents.length,
              itemBuilder: (context, index) {
                return DocumentCard(document: documents[index]);
              },
              separatorBuilder: (_, __) => const SizedBox(height: 16),
            ),
        ],
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    ComplianceDocumentController controller,
  ) async {
    final selectedSeatProfiles = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComplianceLearningTrackFilterSheet(
        seatProfiles: controller.seatProfiles,
        selectedSeatProfiles: controller.selectedSeatProfiles,
      ),
    );
    if (selectedSeatProfiles == null) {
      return;
    }

    controller.updateSelectedSeatProfiles(selectedSeatProfiles);
  }
}
