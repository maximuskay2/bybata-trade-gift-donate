class AdItem {
  final String id;
  final String kind;
  final String title;
  final String? description;
  final String mediaType;
  final List<String> mediaKeys;
  final String? videoKey;
  final String? thumbnailUrl;
  final String? placementKey;
  final String? destinationUrl;
  final String? referenceType;
  final String? referenceId;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  const AdItem({
    required this.id,
    this.kind = 'schedule',
    required this.title,
    this.description,
    this.mediaType = 'IMAGE',
    this.mediaKeys = const [],
    this.videoKey,
    this.thumbnailUrl,
    this.placementKey,
    this.destinationUrl,
    this.referenceType,
    this.referenceId,
    this.scheduledStart,
    this.scheduledEnd,
  });

  bool get isBoost => kind == 'boost';
  bool get hasListingReference =>
      referenceId != null && referenceId!.trim().isNotEmpty;
  bool get isVideo =>
      mediaType.toUpperCase() == 'VIDEO' && (videoKey?.isNotEmpty ?? false);

  /// Storage key for image ads, or video key when media type is video.
  String? get primaryMediaKey {
    if (isVideo) {
      final vk = videoKey?.trim();
      if (vk != null && vk.isNotEmpty) return vk;
    }
    for (final k in mediaKeys) {
      final trimmed = k.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static List<String> _parseMediaKeys(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return const [];
    return [s];
  }

  factory AdItem.fromJson(Map<String, dynamic> json) {
    return AdItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'schedule',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      mediaType: json['mediaType']?.toString() ?? 'IMAGE',
      mediaKeys: _parseMediaKeys(json['mediaKeys']),
      videoKey: json['videoKey']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      placementKey: json['placementKey']?.toString(),
      destinationUrl: json['destinationUrl']?.toString(),
      referenceType: json['referenceType']?.toString(),
      referenceId: json['referenceId']?.toString(),
      scheduledStart: json['scheduledStart'] != null
          ? DateTime.tryParse(json['scheduledStart'].toString())
          : null,
      scheduledEnd: json['scheduledEnd'] != null
          ? DateTime.tryParse(json['scheduledEnd'].toString())
          : null,
    );
  }
}
