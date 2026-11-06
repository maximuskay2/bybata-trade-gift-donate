/// Device / client signals sent on register and OAuth sign-in for currency + location.
class LocaleHints {
  final String? countryCode;
  final String? preferredFiatCurrency;
  final String? timezone;
  final String? location;

  const LocaleHints({
    this.countryCode,
    this.preferredFiatCurrency,
    this.timezone,
    this.location,
  });

  Map<String, dynamic> toJson() => {
        if (countryCode != null && countryCode!.isNotEmpty) 'countryCode': countryCode,
        if (preferredFiatCurrency != null && preferredFiatCurrency!.isNotEmpty)
          'preferredFiatCurrency': preferredFiatCurrency,
        if (timezone != null && timezone!.isNotEmpty) 'timezone': timezone,
        if (location != null && location!.isNotEmpty) 'location': location,
      };
}
