import '../constants/app_strings.dart';

class ApiError implements Exception {
  const ApiError._(this.message, {this.statusCode, this.responseData});

  const ApiError.invalidUrl() : this._(AppStrings.apiInvalidUrl);
  const ApiError.invalidResponse() : this._(AppStrings.apiInvalidResponse);
  ApiError.requestFailed(
    int statusCode, {
    String? message,
    Object? responseData,
  }) : this._(
         message ?? AppStrings.apiRequestFailed(statusCode),
         statusCode: statusCode,
         responseData: responseData,
       );

  final String message;
  final int? statusCode;
  final Object? responseData;

  @override
  String toString() => '${AppStrings.apiErrorPrefix} $message';
}
