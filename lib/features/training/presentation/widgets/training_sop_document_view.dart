import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiptap_flutter/tiptap_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_text_view.dart';
import '../../../../core/widgets/fast_circular_progress.dart';
import '../controllers/training_module_controller.dart';
import '../controllers/training_sop_editor_controller.dart';
import '../controllers/training_sop_engine_controller.dart';

/// Keeps the native A4 surface mounted while initialization is covered by a loader.
class TrainingSopDocumentView extends StatelessWidget {
  const TrainingSopDocumentView({super.key, required this.controller});

  final TrainingSopEditorController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: !controller.isReady,
            child: switch (controller.editor) {
              final TrainingSopSurface surface => surface.buildDocument(
                width: constraints.maxWidth,
                textScale: MediaQuery.textScalerOf(context).scale(1),
              ),
              final editor => TiptapEditor(controller: editor),
            },
          ),
          if (!controller.isReady)
            // Paint the platform view at its real size beneath this cover. A
            // zero-opacity view has no native viewport during initialization.
            ColoredBox(
              color: Colors.white,
              child: Center(
                child: controller.errorMessage == null
                    ? const FastCircularProgressIndicator(color: AppColors.secondaryColor)
                    : const Padding(
                        padding: EdgeInsets.all(16),
                        child: AppTextView.body1(
                          AppStrings.trainingSopEditorError,
                          color: AppColors.mainBg,
                        ),
                      ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Uses the same A4 engine in read-only mode, with no formatting or write callback.
class TrainingSopReader extends StatelessWidget {
  const TrainingSopReader({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<TrainingSopEditorController>(
    key: ValueKey(html),
    create: (context) {
      final factory = context.read<TrainingSopEditorFactory?>();
      final controller =
          factory?.call(html, (_) {}) ??
          TrainingSopEditorController(initialHtml: html, onHtmlChanged: (_) {});
      controller.initialize(editable: false);
      return controller;
    },
    child: Consumer<TrainingSopEditorController>(
      builder: (_, controller, _) => TrainingSopDocumentView(controller: controller),
    ),
  );
}
