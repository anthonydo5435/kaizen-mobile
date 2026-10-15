import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sparrowkaizen/core/constants/app_colors.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/widgets/app_overlay_close_button.dart';
import 'package:sparrowkaizen/core/widgets/app_swipe_reveal_action.dart';
import 'package:sparrowkaizen/features/login/domain/entities/user.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/department.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/entities/seat_profile_detail.dart';
import 'package:sparrowkaizen/features/seat_profile/domain/usecases/get_seat_profiles_usecase.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/seat_profile_descriptions_screen.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/seat_profile_detail_screen.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/pages/shared_seat_profile_screen.dart';
import 'package:sparrowkaizen/features/seat_profile/presentation/providers/seat_profile_detail_controller.dart';
import 'package:sparrowkaizen/routes/app_router.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreference.init();
    AppManager.instance.resetSessionState();
    AppManager.instance.updateCurrentUser(
      User(uuid: 'owner', isOwner: true, organizationUuid: 'org'),
    );
  });
  tearDown(AppManager.instance.resetSessionState);

  testWidgets('category cards navigate without inline descriptions', (tester) async {
    await _openScreen(tester);
    final controller = _controller(tester);
    final category = find.byKey(const ValueKey('finance'));
    final categoryBounds = tester.getRect(category);
    expect(find.descendant(of: category, matching: find.byType(RotationTransition)), findsNothing);
    expect(find.text('Controls Financial Records'), findsNothing);
    expect(find.text(AppStrings.seatProfileAddSeatDescriptionAction), findsNothing);
    expect(find.text('30%'), findsOneWidget);

    await _openCategory(tester, 'Financial Management');
    final screen = tester.widget<SeatProfileDescriptionsScreen>(
      find.byType(SeatProfileDescriptionsScreen),
    );
    expect(screen.controller, same(controller));
    final route = ModalRoute.of(tester.element(find.byType(SeatProfileDescriptionsScreen)))!;
    expect(route.settings.name, AppRouter.seatProfileDescriptions);
    expect((route.settings.arguments as SeatProfileDescriptionsRouteArgs).category.id, 'finance');
    expect(find.text('Controls Financial Records'), findsOneWidget);
    expect(find.text('Maintains Account Reports'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.text('Financial Management'), findsNothing);
    expect(find.text(AppStrings.seatProfilePercentageHold), findsNothing);
    final descriptionBounds = tester.getRect(_description('records'));
    expect(descriptionBounds.left, closeTo(categoryBounds.left, 0.01));
    expect(descriptionBounds.right, closeTo(categoryBounds.right, 0.01));
    expect(tester.getRect(_description('reports')).left, closeTo(descriptionBounds.left, 0.01));
    final cardContainer = tester.widget<Container>(
      find.descendant(of: _description('records'), matching: find.byType(Container)).first,
    );
    final decoration = cardContainer.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.surfaceDark);
    expect(decoration.border, isNull);
    expect(
      _withinDescription('records', AppStrings.seatProfileAuditSpecifics).hitTestable(),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(SeatProfileDetailView), findsOneWidget);
    expect(find.text('Controls Financial Records'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('description cards expand independently without chevrons or inline delete icons', (
    tester,
  ) async {
    await _openScreen(tester);
    await _openCategory(tester, 'Financial Management');
    final card = _description('records');
    final title = find.text('Controls Financial Records');
    final titleTop = tester.getTopLeft(title).dy;
    final collapsedHeight = tester.getSize(card).height;
    final specifics = _withinDescription('records', AppStrings.seatProfileAuditSpecifics);
    final edit = _withinDescription('records', AppStrings.seatProfileEditAction);

    await tester.tap(title);
    await tester.pump();
    var previousHeight = collapsedHeight;
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
      final height = tester.getSize(card).height;
      expect(height, greaterThanOrEqualTo(previousHeight));
      expect(tester.getTopLeft(title).dy, closeTo(titleTop, 0.01));
      if (frame < 7) expect(edit.hitTestable(), findsNothing);
      previousHeight = height;
    }
    await tester.pumpAndSettle();
    expect(tester.getSize(card).height, greaterThan(collapsedHeight));
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    expect(find.byType(SvgPicture), findsNothing);
    expect(specifics.hitTestable(), findsOneWidget);
    expect(edit.hitTestable(), findsOneWidget);
    expect(
      _withinDescription('reports', AppStrings.seatProfileAuditSpecifics).hitTestable(),
      findsNothing,
    );
    final trainings = _withinDescription('records', AppStrings.seatProfileViewTrainings);
    expect(tester.getTopLeft(edit).dx, lessThan(tester.getTopLeft(trainings).dx));
    expect(tester.getTopLeft(edit).dy, closeTo(tester.getTopLeft(trainings).dy, 0.01));

    await tester.tap(title);
    await tester.pump();
    expect(edit.hitTestable(), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.getSize(card).height, closeTo(collapsedHeight, 0.01));
    expect(specifics.hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right swipe shows more and less for only the selected description', (tester) async {
    await _openScreen(tester);
    await _openCategory(tester, 'Financial Management');
    final type = _withinDescription('records', '${AppStrings.seatProfileCheckInType}:');
    expect(type.hitTestable(), findsOneWidget);
    expect(_withinDescription('records', 'Observation').hitTestable(), findsOneWidget);
    final collapsedHeight = tester.getSize(_description('records')).height;

    await _swipeDescription(tester, 'records', const Offset(180, 0));
    final more = _withinDescription('records', AppStrings.seatProfileShowMoreAction);
    _expectSecondaryColorSwipeAction(tester, more);
    expect(
      _withinDescription('records', AppStrings.seatProfileAuditSpecifics).hitTestable(),
      findsNothing,
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(
      _withinDescription('records', AppStrings.seatProfileAuditSpecifics).hitTestable(),
      findsOneWidget,
    );
    expect(
      _withinDescription('reports', AppStrings.seatProfileAuditSpecifics).hitTestable(),
      findsNothing,
    );
    expect(type, findsOneWidget);
    expect(find.text(AppStrings.seatProfileShowMoreAction), findsNothing);

    await _swipeDescription(tester, 'records', const Offset(180, 0));
    await tester.tap(_withinDescription('records', AppStrings.seatProfileShowLessAction));
    await tester.pumpAndSettle();
    expect(tester.getSize(_description('records')).height, closeTo(collapsedHeight, 0.01));
    expect(type.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('left swipe edits the collapsed description through the shared controller', (
    tester,
  ) async {
    final useCase = await _openScreen(tester);
    await _openCategory(tester, 'Financial Management');
    await _swipeDescription(tester, 'records', const Offset(-200, 0));
    final edit = _withinDescription('records', AppStrings.seatProfileEditAction).hitTestable();
    _expectSecondaryColorSwipeAction(tester, edit);
    expect(useCase.updatedDescriptionId, isNull);
    expect(useCase.deletedDescriptionId, isNull);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Controls Financial Records',
    );
    await tester.enterText(find.byType(TextField).first, 'Updated Financial Records');
    await tester.ensureVisible(find.text(AppStrings.seatProfileUpdateAction));
    await tester.tap(find.text(AppStrings.seatProfileUpdateAction));
    await tester.pumpAndSettle();
    expect(useCase.updatedDescriptionId, 'actual-records');
    expect(find.text('Updated Financial Records'), findsOneWidget);
    expect(
      _withinDescription('records', AppStrings.seatProfileAuditSpecifics).hitTestable(),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping reveals Delete and keeps the existing confirmation', (tester) async {
    final useCase = await _openScreen(tester);
    await _openCategory(tester, 'Financial Management');
    final delete = find.byTooltip(AppStrings.seatProfileDeleteDescriptionAction);
    await _swipeDescription(tester, 'records', const Offset(-200, 0));
    expect(useCase.deletedDescriptionId, isNull);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.seatProfileDeleteDescriptionTitle), findsOneWidget);
    expect(useCase.deletedDescriptionId, isNull);
    await tester.tap(find.text(AppStrings.actionCancel));
    await tester.pumpAndSettle();
    expect(find.text('Controls Financial Records'), findsOneWidget);
    await _swipeDescription(tester, 'records', const Offset(-200, 0));
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.seatProfileDeleteDescriptionAction));
    await tester.pumpAndSettle();
    expect(useCase.deletedDescriptionId, 'actual-records');
    expect(find.text('Controls Financial Records'), findsNothing);
    expect(find.text('Maintains Account Reports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interrupted expansion and refresh retain the description state', (tester) async {
    await _openScreen(tester);
    final controller = _controller(tester);
    await _openCategory(tester, 'Financial Management');
    final card = _description('records');
    final collapsedHeight = tester.getSize(card).height;
    final title = find.text('Controls Financial Records');
    await tester.tap(title);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final openingHeight = tester.getSize(card).height;
    expect(openingHeight, greaterThan(collapsedHeight));
    controller.selectTone(SeatProfileDetailContentTone.technical);
    await tester.pump();
    expect(tester.getSize(card).height, closeTo(openingHeight, 0.01));

    await tester.tap(title);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final closingHeight = tester.getSize(card).height;
    expect(closingHeight, lessThan(openingHeight));
    await tester.tap(title);
    await tester.pumpAndSettle();
    final expandedHeight = tester.getSize(card).height;
    expect(expandedHeight, greaterThan(openingHeight));
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(tester.getSize(card).height, expandedHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit saves through the shared controller and keeps the card expanded', (
    tester,
  ) async {
    final useCase = await _openScreen(tester);
    final controller = _controller(tester);
    await _openCategory(tester, 'Financial Management');
    await _expandDescription(tester);
    await tester.tap(_withinDescription('records', AppStrings.seatProfileEditAction));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Controls Financial Records',
    );
    await tester.enterText(find.byType(TextField).first, 'Maintains Financial Records');
    await tester.ensureVisible(find.text(AppStrings.seatProfileUpdateAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.seatProfileUpdateAction));
    await tester.pumpAndSettle();
    expect(useCase.updatedDescriptionId, 'actual-records');
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Maintains Financial Records'), findsOneWidget);
    expect(
      controller.detail!.categories.first.descriptions.first.name,
      'Maintains Financial Records',
    );
    expect(
      _withinDescription('records', AppStrings.seatProfileAuditSpecifics).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Description creates in the selected category and shows a collapsed card', (
    tester,
  ) async {
    final useCase = await _openScreen(tester);
    await _openCategory(tester, 'Service Quality');
    await tester.tap(find.text(AppStrings.seatProfileAddSeatDescriptionAction));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Reviews Customer Feedback');
    await tester.enterText(find.byType(TextField).at(1), 'Review each customer request');
    await tester.ensureVisible(find.text(AppStrings.seatProfileSaveAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.seatProfileSaveAction));
    await tester.pumpAndSettle();
    expect(useCase.createdCategoryId, 'service');
    expect(useCase.createdSeatId, 'actual-seat-id');
    expect(find.text(AppStrings.seatProfileNoDescriptionsFound), findsNothing);
    expect(find.text('Reviews Customer Feedback'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    expect(
      _withinDescription('new-description', AppStrings.seatProfileAuditSpecifics).hitTestable(),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded cards keep Delete in the swipe actions with confirmation', (tester) async {
    final useCase = await _openScreen(tester);
    final controller = _controller(tester);
    await _openCategory(tester, 'Financial Management');
    await _expandDescription(tester);
    expect(find.byType(SvgPicture), findsNothing);
    await _swipeDescription(tester, 'records', const Offset(-200, 0));
    final delete = find.byTooltip(AppStrings.seatProfileDeleteDescriptionAction);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.seatProfileDeleteDescriptionTitle), findsOneWidget);
    expect(useCase.deletedDescriptionId, isNull);
    await tester.tap(find.text(AppStrings.actionCancel));
    await tester.pumpAndSettle();
    expect(find.text('Controls Financial Records'), findsOneWidget);
    await _swipeDescription(tester, 'records', const Offset(-200, 0));
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.seatProfileDeleteDescriptionAction));
    await tester.pumpAndSettle();
    expect(useCase.deletedDescriptionId, 'actual-records');
    expect(find.text('Controls Financial Records'), findsNothing);
    expect(find.text('Maintains Account Reports'), findsOneWidget);
    expect(controller.detail!.categories.first.descriptions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty category opens its own list with the existing add action', (tester) async {
    await _openScreen(tester, disableAnimations: true);
    await _openCategory(tester, 'Service Quality');
    expect(find.text(AppStrings.seatProfileNoDescriptionsFound), findsOneWidget);
    expect(find.text(AppStrings.seatProfileAddSeatDescriptionAction), findsOneWidget);
    expect(find.text('Controls Financial Records'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow phones with large text keep read-only description actions usable', (
    tester,
  ) async {
    AppManager.instance.updateCurrentUser(User(uuid: 'member', roles: ['team_member']));
    const longTitle = 'Financial Management and Customer Experience Operations';
    await _openScreen(tester, firstTitle: longTitle, width: 320, textScale: 2);
    await _openCategory(tester, longTitle);
    await _swipeDescription(tester, 'records', const Offset(-200, 0));
    expect(find.byTooltip(AppStrings.seatProfileDeleteDescriptionAction), findsNothing);
    expect(_withinDescription('records', AppStrings.seatProfileEditAction), findsNothing);
    await _swipeDescription(tester, 'records', const Offset(180, 0));
    await tester.tap(_withinDescription('records', AppStrings.seatProfileShowMoreAction));
    await tester.pumpAndSettle();
    final trainings = _withinDescription('records', AppStrings.seatProfileViewTrainings);
    await tester.ensureVisible(trainings);
    await tester.pumpAndSettle();
    expect(trainings.hitTestable(), findsOneWidget);
    expect(find.text(AppStrings.seatProfileAddSeatDescriptionAction), findsNothing);
    expect(find.text(AppStrings.seatProfileEditAction), findsNothing);
    expect(find.byType(SvgPicture), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('child organisation descriptions allow Show More without editing or deletion', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode([
          {'uuid': 'org', 'name': 'Child', 'type': 'child'},
        ]),
        200,
      ),
    );
    addTearDown(client.close);
    await http.runWithClient(
      () => AppManager.instance.fetchOrganizations(forceRefresh: true, requireSuccess: true),
      () => client,
    );
    final useCase = await _openScreen(tester);
    await _openCategory(tester, 'Financial Management');
    await _swipeDescription(tester, 'records', const Offset(-200, 0));
    expect(find.byTooltip(AppStrings.seatProfileDeleteDescriptionAction), findsNothing);
    expect(find.text(AppStrings.seatProfileEditAction), findsNothing);
    await _swipeDescription(tester, 'records', const Offset(180, 0));
    await tester.tap(_withinDescription('records', AppStrings.seatProfileShowMoreAction));
    await tester.pumpAndSettle();
    expect(find.text('Verify all transactions accurately').hitTestable(), findsOneWidget);
    expect(useCase.updatedDescriptionId, isNull);
    expect(useCase.deletedDescriptionId, isNull);
    expect(find.byType(SvgPicture), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared category lists expand without editing or training actions', (tester) async {
    await _openScreen(tester, shared: true, disableAnimations: true);
    await _openCategory(tester, 'Financial Management');
    expect(
      tester
          .widget<SeatProfileDescriptionsScreen>(find.byType(SeatProfileDescriptionsScreen))
          .isShared,
      isTrue,
    );
    await _swipeDescription(tester, 'records', const Offset(-200, 0));
    expect(find.byTooltip(AppStrings.seatProfileDeleteDescriptionAction), findsNothing);
    await _swipeDescription(tester, 'records', const Offset(180, 0));
    await tester.tap(_withinDescription('records', AppStrings.seatProfileShowMoreAction));
    await tester.pumpAndSettle();
    expect(find.text('Verify all transactions accurately').hitTestable(), findsOneWidget);
    expect(find.text(AppStrings.seatProfileAddSeatDescriptionAction), findsNothing);
    expect(find.text(AppStrings.seatProfileViewTrainings), findsNothing);
    expect(find.text(AppStrings.seatProfileEditAction), findsNothing);
    expect(find.text(AppStrings.seatProfileGenerateAction), findsNothing);
    expect(find.byType(SvgPicture), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('expanded specifics retain inline See All at text scale $textScale', (
      tester,
    ) async {
      final specifics = List.filled(
        12,
        'Verify every invoice and its approval before closing the monthly accounts.',
      ).join(' ');
      await _openScreen(
        tester,
        width: textScale == 1 ? 390 : 320,
        textScale: textScale,
        auditSpecifics: specifics,
      );
      await _openCategory(tester, 'Financial Management');
      await _expandDescription(tester);
      final seeAll = _withinDescription('records', AppStrings.seeAllAction);
      expect(seeAll, findsOneWidget);
      await tester.ensureVisible(seeAll);
      await tester.pumpAndSettle();
      expect(seeAll.hitTestable(), findsOneWidget);
      final preview = find
          .textContaining(AppStrings.seatProfileDescriptionEllipsis, findRichText: true)
          .first;
      expect(tester.getRect(preview).contains(tester.getCenter(seeAll)), isTrue);
      expect(find.text(specifics), findsNothing);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(specifics), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byType(AppOverlayCloseButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

Finder _description(String id) => find.byKey(ValueKey(id));
Finder _withinDescription(String id, String label) =>
    find.descendant(of: _description(id), matching: find.text(label));

Future<void> _swipeDescription(WidgetTester tester, String id, Offset offset) async {
  await tester.drag(
    find.descendant(of: _description(id), matching: find.byType(AppSwipeRevealAction)),
    offset,
  );
  await tester.pumpAndSettle();
}

void _expectSecondaryColorSwipeAction(WidgetTester tester, Finder label) {
  expect(label.hitTestable(), findsOneWidget);
  final material = find.ancestor(of: label, matching: find.byType(Material)).first;
  expect(tester.widget<Material>(material).color, AppColors.secondaryColor);
}

SeatProfileDetailController _controller(WidgetTester tester) =>
    tester.element(find.byType(SeatProfileDetailView)).read<SeatProfileDetailController>();

Future<void> _openCategory(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(find.text(title), 200);
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  expect(find.text(AppStrings.seatProfileDescriptionsTitle), findsOneWidget);
}

Future<void> _expandDescription(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Controls Financial Records'));
  await tester.tap(find.text('Controls Financial Records'));
  await tester.pumpAndSettle();
}

Future<_SeatProfileDetailUseCase> _openScreen(
  WidgetTester tester, {
  String firstTitle = 'Financial Management',
  double width = 390,
  double textScale = 1,
  bool disableAnimations = false,
  bool shared = false,
  String auditSpecifics = 'Verify all transactions accurately',
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final useCase = _SeatProfileDetailUseCase(firstTitle, auditSpecifics);
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: disableAnimations),
        child: child!,
      ),
      home: shared
          ? SharedSeatProfileScreen(publicId: 'public-id', getSeatProfilesUseCase: useCase)
          : SeatProfileDetailScreen(seatId: 'seat-id', getSeatProfilesUseCase: useCase),
    ),
  );
  await tester.pumpAndSettle();
  return useCase;
}

class _SeatProfileDetailUseCase extends Fake implements GetSeatProfilesUseCase {
  _SeatProfileDetailUseCase(this.firstTitle, String auditSpecifics) {
    descriptions = [
      SeatProfileDescription(
        id: 'records',
        actualId: 'actual-records',
        name: 'Controls Financial Records',
        auditSpecifics: auditSpecifics,
        auditFactorType: 'observation',
        milestoneDays: '30',
      ),
      const SeatProfileDescription(
        id: 'reports',
        actualId: 'actual-reports',
        name: 'Maintains Account Reports',
        auditSpecifics: 'Review account statements',
        auditFactorType: 'observation',
        milestoneDays: '30',
      ),
    ];
  }

  final String firstTitle;
  late List<SeatProfileDescription> descriptions;
  final List<SeatProfileDescription> serviceDescriptions = [];
  String? updatedDescriptionId;
  String? deletedDescriptionId;
  String? createdCategoryId;
  String? createdSeatId;

  @override
  Future<String?> getSeatProfilePublicLink(String seatId) async => null;
  @override
  Future<SeatProfileDetail> getSeatProfileDetail(String seatId) async => _detail;
  @override
  Future<SeatProfileDetail> getSharedSeatProfileDetail(String publicId) async => _detail;

  @override
  Future<void> updateSeatProfileDescription({
    required String descriptionId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  }) async {
    updatedDescriptionId = descriptionId;
    descriptions = descriptions
        .map(
          (description) => description.actualId == descriptionId
              ? SeatProfileDescription(
                  id: description.id,
                  actualId: description.actualId,
                  name: descriptionName,
                  auditSpecifics: auditSpecifics,
                  auditFactorType: auditFactorType,
                  milestoneDays: milestoneDays ?? '',
                )
              : description,
        )
        .toList();
  }

  @override
  Future<void> deleteSeatProfileDescription({required String descriptionId}) async {
    deletedDescriptionId = descriptionId;
    descriptions = descriptions
        .where((description) => description.actualId != descriptionId)
        .toList();
  }

  @override
  Future<void> createSeatProfileDescription({
    required String actualId,
    required String categoryId,
    required String descriptionName,
    required String auditSpecifics,
    required String auditFactorType,
    String? milestoneDays,
  }) async {
    createdSeatId = actualId;
    createdCategoryId = categoryId;
    serviceDescriptions.add(
      SeatProfileDescription(
        id: 'new-description',
        actualId: 'actual-new-description',
        name: descriptionName,
        auditSpecifics: auditSpecifics,
        auditFactorType: auditFactorType,
        milestoneDays: milestoneDays ?? '',
      ),
    );
  }

  SeatProfileDetail get _detail => SeatProfileDetail(
    id: 'seat-id',
    actualId: 'actual-seat-id',
    title: 'Operations Lead',
    department: const Department(id: 'operations', name: 'Operations'),
    paygradeUnit: 'hr',
    categories: [
      SeatProfileCategory(
        id: 'finance',
        title: firstTitle,
        weightPercent: 30,
        descriptions: List.of(descriptions),
      ),
      SeatProfileCategory(
        id: 'service',
        title: 'Service Quality',
        weightPercent: 70,
        descriptions: List.of(serviceDescriptions),
      ),
    ],
  );
}
