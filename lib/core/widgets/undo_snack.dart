import 'package:flutter/material.dart';

/// Ako dlho je „Späť“ k dispozícii.
const undoWindow = Duration(seconds: 4);

/// Ukáže „[message] · Späť“ a počká, kým lišta zmizne.
/// Vráti true, ak používateľ ťukol na Späť.
Future<bool> showUndoSnack(BuildContext context, String message) async {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  var undone = false;
  final bar = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: undoWindow,
      persist: false,
      action: SnackBarAction(label: 'Späť', onPressed: () => undone = true),
    ),
  );
  await bar.closed;
  return undone;
}
