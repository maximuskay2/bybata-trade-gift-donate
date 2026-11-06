/// Canonical marketing / share / legal URLs (https://bybata.com).
class WebLinksConfig {
  WebLinksConfig._();

  static const String host = 'bybata.com';
  static const String baseUrl = 'https://bybata.com';

  static Uri uri(String path, {Map<String, String>? query}) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri(
      scheme: 'https',
      host: host,
      path: normalized,
      queryParameters: query?.isNotEmpty == true ? query : null,
    );
  }

  static String link(String path, {Map<String, String>? query}) =>
      uri(path, query: query).toString();

  static String tradeLink(String id) => link('/trade/$id');
  static String giftLink(String id) => link('/gift/$id');
  static String campaignLink(String id) => link('/campaign/$id');
  static String donationLink(String id) => link('/donation/$id');

  /// iOS App Store compliance — support completed in Safari, not in-app.
  /// Uses direct HTML file so it works even if pretty-url rewrite is missing.
  static String campaignSupportLink(
    String id, {
    String? accessToken,
    String? email,
    String? displayName,
    String? title,
    double? raisedAmount,
    double? goalAmount,
    String? storySnippet,
  }) {
    final query = <String, String>{'id': id.trim()};
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      query['token'] = accessToken.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      query['email'] = email.trim();
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      query['name'] = displayName.trim();
    }
    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      query['title'] = trimmedTitle;
    }
    if (raisedAmount != null && raisedAmount >= 0) {
      query['raised'] = raisedAmount.round().toString();
    }
    if (goalAmount != null && goalAmount > 0) {
      query['goal'] = goalAmount.round().toString();
    }
    final story = storySnippet?.trim();
    if (story != null && story.isNotEmpty) {
      query['story'] = story.length > 180 ? '${story.substring(0, 177)}...' : story;
    }
    return link('/campaign-support.html', query: query);
  }
  static String profileLink(String slug) => link('/profile/$slug');
  static String inviteLink(String code) => link('/invite/$code');
  static String requestLink(String id) => link('/request/$id');

  static const String termsUrl = '$baseUrl/terms.html';
  static const String privacyUrl = '$baseUrl/privacy.html';

  /// Email / CTA links that use the open-app router on web.
  static String openAppLink({String? path}) {
    if (path == null || path.isEmpty) return '$baseUrl/open-app';
    return '$baseUrl/open-app?path=${Uri.encodeComponent(path)}';
  }
}
