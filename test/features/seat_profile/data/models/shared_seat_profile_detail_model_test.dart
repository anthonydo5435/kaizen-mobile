import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/seat_profile/data/models/seat_profile_detail_model.dart';

void main() {
  test('maps shared seat profile categories and descriptions', () {
    final detail = SeatProfileDetailModel.fromSharedContentJson({
      'view_type': 'seat_profile',
      'content': {
        'title': 'Admin Controller',
        'department_name': 'Engineering Departments',
        'categories': [
          {
            'title': 'Financial Management',
            'weight_percent': 30.0,
            'descriptions': [
              {
                'description': 'Controls Financial Records',
                'job_specifics': 'Verify transactions',
                'milestone_day': '30',
                'check_in_type': 'administrative',
              },
            ],
          },
        ],
      },
    });

    expect(detail.title, 'Admin Controller');
    expect(detail.department?.name, 'Engineering Departments');
    expect(detail.categories.single.id, 'shared-category-0');
    expect(detail.categories.single.weightPercent, 30);
    final description = detail.categories.single.descriptions.single;
    expect(description.name, 'Controls Financial Records');
    expect(description.auditSpecifics, 'Verify transactions');
    expect(description.milestoneDays, '30');
    expect(description.auditFactorType, 'administrative');
  });

  test('rejects a different shared content type', () {
    expect(
      () => SeatProfileDetailModel.fromSharedContentJson({
        'view_type': 'lms',
        'content': <String, dynamic>{},
      }),
      throwsFormatException,
    );
  });
}
