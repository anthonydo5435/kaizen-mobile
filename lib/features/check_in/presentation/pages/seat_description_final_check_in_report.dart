import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../../../training/domain/entities/seat_description_training_route.dart';
import '../../../training/presentation/pages/edit_training_screen.dart';
import '../../domain/entities/audit_description_audit.dart';
import '../providers/check_in_controller.dart';
import '../providers/seat_description_final_check_in_report_controller.dart';
import '../widgets/check_in_media_preview.dart';
import 'check_in_media_comments_bottom_sheet.dart';

part '../widgets/seat_description_final_report_cards.dart';
part '../widgets/seat_description_final_report_comments.dart';
part '../widgets/seat_description_final_report_layout.dart';
part '../widgets/seat_description_final_report_trend.dart';
part '../widgets/seat_description_final_report_trend_profiles.dart';

class SeatDescriptionFinalCheckInReportScreen extends StatelessWidget {
  const SeatDescriptionFinalCheckInReportScreen({
    super.key,
    required this.flowFirstId,
    this.profileUuid,
    required this.descriptionId,
    required this.quarter,
    required this.year,
  });

  final String flowFirstId;
  final String? profileUuid;
  final String descriptionId;
  final int quarter;
  final int year;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey((flowFirstId, profileUuid, descriptionId, quarter, year)),
      create: (context) => SeatDescriptionFinalCheckInReportController(
        checkInController: context.read<CheckInController>(),
        flowFirstId: flowFirstId,
        profileUuid: profileUuid,
        descriptionId: descriptionId,
        quarter: quarter,
        year: year,
      ),
      child: const _FinalReportView(),
    );
  }
}

class _FinalReportView extends StatelessWidget {
  const _FinalReportView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SeatDescriptionFinalCheckInReportController>();
    return Scaffold(
      backgroundColor: AppColors.mainBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(8, 4, 8, 0), child: _FinalReportHeader()),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _TimeRangeDropdown(
                value: controller.timeRange,
                items: FinalCheckInReportTimeRange.values,
                onChanged: controller.selectTimeRange,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(child: _FinalReportContent(controller: controller)),
          ],
        ),
      ),
    );
  }
}
