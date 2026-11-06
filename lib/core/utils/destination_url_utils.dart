/// Normalizes and validates creator-supplied ad destination links.
class DestinationUrlUtils {
  static String? normalize(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    var candidate = trimmed;
    if (!candidate.toLowerCase().startsWith('http://') &&
        !candidate.toLowerCase().startsWith('https://')) {
      candidate = 'https://$candidate';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return uri.toString();
  }

  static String? validationMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Destination link is required';
    }
    if (normalize(raw) == null) {
      return 'Enter a valid link (e.g. https://yoursite.com)';
    }
    return null;
  }
}
