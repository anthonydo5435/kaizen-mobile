import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/managers/app_manager.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_processor.dart';
import '../../../../core/preference/app_preference.dart';
import '../../../../core/services/file_uploader.dart';
import '../../../../core/utils/custom_functions.dart';
import '../../../login/data/datasources/auth_remote_data_source.dart';
import '../../../login/domain/entities/user.dart';

class ProfileController extends ChangeNotifier {
  final ApiCallExecutor _apiCallExecutor = const ApiCallExecutor();
  final FileUploader _fileUploader = const FileUploader();
  final AuthRemoteDataSource _authRemoteDataSource = AuthRemoteDataSource();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = true;
  bool _hasInitialized = false;
  bool _isOpeningImagePicker = false;
  bool _isUpdatingImage = false;
  bool _isUpdatingDateOfBirth = false;
  User? _user;

  bool get isLoading => _isLoading;
  bool get isOpeningImagePicker => _isOpeningImagePicker;
  bool get isUpdatingImage => _isUpdatingImage;
  bool get isProcessingImageUpdate => _isOpeningImagePicker || _isUpdatingImage;
  bool get isUpdatingDateOfBirth => _isUpdatingDateOfBirth;
  User? get user => _user;

  Future<void> initialize() async {
    if (_hasInitialized) {
      return;
    }

    _hasInitialized = true;
    _user = await AppPreference.getUser();
    _isLoading = false;
    notifyListeners();

    await _refreshUserDetailsSilently();
  }

  Future<void> pickAndUpdateProfileImage() async {
    if (_user == null || _isOpeningImagePicker || _isUpdatingImage) {
      return;
    }

    _isOpeningImagePicker = true;
    notifyListeners();

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      await updateProfileImage(image.path);
    } finally {
      _isOpeningImagePicker = false;
      notifyListeners();
    }
  }

  Future<void> updateProfileImage(String imagePath) async {
    if (_user == null || _isUpdatingImage) {
      return;
    }

    final trimmedImagePath = imagePath.trim();
    if (trimmedImagePath.isEmpty) {
      return;
    }

    _isUpdatingImage = true;
    notifyListeners();

    try {
      final authToken = AppPreference.getAuthToken().trim();
      final userId = _resolveUserId(_user);
      if (authToken.isEmpty || userId.isEmpty) {
        throw const ApiError.invalidResponse();
      }

      final fileName = CustomFunctions.fileNameFromPath(trimmedImagePath);
      final contentType = CustomFunctions.contentTypeFromPath(trimmedImagePath);
      final fileBytes = await File(trimmedImagePath).readAsBytes();

      final uploadedImage = await _fileUploader.uploadOnboardingImage(
        fileName: fileName,
        fileBytes: fileBytes,
        contentType: contentType,
        authToken: authToken,
      );

      await _apiCallExecutor.processApi<void>(
        apiCallType: ApiCallType.patch,
        endpoint: ApiEndPoints.userById(userId),
        authToken: authToken,
        parameters: {'image': uploadedImage.uuid},
        decoder: (_) {},
      );

      final updatedUser = _user!.copyWith(
        image: uploadedImage.image,
        imageUuid: uploadedImage.uuid,
        imageUrl: uploadedImage.image,
      );
      await AppPreference.saveUser(updatedUser);
      AppManager.instance.updateCurrentUser(updatedUser);
      _user = updatedUser;
    } catch (error) {
      debugPrint('Unable to update profile image: $error');
      rethrow;
    } finally {
      _isUpdatingImage = false;
      notifyListeners();
    }
  }

  Future<void> updateDateOfBirth(String formattedDate) async {
    if (_user == null || _isUpdatingDateOfBirth) {
      return;
    }

    final trimmedDate = formattedDate.trim();
    if (trimmedDate.isEmpty) {
      return;
    }

    final existingDate = _normalizeDateOfBirthValue(_user!.dateOfBirth);
    if (existingDate == trimmedDate) {
      return;
    }

    _isUpdatingDateOfBirth = true;
    notifyListeners();

    try {
      final authToken = AppPreference.getAuthToken().trim();
      final userId = _resolveUserId(_user);
      if (authToken.isEmpty || userId.isEmpty) {
        throw const ApiError.invalidResponse();
      }

      final payload = _buildProfileUpdatePayload(
        user: _user!,
        dateOfBirth: trimmedDate,
      );

      await _apiCallExecutor.processApi<void>(
        apiCallType: ApiCallType.patch,
        endpoint: ApiEndPoints.userById(userId),
        authToken: authToken,
        parameters: payload,
        decoder: (_) {},
      );

      final updatedUser = _user!.copyWith(dateOfBirth: trimmedDate);
      await AppPreference.saveUser(updatedUser);
      AppManager.instance.updateCurrentUser(updatedUser);
      _user = updatedUser;
    } catch (error) {
      debugPrint('Unable to update date of birth: $error');
      rethrow;
    } finally {
      _isUpdatingDateOfBirth = false;
      notifyListeners();
    }
  }

  String _resolveUserId(User? user) {
    return user?.userUuid?.trim() ?? user?.uuid?.trim() ?? '';
  }

  Future<void> _refreshUserDetailsSilently() async {
    final authToken = AppPreference.getAuthToken().trim();
    if (authToken.isEmpty) {
      return;
    }

    try {
      final refreshedUser = await _authRemoteDataSource.fetchUserDetail(
        accessToken: authToken,
      );
      await AppPreference.saveUser(refreshedUser);
      AppManager.instance.updateCurrentUser(refreshedUser);
      _user = refreshedUser;
      notifyListeners();
    } catch (error) {
      debugPrint('Unable to refresh profile user details silently: $error');
    }
  }

  String? _normalizeDateOfBirthValue(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }

    final parsedDate = DateTime.tryParse(trimmedValue);
    if (parsedDate != null) {
      return _formatApiDate(parsedDate);
    }

    final numericValue = int.tryParse(trimmedValue);
    if (numericValue == null) {
      return trimmedValue;
    }

    final timestamp = trimmedValue.length <= 10
        ? numericValue * 1000
        : numericValue;
    return _formatApiDate(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  String _formatApiDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, dynamic> _buildProfileUpdatePayload({
    required User user,
    required String dateOfBirth,
  }) {
    final profileAddress = user.profileAddress;

    return <String, dynamic>{
      'first_name': user.firstName?.trim() ?? '',
      'last_name': user.lastName?.trim() ?? '',
      'contact_no': user.contactNo?.trim() ?? '',
      'email': user.email?.trim() ?? '',
      'prefix': '',
      'gender': user.gender?.trim() ?? '',
      'personality_type': user.personalityType?.trim() ?? '',
      'profile_address': <String, dynamic>{
        'address': profileAddress?.address?.trim() ?? '',
        'city': profileAddress?.city?.trim() ?? '',
        'state': profileAddress?.state?.trim() ?? '',
        'country': profileAddress?.country?.trim() ?? '',
        'zip_code': profileAddress?.zipCode?.trim() ?? '',
      },
      'date_of_birth': dateOfBirth,
    };
  }
}
