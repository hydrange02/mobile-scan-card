/// Card Utilities for Expiration & Security Validation
class CardUtils {
  /// Checks whether a card's MM/YY expiry date is in the past.
  static bool isCardExpired(dynamic expiryDate) {
    if (expiryDate == null) return false;
    final str = expiryDate.toString().trim();
    final parts = str.split('/');
    if (parts.length != 2) return false;

    final expMonth = int.tryParse(parts[0]);
    final expYearTwoDigits = int.tryParse(parts[1]);
    if (expMonth == null || expYearTwoDigits == null) return false;

    final fullExpYear = 2000 + expYearTwoDigits;
    final now = DateTime.now();

    if (fullExpYear < now.year) return true;
    if (fullExpYear == now.year && expMonth < now.month) return true;

    return false;
  }
}
