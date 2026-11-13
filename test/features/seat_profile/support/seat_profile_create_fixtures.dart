import 'package:flutter_test/flutter_test.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/department.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_category_draft.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_creation_result.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/models/seat_profile_form_initial_data.dart';

const createDepartment = Department(id: 'operations', name: 'Operations');
const otherCreateDepartment = Department(id: 'finance', name: 'Finance');
const createCategory = SeatProfileCategoryDraft(
  uuid: 'category-id',
  title: 'Daily Delivery',
  weightPercent: 100,
);
const createResult = SeatProfileCreationResult(
  id: 'created-seat',
  actualId: 'actual-seat',
  descriptionsCount: 0,
  categoriesCount: 1,
  categories: [createCategory],
);
const editFormData = SeatProfileFormInitialData(
  seatId: 'lookup-seat',
  actualId: 'actual-seat',
  name: 'Operator',
  department: createDepartment,
  paygradeUnit: 'hr',
);

class SeatProfileCreateUseCase extends Fake implements GetSeatProfilesUseCase {
  List<Department> departments = [createDepartment, otherCreateDepartment];
  SeatProfileCreationResult result = createResult;
  int departmentLoads = 0;
  Future<List<Department>>? pendingDepartments;
  Future<SeatProfileCreationResult>? pendingCreate;
  Future<void>? pendingGeneration;
  Future<void>? pendingCategorySave;
  Object? generationFailure;
  Object? categoryFailure;
  final creations = <({String title, Department department, String unit})>[];
  final updates =
      <({String id, String title, Department department, String unit})>[];
  final generations = <({String id, String? specificity, String? tone})>[];
  final contentLoads = <String>[];
  final categorySaves =
      <({String id, List<SeatProfileCategoryDraft> categories})>[];

  @override
  Future<List<Department>> getDepartments() async {
    departmentLoads += 1;
    return pendingDepartments ?? departments;
  }

  @override
  Future<SeatProfileCreationResult> createSeatProfile({
    required Department department,
    required String title,
    required String paygradeUnit,
  }) async {
    creations.add((title: title, department: department, unit: paygradeUnit));
    return pendingCreate ?? result;
  }

  @override
  Future<void> updateSeatProfile({
    required String seatId,
    required Department department,
    required String title,
    required String paygradeUnit,
  }) async {
    updates.add((
      id: seatId,
      title: title,
      department: department,
      unit: paygradeUnit,
    ));
  }

  @override
  Future<void> generateSeatProfileJobContent({
    required String actualId,
    String? specificity,
    String? tone,
  }) async {
    generations.add((id: actualId, specificity: specificity, tone: tone));
    if (generationFailure != null) throw generationFailure!;
    await pendingGeneration;
  }

  @override
  Future<SeatProfileCreationResult> getSeatProfileJobContent(
    String actualId,
  ) async {
    contentLoads.add(actualId);
    return result;
  }

  @override
  Future<void> bulkUpsertSeatProfileCategories({
    required String actualId,
    required List<SeatProfileCategoryDraft> categories,
  }) async {
    categorySaves.add((id: actualId, categories: List.of(categories)));
    if (categoryFailure != null) throw categoryFailure!;
    await pendingCategorySave;
  }
}
