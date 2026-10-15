import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/navigation/app_menu_type.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/drawer_main_screen.dart';
import '../../../../features/login/domain/entities/user.dart';
import '../providers/kaizen_gpt_controller.dart';

class KaizenGptScreen extends StatelessWidget {
  const KaizenGptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<KaizenGptController>(
      create: (_) => KaizenGptController()..initializeAssistantSocket(),
      child: const _KaizenGptView(),
    );
  }
}

class _KaizenGptView extends StatefulWidget {
  const _KaizenGptView();

  @override
  State<_KaizenGptView> createState() => _KaizenGptViewState();
}

class _KaizenGptViewState extends State<_KaizenGptView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbAnimationController;
  late final Animation<double> _orbScaleAnimation;
  late final Future<User?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = AppPreference.getUser();
    _orbAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _orbScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.06,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_orbAnimationController);
  }

  @override
  void dispose() {
    _orbAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<KaizenGptController>();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.scrollToBottom(),
    );

    return DrawerMainScreen(
      title: '',
      selectedMenu: AppMenuType.kaizenGpt,
      child: _buildBody(controller),
    );
  }

  Widget _buildBody(KaizenGptController controller) {
    return SafeArea(
      top: false,
      bottom: false,
      child: _buildHomeView(controller),
    );
  }

  Widget _buildHomeView(KaizenGptController controller) {
    return FutureBuilder<User?>(
      future: _userFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 60, 12, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    AppTextView.title1(
                      CustomFunctions.buildGreeting(user),
                      color: AppColors.textPrimary.withValues(alpha: 0.72),
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _buildAiOrb(controller),
                    const SizedBox(height: 16),
                    AppTextView.body1(
                      controller.isListening
                          ? 'Hearing You'
                          : controller.isResponding
                          ? 'AI Speaking'
                          : AppStrings.kaizenGptReady,
                      color: AppColors.textPrimary.withValues(alpha: 0.8),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatusButton(
                          icon: controller.isMicMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          isActive: controller.isMicMuted,
                          isBusy: controller.isMicToggleInProgress,
                          onTap: () => controller.toggleMic(context),
                        ),
                        const SizedBox(width: 9),
                        _buildStatusButton(
                          icon: controller.isSpeakerMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          isActive: controller.isSpeakerMuted,
                          isBusy: controller.isSpeakerToggleInProgress,
                          onTap: controller.toggleSpeaker,
                        ),
                      ],
                    ),
                    if (controller.showSpeechTranscript) ...[
                      const SizedBox(height: 18),
                      showLatestMessage(controller),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAiOrb(KaizenGptController controller) {
    final isListening = controller.isListening;
    final outerBorderColor = isListening
        ? AppColors.green1.withValues(alpha: 0.82)
        : AppColors.purple1.withValues(alpha: 0.82);
    final outerShadowColor = isListening
        ? AppColors.green1.withValues(alpha: 0.12)
        : AppColors.purple2.withValues(alpha: 0.10);
    final outerGradientColors = isListening
        ? <Color>[
            AppColors.hex79c99d.withValues(alpha: 0.12),
            AppColors.hex2e8f63.withValues(alpha: 0.16),
            AppColors.hex102c20.withValues(alpha: 0.56),
            AppColors.hex09080f,
          ]
        : <Color>[
            AppColors.hex7756da.withValues(alpha: 0.10),
            AppColors.hex5f3cb8.withValues(alpha: 0.16),
            AppColors.hex251a45.withValues(alpha: 0.56),
            AppColors.hex09080f,
          ];
    final innerGradientColors = isListening
        ? <Color>[
            AppColors.hexb8f0cf.withValues(alpha: 0.90),
            AppColors.hex4fa978.withValues(alpha: 0.60),
            AppColors.hex173628.withValues(alpha: 0.54),
            AppColors.hex0e0c17,
          ]
        : <Color>[
            AppColors.hex9c78ff.withValues(alpha: 0.94),
            AppColors.hex6546cc.withValues(alpha: 0.64),
            AppColors.hex2c1f52.withValues(alpha: 0.52),
            AppColors.hex0e0c17,
          ];
    final coreGlowColor = isListening
        ? AppColors.hex4fa978.withValues(alpha: 0.18)
        : AppColors.secondaryColor.withValues(alpha: 0.22);
    final coreShadowColor = isListening
        ? AppColors.green1.withValues(alpha: 0.16)
        : AppColors.purple2.withValues(alpha: 0.14);

    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.10),
                  width: 1.1,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _orbScaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _orbScaleAnimation.value,
                  child: child,
                );
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: outerBorderColor, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: outerShadowColor,
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ],
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.84,
                    colors: outerGradientColors,
                    stops: const [0.0, 0.30, 0.64, 1.0],
                  ),
                ),
              ),
            ),
            Container(
              width: 184,
              height: 184,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                  width: 1,
                ),
                gradient: RadialGradient(
                  center: const Alignment(-0.05, -0.08),
                  radius: 0.80,
                  colors: innerGradientColors,
                  stops: const [0.0, 0.24, 0.54, 1.0],
                ),
              ),
            ),
            Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: coreShadowColor,
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
                gradient: RadialGradient(
                  colors: [coreGlowColor, Colors.transparent],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
            Image.asset(
              '${AppStrings.imagePath}ai.png',
              width: 95,
              height: 95,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton({
    required IconData icon,
    required bool isActive,
    required bool isBusy,
    required VoidCallback onTap,
  }) {
    final accentColor = isActive ? AppColors.hexff633b : AppColors.green1;
    final effectiveOnTap = isBusy ? null : onTap;

    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: effectiveOnTap,
          child: Center(
            child: Opacity(
              opacity: isBusy ? 0.72 : 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.45),
                      ),
                      color: AppColors.surfaceDark.withValues(alpha: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.12),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: accentColor, size: 28),
                  ),
                  if (isActive)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.hexff5b3e,
                          border: Border.all(color: AppColors.mainBg, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.hexff5b3e.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget showLatestMessage(KaizenGptController controller) {
    final latestMessage = controller.latestTranscriptPairText.trim();
    final baseStyle = _transcriptBaseStyle(latestMessage);

    return _buildTranscriptBox(text: latestMessage, baseStyle: baseStyle);
  }

  Widget showAllMessages(KaizenGptController controller) {
    final transcript = controller.transcriptText.trim();
    final baseStyle = _transcriptBaseStyle(transcript);

    return _buildTranscriptBox(text: transcript, baseStyle: baseStyle);
  }

  Widget _buildTranscriptBox({
    required String text,
    required TextStyle baseStyle,
  }) {
    final maxTranscriptHeight = MediaQuery.sizeOf(context).height * 0.34;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: 340,
        minHeight: 72,
        maxHeight: maxTranscriptHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.fieldBorder.withValues(alpha: 0.26),
        ),
      ),
      child: text.isEmpty
          ? AppTextView.body2(
              AppStrings.kaizenGptListening,
              color: AppColors.textPrimary.withValues(alpha: 0.66),
              height: 1.45,
              textAlign: TextAlign.left,
            )
          : SingleChildScrollView(
              child: RichText(
                textAlign: TextAlign.left,
                text: TextSpan(
                  style: baseStyle,
                  children: _buildTranscriptSpans(text, baseStyle),
                ),
              ),
            ),
    );
  }

  TextStyle _transcriptBaseStyle(String transcript) {
    return TextStyle(
      color: AppColors.textPrimary.withValues(
        alpha: transcript.isEmpty ? 0.66 : 0.92,
      ),
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.45,
    );
  }

  List<TextSpan> _buildTranscriptSpans(String transcript, TextStyle baseStyle) {
    final lines = transcript.split('\n\n');
    final spans = <TextSpan>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.startsWith('You: ')) {
        spans.addAll([
          TextSpan(
            text: 'You: ',
            style: baseStyle.copyWith(
              color: AppColors.purple2,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: line.substring(5)),
        ]);
      } else if (line.startsWith('AI: ')) {
        spans.addAll([
          TextSpan(
            text: 'AI: ',
            style: baseStyle.copyWith(
              color: AppColors.green1,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: line.substring(4)),
        ]);
      } else {
        spans.add(TextSpan(text: line));
      }

      if (index < lines.length - 1) {
        spans.add(const TextSpan(text: '\n\n'));
      }
    }

    return spans;
  }
}
