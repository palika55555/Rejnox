import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Potvrdenie akcie: na iOS natívny Cupertino alert, inde Material dialóg
/// v štýle appky. Vráti true len pri potvrdení.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Zrušiť',
  bool destructive = true,
}) async {
  final ios = Theme.of(context).platform == TargetPlatform.iOS;
  final Future<bool?> dialog;
  if (ios) {
    dialog = showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.dark),
        child: CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDefaultAction: !destructive,
              isDestructiveAction: destructive,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  } else {
    dialog = showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppColors.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
  return await dialog ?? false;
}
