/// Display / preference currencies shown in Settings and wallet UI.
///
/// Funding gateways may support additional codes via [WalletProvider.getSupportedFiatCurrencies];
/// this list is what users can pick for app display and profile currency.
class CurrencyOption {
  final String code;
  final String name;
  final String symbol;

  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
  });

  String get pickerLabel => '$code — $name';
}

class CurrencyConstants {
  CurrencyConstants._();

  /// Ordered with NGN first (primary market / Paystack & Flutterwave).
  static const List<CurrencyOption> displayCurrencies = [
    CurrencyOption(code: 'NGN', name: 'Nigerian Naira', symbol: '₦'),
    CurrencyOption(code: 'USD', name: 'US Dollar', symbol: '\$'),
    CurrencyOption(code: 'EUR', name: 'Euro', symbol: '€'),
    CurrencyOption(code: 'GBP', name: 'British Pound', symbol: '£'),
    CurrencyOption(code: 'GHS', name: 'Ghanaian Cedi', symbol: '₵'),
    CurrencyOption(code: 'KES', name: 'Kenyan Shilling', symbol: 'KES'),
    CurrencyOption(code: 'ZAR', name: 'South African Rand', symbol: 'R'),
    CurrencyOption(code: 'JPY', name: 'Japanese Yen', symbol: '¥'),
    CurrencyOption(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$'),
  ];

  static List<String> get displayCurrencyCodes =>
      displayCurrencies.map((c) => c.code).toList();

  static CurrencyOption? optionFor(String code) {
    final upper = code.toUpperCase();
    for (final o in displayCurrencies) {
      if (o.code == upper) return o;
    }
    return null;
  }

  static String labelFor(String code) =>
      optionFor(code)?.pickerLabel ?? code.toUpperCase();

  static String symbolFor(String code) =>
      optionFor(code)?.symbol ?? code.toUpperCase();
}
