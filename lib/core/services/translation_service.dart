import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// نتيجة ترجمة رسالة واحدة.
class MessageTranslation {
  final String text;

  /// لغة النص الأصلي ('ar' / 'en' / '').
  final String sourceLang;

  /// النص أصلاً بلغة المستخدم، فلا داعي لعرض ترجمة.
  final bool sameLanguage;

  const MessageTranslation({
    required this.text,
    this.sourceLang = '',
    this.sameLanguage = false,
  });
}

/// ترجمة عربي ↔ إنجليزي على الجهاز عبر Google ML Kit.
///
/// مجانية بالكامل وتعمل بدون إنترنت بعد تحميل موديل اللغة مرة واحدة،
/// ولا تحتاج أي مفتاح API أو سيرفر.
class TranslationService {
  TranslationService._();

  static final TranslationService instance = TranslationService._();

  /// المفتاح: "messageId|targetLang"
  final Map<String, MessageTranslation> _cache = {};
  final Set<String> _inFlight = {};

  final _modelManager = OnDeviceTranslatorModelManager();

  /// مترجم لكل اتجاه، يُنشأ عند أول استخدام.
  final Map<String, OnDeviceTranslator> _translators = {};

  /// تحميل الموديلات يحدث مرة واحدة؛ نحتفظ بالـ Future حتى لا يبدأ مرتين.
  Future<bool>? _modelsFuture;

  /// هل التحميل جارٍ الآن (لعرض مؤشر في الواجهة).
  bool _isPreparingModels = false;
  bool get isPreparingModels => _isPreparingModels;

  static final RegExp _arabicRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
  );
  static final RegExp _latinRegex = RegExp(r'[A-Za-z]');

  static const Map<String, TranslateLanguage> _languages = {
    'ar': TranslateLanguage.arabic,
    'en': TranslateLanguage.english,
  };

  String _key(String messageId, String targetLang) => '$messageId|$targetLang';

  /// يكتشف لغة النص: 'ar' أو 'en' أو null لو مش واضح
  /// (أرقام أو إيموجي فقط مثلاً).
  static String? guessLanguage(String text) {
    final arabicCount = _arabicRegex.allMatches(text).length;
    final latinCount = _latinRegex.allMatches(text).length;

    if (arabicCount == 0 && latinCount == 0) return null;
    return arabicCount >= latinCount ? 'ar' : 'en';
  }

  /// هل الرسالة تحتاج ترجمة للغة المطلوبة؟
  static bool needsTranslation(String text, String targetLang) {
    if (text.trim().isEmpty) return false;
    final source = guessLanguage(text);
    return source != null && source != targetLang;
  }

  MessageTranslation? cachedTranslation(String messageId, String targetLang) {
    final entry = _cache[_key(messageId, targetLang)];
    if (entry == null || entry.sameLanguage) return null;
    return entry;
  }

  bool isTranslating(String messageId, String targetLang) =>
      _inFlight.contains(_key(messageId, targetLang));

  /// يحمّل موديلي العربي والإنجليزي لو مش محمّلين (~30MB لكل لغة، مرة واحدة).
  Future<bool> _ensureModels() {
    return _modelsFuture ??= _downloadModels();
  }

  Future<bool> _downloadModels() async {
    _isPreparingModels = true;
    try {
      for (final language in _languages.values) {
        final code = language.bcpCode;
        if (await _modelManager.isModelDownloaded(code)) continue;

        // isWifiRequired: false حتى لا تتوقف الميزة على مستخدمي بيانات
        // الجوال. غيّرها لـ true لو عايز تحمي استهلاك الباقة.
        final ok = await _modelManager.downloadModel(
          code,
          isWifiRequired: false,
        );
        if (!ok) {
          debugPrint('TranslationService: failed to download model "$code"');
          _modelsFuture = null; // نسمح بإعادة المحاولة لاحقاً
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('TranslationService: model download error → $e');
      _modelsFuture = null;
      return false;
    } finally {
      _isPreparingModels = false;
    }
  }

  OnDeviceTranslator _translatorFor(String sourceLang, String targetLang) {
    final key = '$sourceLang>$targetLang';
    return _translators[key] ??= OnDeviceTranslator(
      sourceLanguage: _languages[sourceLang]!,
      targetLanguage: _languages[targetLang]!,
    );
  }

  /// يترجم ما يحتاج ترجمة من [messages] إلى [targetLang].
  ///
  /// يتجاهل تلقائياً ما هو مترجَم، أو قيد الترجمة، أو أصلاً بلغة المستخدم.
  /// يرجع `true` لو تغيّر الكاش (أي على الشاشة إعادة الرسم).
  Future<bool> translateMessages({
    required List<({String id, String text})> messages,
    required String targetLang,
  }) async {
    if (!_languages.containsKey(targetLang)) return false;

    final pending = <({String id, String text, String sourceLang})>[];

    for (final message in messages) {
      if (message.id.isEmpty) continue;

      final key = _key(message.id, targetLang);
      if (_cache.containsKey(key) || _inFlight.contains(key)) continue;

      final sourceLang = guessLanguage(message.text);
      if (sourceLang == null || sourceLang == targetLang) {
        // نخزنها كـ "نفس اللغة" حتى لا نفحصها في كل دورة polling
        _cache[key] = MessageTranslation(
          text: message.text,
          sourceLang: sourceLang ?? '',
          sameLanguage: true,
        );
        continue;
      }

      pending.add((id: message.id, text: message.text, sourceLang: sourceLang));
    }

    if (pending.isEmpty) return false;

    final keys = pending.map((m) => _key(m.id, targetLang)).toList();
    _inFlight.addAll(keys);

    try {
      if (!await _ensureModels()) return false;

      var changed = false;
      for (final message in pending) {
        try {
          final translator = _translatorFor(message.sourceLang, targetLang);
          final result = await translator.translateText(message.text);

          if (result.trim().isEmpty) continue;

          _cache[_key(message.id, targetLang)] = MessageTranslation(
            text: result,
            sourceLang: message.sourceLang,
          );
          changed = true;
        } catch (e) {
          debugPrint('TranslationService: failed on ${message.id} → $e');
        }
      }
      return changed;
    } finally {
      _inFlight.removeAll(keys);
    }
  }

  /// تُستدعى عند الخروج من الشات لتحرير موارد المترجمات.
  Future<void> dispose() async {
    for (final translator in _translators.values) {
      await translator.close();
    }
    _translators.clear();
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
