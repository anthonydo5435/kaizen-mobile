import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sparrowkaizen/core/managers/app_manager.dart';
import 'package:sparrowkaizen/core/preference/app_preference.dart';
import 'package:sparrowkaizen/core/services/deep_link_service.dart';
import 'package:sparrowkaizen/core/widgets/billing_banner.dart';
import 'package:sparrowkaizen/core/widgets/organization_conflict_dialog.dart';
import 'package:sparrowkaizen/features/training/presentation/widgets/training_video_upload_banner.dart';

import 'core/constants/app_fonts.dart';
import 'core/constants/app_strings.dart';
import 'routes/app_router.dart';

const bool _showTrainingVideoUploadBanner = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  await AppPreference.init();
  await AppManager.instance.hydrateCurrentUser();
  await DeepLinkService.instance.initialize();
  runApp(const MyApp());
  //unawaited(PushNotificationService.instance.initialize());
}

class _AppRouteObserver extends NavigatorObserver {
  _AppRouteObserver(this._appManager);

  final AppManager _appManager;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _appManager.updateCurrentRouteName(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _appManager.updateCurrentRouteName(previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _appManager.updateCurrentRouteName(newRoute?.settings.name);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _appManager.updateCurrentRouteName(previousRoute?.settings.name);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_wasBackgrounded) {
        return;
      }

      _wasBackgrounded = false;
      if (AppManager.instance.consumeResumeSessionRefreshSkip()) {
        return;
      }
      unawaited(AppManager.instance.refreshSessionContext());
      return;
    }

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      fontFamily: AppFonts.inter,
    );

    return ChangeNotifierProvider<AppManager>.value(
      value: AppManager.instance,
      child: Consumer<AppManager>(
        builder: (context, appManager, _) {
          return MaterialApp(
            navigatorKey: AppRouter.navigatorKey,
            title: AppStrings.appTitle,
            theme: baseTheme.copyWith(
              textTheme: baseTheme.textTheme.apply(fontFamily: AppFonts.inter),
              primaryTextTheme: baseTheme.primaryTextTheme.apply(
                fontFamily: AppFonts.inter,
              ),
            ),
            builder: (context, child) {
              return Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  if (appManager.showBillingBanner) const BillingBanner(),
                  if (_showTrainingVideoUploadBanner)
                    const TrainingVideoUploadBanner(),
                  if (appManager.showOrganizationBanner)
                    const OrganizationConflictDialog(),
                ],
              );
            },
            debugShowCheckedModeBanner: false,
            navigatorObservers: <NavigatorObserver>[
              _AppRouteObserver(appManager),
            ],
            initialRoute: AppRouter.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
