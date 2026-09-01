import 'package:dio/dio.dart';

/// Erro ja traduzido para mensagem exibivel ao usuario.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Código de negócio do backend (`SCHEDULE_CHANGED`, `CANNOT_REMOVE_OWNER`).
  ///
  /// A `message` é para a pessoa ler; o `code` é para a tela reagir. Sem ele,
  /// reconhecer um erro específico exigiria comparar o texto da mensagem — que
  /// muda de redação sem aviso.
  final String? code;

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
        return ApiException(
          message,
          statusCode: e.response?.statusCode,
          code: data is Map ? data['code'] as String? : null,
        );
    }
  }

  @override
  String toString() => message;
}
