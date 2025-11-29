// lib/services/middleware_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/receipt_models.dart';
import '../models/api_result.dart';
import '../utils/api_config.dart';

class MiddlewareService {
  final http.Client _client;

  MiddlewareService({http.Client? client}) : _client = client ?? http.Client();

  Future<ApiResult> sendReceipt(ReceiptParseResult receipt) async {
    final uri = Uri.parse(ApiConfig.receiptsEndpoint);

    final body = jsonEncode(receipt.toJson());

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        String message = 'Fiş başarıyla gönderildi.';

        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) {
            message = decoded['message'] as String;
          }
        } catch (_) {}

        return ApiResult(success: true, message: message);
      } else {
        return ApiResult(
          success: false,
          message: 'Sunucudan hata kodu alındı: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResult(success: false, message: 'Bağlantı hatası: $e');
    }
  }
}
