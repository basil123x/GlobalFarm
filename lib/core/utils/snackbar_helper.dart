import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';

enum SnackType { success, error, warning, info }

void showAppSnackbar(
  BuildContext context, {
  required String message,
  String title = '',
  SnackType type = SnackType.info,
}) {
  final contentType = switch (type) {
    SnackType.success => ContentType.success,
    SnackType.error => ContentType.failure,
    SnackType.warning => ContentType.warning,
    SnackType.info => ContentType.help,
  };

  final snackBar = SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    content: AwesomeSnackbarContent(
      title: title.isEmpty ? _defaultTitle(type) : title,
      message: message,
      contentType: contentType,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

String _defaultTitle(SnackType type) => switch (type) {
  SnackType.success => 'تم بنجاح',
  SnackType.error => 'خطأ',
  SnackType.warning => 'تنبيه',
  SnackType.info => 'معلومة',
};
