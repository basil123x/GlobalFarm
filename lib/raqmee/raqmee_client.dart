import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RaqmeeResponse {
  final int statusCode;
  final String body;

  const RaqmeeResponse({required this.statusCode, required this.body});

  bool get isOk => statusCode >= 200 && statusCode < 300;

  @override
  String toString() => 'RaqmeeResponse($statusCode)';
}

class RaqmeeException implements Exception {
  final int statusCode;
  final String body;

  const RaqmeeException({required this.statusCode, required this.body});

  @override
  String toString() => 'RaqmeeException(status: $statusCode, body: $body)';
}

/// Minimal inbound client for Raqmee customers / send-message APIs.
/// Secrets are read from dotenv only — never log [RAQMEE_SIGNATURE_SECRET].
class RaqmeeClient {
  static const _timeout = Duration(seconds: 15);

  final http.Client _http;

  RaqmeeClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  String get _customersUrl =>
      (dotenv.env['RAQMEE_INBOUND_CUSTOMERS_URL'] ?? '').trim();

  String get _sendMessageUrl =>
      (dotenv.env['RAQMEE_INBOUND_SEND_MESSAGE_URL'] ?? '').trim();

  String get _channelId => (dotenv.env['RAQMEE_CHANNEL_ID'] ?? '').trim();

  String get _secret =>
      (dotenv.env['RAQMEE_SIGNATURE_SECRET'] ?? '').trim();

  String get _signatureHeader =>
      (dotenv.env['RAQMEE_SIGNATURE_HEADER'] ?? 'X-Signature').trim();

  String get _signatureMode =>
      (dotenv.env['RAQMEE_SIGNATURE_MODE'] ?? 'hmac-sha256-hex')
          .trim()
          .toLowerCase();

  void _assertSecret() {
    if (_secret.isEmpty) {
      throw StateError(
        'RAQMEE_SIGNATURE_SECRET is missing. Set it in .env (do not commit it).',
      );
    }
  }

  String _signBody(String rawBody) {
    if (_signatureMode == 'header-secret') {
      return _secret;
    }
    // Default: hmac-sha256-hex over the exact request body bytes.
    final digest =
        Hmac(sha256, utf8.encode(_secret)).convert(utf8.encode(rawBody));
    return digest.toString();
  }

  Future<RaqmeeResponse> _postSigned({
    required String url,
    required Map<String, dynamic> payload,
  }) async {
    _assertSecret();
    if (url.isEmpty) {
      throw StateError('Raqmee URL is missing. Set it in .env');
    }

    // Encode once so the signature matches the exact body bytes sent.
    final rawBody = jsonEncode(payload);
    final signature = _signBody(rawBody);

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      _signatureHeader: signature,
      if (_channelId.isNotEmpty) 'X-Channel-Id': _channelId,
    };

    final response = await _http
        .post(Uri.parse(url), headers: headers, body: rawBody)
        .timeout(_timeout);

    final result = RaqmeeResponse(
      statusCode: response.statusCode,
      body: response.body,
    );

    if (!result.isOk) {
      throw RaqmeeException(
        statusCode: result.statusCode,
        body: result.body,
      );
    }

    return result;
  }

  Future<RaqmeeResponse> upsertCustomer({
    required String name,
    required String phone,
    String? email,
    String? externalId,
    List<String>? tags,
  }) async {
    if (_customersUrl.isEmpty) {
      throw StateError(
        'RAQMEE_INBOUND_CUSTOMERS_URL is missing. Set it in .env',
      );
    }

    return _postSigned(
      url: _customersUrl,
      payload: {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
        if (externalId != null) 'external_id': externalId,
        if (tags != null) 'tags': tags,
      },
    );
  }

  /// Temporary WhatsApp/text send via inbound send-message endpoint.
  Future<RaqmeeResponse> sendMessage({
    required String phone,
    required String message,
    String? name,
    String? email,
    String? externalId,
  }) async {
    if (_sendMessageUrl.isEmpty) {
      throw StateError(
        'RAQMEE_INBOUND_SEND_MESSAGE_URL is missing. Set it in .env',
      );
    }

    // Normalize Qatar local numbers to E.164 digits without '+'.
    final normalizedPhone = _normalizePhone(phone);

    return _postSigned(
      url: _sendMessageUrl,
      payload: {
        'phone': normalizedPhone,
        'message': message,
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (externalId != null && externalId.isNotEmpty)
          'external_id': externalId,
      },
    );
  }

  /// Accepts `7xxxxxxx`, `9747xxxxxxx`, `+9747xxxxxxx` → `9747xxxxxxx`.
  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 8 && digits.startsWith('7')) {
      return '974$digits';
    }
    if (digits.startsWith('974') && digits.length >= 11) {
      return digits;
    }
    return digits;
  }

  void close() => _http.close();
}
