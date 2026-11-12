/// Chyba, ktorá sa má vrátiť klientovi ako JSON s daným HTTP kódom.
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);

  final int status;

  /// Strojovo čitateľný kód (napr. "invalid_credentials").
  final String code;

  /// Správa pre používateľa.
  final String message;

  @override
  String toString() => 'ApiException($status, $code)';
}
