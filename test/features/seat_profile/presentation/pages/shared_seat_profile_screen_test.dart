import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/features/seat_profile/data/models/seat_profile_detail_model.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_detail.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/shared_seat_profile_screen.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  testWidgets(
    'shared seat profile renders read-only details on narrow phones',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final useCase = _SharedSeatUseCase(
        SeatProfileDetailModel.fromSharedContentJson({
          'view_type': 'seat_profile',
          'content': {
            'title': 'Admin Controller With A Very Long Seat Profile Name',
            'department_name': 'Engineering Departments',
            'categories': [
              {
                'title': 'Financial Management',
                'weight_percent': 30.0,
                'descriptions': [
                  {
                    'description': 'Controls Financial Records',
                    'job_specifics': 'Verify all transactions accurately',
                    'milestone_day': '30',
                    'check_in_type': 'administrative',
                  },
                ],
              },
            ],
          },
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: SharedSeatProfileScreen(
            publicId: 'shared-id',
            getSeatProfilesUseCase: useCase,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(useCase.requestedId, 'shared-id');
      expect(find.text('Financial Management'), findsOneWidget);
      expect(find.text('Engineering Departments'), findsOneWidget);
      expect(find.text(AppStrings.seatProfileGenerateAction), findsNothing);
      await tester.tap(find.text('Financial Management'));
      await tester.pumpAndSettle();
      expect(find.text('Controls Financial Records'), findsOneWidget);
      await tester.tap(find.text('Controls Financial Records'));
      await tester.pumpAndSettle();
      expect(find.text('Verify all transactions accurately'), findsOneWidget);
      expect(
        find.text(AppStrings.seatProfileAddSeatDescriptionAction),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _SharedSeatUseCase extends Fake implements GetSeatProfilesUseCase {
  _SharedSeatUseCase(this.detail);

  final SeatProfileDetail detail;
  String? requestedId;

  @override
  Future<SeatProfileDetail> getSharedSeatProfileDetail(String publicId) async {
    requestedId = publicId;
    return detail;
  }
}
