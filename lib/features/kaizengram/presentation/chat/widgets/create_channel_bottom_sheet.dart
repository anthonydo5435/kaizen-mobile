import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/app_text_view.dart';
import '../../../../../core/widgets/app_keyboard_bottom_sheet_surface.dart';
import '../../widgets/kaizengram_notifier_state.dart';
import '../providers/kaizengram_chat_controller.dart';
import 'chat_module_ui.dart';
import 'package:sparrowkaizen/core/constants/app_strings.dart';

class CreateChannelBottomSheet extends StatefulWidget {
  const CreateChannelBottomSheet({super.key, required this.controller});

  final KaizengramChatController controller;

  @override
  State<CreateChannelBottomSheet> createState() =>
      _CreateChannelBottomSheetState();
}

class _CreateChannelBottomSheetState extends State<CreateChannelBottomSheet>
    with KaizengramNotifierState<CreateChannelBottomSheet> {
  late final TextEditingController _textController = TextEditingController();
  String? _errorText;
  String? _selectedImagePath;
  var _isPickingImage = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithNotifier((context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          bottom: false,
          child: AppKeyboardBottomSheetSurface(
            width: double.infinity,
            color: kaizengramChatScreenSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const KaizengramChatSheetHandle(),
                  const SizedBox(height: 18),
                  const AppTextView.body1(
                    AppStrings.createChannelTitle,
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  const SizedBox(height: 6),
                  const AppTextView.body2(
                    AppStrings.createChannelSubtitle,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  AppTextView.body2(
                    AppStrings.createChannelImageLabel,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isPickingImage ? null : _handlePickImage,
                      borderRadius: BorderRadius.circular(14),
                      child: KaizengramChatInputShell(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 58,
                                  height: 58,
                                  child: _selectedImagePath == null
                                      ? Container(
                                          color: AppColors.surfaceDark3,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.tag_rounded,
                                            color: AppColors.secondaryColor,
                                            size: 24,
                                          ),
                                        )
                                      : Image.file(
                                          File(_selectedImagePath!),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    AppTextView.body2(
                                      _selectedImagePath == null
                                          ? AppStrings.createChannelImageHint
                                          : AppStrings.actionChangeImage,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    const SizedBox(height: 4),
                                    AppTextView.body3(
                                      _selectedImagePath == null
                                          ? AppStrings.actionAddImage
                                          : AppStrings
                                                .createChannelImageSelectedHint,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _isPickingImage
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.textPrimary,
                                      ),
                                    )
                                  : Icon(
                                      _selectedImagePath == null
                                          ? Icons.add_photo_alternate_outlined
                                          : Icons.edit_outlined,
                                      color: AppColors.textPrimary,
                                      size: 20,
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  KaizengramChatInputShell(
                    borderColor: _errorText == null
                        ? null
                        : AppColors.red.withValues(alpha: 0.70),
                    child: TextField(
                      controller: _textController,
                      maxLength: 20,
                      style: const TextStyle(color: AppColors.textPrimary),
                      cursorColor: AppColors.textPrimary,
                      decoration: const InputDecoration(
                        labelText: AppStrings.channelNameLabel,
                        hintText: AppStrings.channelNameHint,
                        counterText: '',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.fromLTRB(14, 14, 14, 14),
                      ),
                      onChanged: (_) {
                        if (_errorText == null) {
                          return;
                        }
                        updateView(() => _errorText = null);
                      },
                    ),
                  ),
                  if (_errorText != null) ...<Widget>[
                    const SizedBox(height: 8),
                    AppTextView.body4(
                      _errorText!,
                      color: AppColors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: KaizengramChatSecondaryButton(
                          label: AppStrings.actionCancel,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KaizengramChatPrimaryButton(
                          label: AppStrings.actionCreate,
                          onTap: _handleCreateChannel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  void _handleCreateChannel() {
    final validationMessage = widget.controller.validateChannelName(
      _textController.text,
    );
    if (validationMessage != null) {
      updateView(() => _errorText = validationMessage);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final createdChannel = widget.controller.createChannel(
      _textController.text,
      imagePath: _selectedImagePath,
    );
    Navigator.of(context).pop(createdChannel);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppStrings.channelCreatedSnackBar(createdChannel)),
        ),
      );
  }

  Future<void> _handlePickImage() async {
    updateView(() {
      _isPickingImage = true;
    });

    try {
      final selectedImagePath = await widget.controller.pickChannelImage();
      if (!mounted || selectedImagePath == null || selectedImagePath.isEmpty) {
        return;
      }

      updateView(() {
        _selectedImagePath = selectedImagePath;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.pickChannelImageError)),
        );
    } finally {
      if (mounted) {
        updateView(() {
          _isPickingImage = false;
        });
      } else {
        _isPickingImage = false;
      }
    }
  }
}
