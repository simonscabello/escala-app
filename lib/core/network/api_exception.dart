import 'package:dio/dio.dart';

/// Erro ja traduzido para mensagem exibivel ao usuario.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException('O servidor demorou a responder.');
      case DioExceptionType.connectionError:
        return const ApiException(
          'Não foi possível conectar ao servidor. Verifique sua internet.',
        );
      default:
        final data = e.response?.data;
        final message = data is Map && data['message'] != null
            ? (data['message'] is List
                ? (data['message'] as List).join('\n')
                : data['message'].toString())
            : 'Algo deu errado. Tente novamente.';
        return ApiException(message, statusCode: e.response?.statusCode);
    }
  }

  @override
  String toString() => message;
}
