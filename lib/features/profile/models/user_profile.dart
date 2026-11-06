class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatar;
  final String? bio;
  final String? location;
  final DateTime? dateOfBirth;
  final String? occupation;
  final List<String> interests;
  final ProfileStats stats;
  final TrustScore trustScore;
  final VerificationStatus verification;
  final ProfileSettings settings;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.avatar,
    this.bio,
    this.location,
    this.dateOfBirth,
    this.occupation,
    this.interests = const [],
    required this.stats,
    required this.trustScore,
    required this.verification,
    required this.settings,
    required this.createdAt,
    required this.lastActiveAt,
  });

  String get displayName => '$firstName $lastName'.trim();

  /// Safely derive initials from the available name fields.
  ///
  /// Handles cases where lastName is empty or only a single display name
  /// is available, and never throws RangeError on empty strings.
  String get initials {
    final fn = firstName.trim();
    final ln = lastName.trim();

    // Case 1: both first and last names present
    if (fn.isNotEmpty && ln.isNotEmpty) {
      return '${fn[0]}${ln[0]}'.toUpperCase();
    }

    // Case 2: only first name present
    if (fn.isNotEmpty) {
      return fn.substring(0, 1).toUpperCase();
    }

    // Case 3: fall back to a best-effort split of displayName
    final display = displayName.trim();
    if (display.isNotEmpty) {
      final parts = display
          .split(RegExp(r'\s+'))
          .where((p) => p.trim().isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return display.substring(0, 1).toUpperCase();
    }

    // Final fallback when everything is empty
    return '?';
  }
  
  bool get isVerified => verification.status == VerificationStatusType.verified;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatar: json['avatar'],
      bio: json['bio'],
      location: json['location'],
      dateOfBirth: json['dateOfBirth'] != null 
        ? DateTime.parse(json['dateOfBirth'])
        : null,
      occupation: json['occupation'],
      interests: List<String>.from(json['interests'] ?? []),
      stats: ProfileStats.fromJson(json['stats'] ?? {}),
      trustScore: TrustScore.fromJson(json['trustScore'] ?? {}),
      verification: VerificationStatus.fromJson(json['verification'] ?? {}),
      settings: ProfileSettings.fromJson(json['settings'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      lastActiveAt: DateTime.parse(json['lastActiveAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'bio': bio,
      'location': location,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'occupation': occupation,
      'interests': interests,
      'stats': stats.toJson(),
      'trustScore': trustScore.toJson(),
      'verification': verification.toJson(),
      'settings': settings.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? avatar,
    String? bio,
    String? location,
    DateTime? dateOfBirth,
    String? occupation,
    List<String>? interests,
    ProfileStats? stats,
    TrustScore? trustScore,
    VerificationStatus? verification,
    ProfileSettings? settings,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      occupation: occupation ?? this.occupation,
      interests: interests ?? this.interests,
      stats: stats ?? this.stats,
      trustScore: trustScore ?? this.trustScore,
      verification: verification ?? this.verification,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}

class ProfileStats {
  final int totalTrades;
  final int successfulTrades;
  final int totalGifts;
  final int totalDonations;
  final int totalCommunities;
  final int totalFollowers;
  final int totalFollowing;
  final int totalPosts;
  final int totalLikes;
  final double averageRating;
  final int totalReviews;

  ProfileStats({
    this.totalTrades = 0,
    this.successfulTrades = 0,
    this.totalGifts = 0,
    this.totalDonations = 0,
    this.totalCommunities = 0,
    this.totalFollowers = 0,
    this.totalFollowing = 0,
    this.totalPosts = 0,
    this.totalLikes = 0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
  });

  double get tradeSuccessRate => totalTrades > 0 ? (successfulTrades / totalTrades) * 100 : 0.0;

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      totalTrades: json['totalTrades'] ?? 0,
      successfulTrades: json['successfulTrades'] ?? 0,
      totalGifts: json['totalGifts'] ?? 0,
      totalDonations: json['totalDonations'] ?? 0,
      totalCommunities: json['totalCommunities'] ?? 0,
      totalFollowers: json['totalFollowers'] ?? 0,
      totalFollowing: json['totalFollowing'] ?? 0,
      totalPosts: json['totalPosts'] ?? 0,
      totalLikes: json['totalLikes'] ?? 0,
      averageRating: (json['averageRating'] ?? 0.0).toDouble(),
      totalReviews: json['totalReviews'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTrades': totalTrades,
      'successfulTrades': successfulTrades,
      'totalGifts': totalGifts,
      'totalDonations': totalDonations,
      'totalCommunities': totalCommunities,
      'totalFollowers': totalFollowers,
      'totalFollowing': totalFollowing,
      'totalPosts': totalPosts,
      'totalLikes': totalLikes,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
    };
  }
}

class TrustScore {
  final double score;
  final int level;
  final List<TrustBadge> badges;
  final DateTime lastUpdated;

  TrustScore({
    this.score = 0.0,
    this.level = 1,
    this.badges = const [],
    required this.lastUpdated,
  });

  String get levelName {
    if (score >= 4.8) return 'Trusted Expert';
    if (score >= 4.5) return 'Highly Trusted';
    if (score >= 4.0) return 'Trusted';
    if (score >= 3.5) return 'Reliable';
    return 'New Member';
  }

  factory TrustScore.fromJson(Map<String, dynamic> json) {
    return TrustScore(
      score: (json['score'] ?? 0.0).toDouble(),
      level: json['level'] ?? 1,
      badges: (json['badges'] as List<dynamic>? ?? [])
          .map((badge) => TrustBadge.fromJson(badge))
          .toList(),
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'level': level,
      'badges': badges.map((badge) => badge.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class TrustBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final DateTime earnedAt;

  TrustBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.earnedAt,
  });

  factory TrustBadge.fromJson(Map<String, dynamic> json) {
    return TrustBadge(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      earnedAt: DateTime.parse(json['earnedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'earnedAt': earnedAt.toIso8601String(),
    };
  }
}

enum VerificationStatusType {
  unverified,
  pending,
  verified,
  rejected,
}

class VerificationStatus {
  final VerificationStatusType status;
  final List<VerificationType> completedVerifications;
  final DateTime? verifiedAt;
  final String? rejectionReason;

  VerificationStatus({
    this.status = VerificationStatusType.unverified,
    this.completedVerifications = const [],
    this.verifiedAt,
    this.rejectionReason,
  });

  /// Parse from API profile (kycStatus: NOT_VERIFIED, PENDING, VERIFIED, REJECTED)
  static VerificationStatus fromKycStatus(String? kycStatus, {String? rejectionReason}) {
    final s = (kycStatus ?? 'NOT_VERIFIED').toUpperCase();
    return VerificationStatus(
      status: s == 'VERIFIED'
          ? VerificationStatusType.verified
          : s == 'PENDING'
              ? VerificationStatusType.pending
              : s == 'REJECTED'
                  ? VerificationStatusType.rejected
                  : VerificationStatusType.unverified,
      completedVerifications: s == 'VERIFIED'
          ? [
              VerificationType.identity,
              VerificationType.phone,
              VerificationType.email,
            ]
          : const [],
      verifiedAt: s == 'VERIFIED' ? DateTime.now() : null,
      rejectionReason: rejectionReason,
    );
  }

  /// Build from `/v1/users/me` profile.verification or related flags.
  static VerificationStatus fromApiProfile({
    Map<String, dynamic>? verification,
    String? kycStatus,
    String? kycNote,
    bool emailVerified = false,
    bool phoneVerified = false,
  }) {
    if (verification != null && verification.isNotEmpty) {
      return VerificationStatus.fromJson(verification);
    }
    final completed = <VerificationType>[];
    if (emailVerified) completed.add(VerificationType.email);
    if (phoneVerified) completed.add(VerificationType.phone);
    final base = fromKycStatus(kycStatus, rejectionReason: kycNote);
    if (base.status == VerificationStatusType.verified) return base;
    return VerificationStatus(
      status: base.status,
      completedVerifications: completed,
      verifiedAt: base.verifiedAt,
      rejectionReason: base.rejectionReason,
    );
  }

  bool isStepComplete(VerificationType type) =>
      completedVerifications.contains(type);

  factory VerificationStatus.fromJson(Map<String, dynamic> json) {
    final nestedKyc = json['kycStatus'] as String?;
    if (nestedKyc != null && json['completedVerifications'] == null) {
      return VerificationStatus.fromKycStatus(
        nestedKyc,
        rejectionReason: json['kycNote'] as String? ?? json['rejectionReason'] as String?,
      );
    }

    final statusRaw = (json['status'] as String?) ?? 'unverified';
    final completedRaw = json['completedVerifications'] as List<dynamic>? ?? [];
    final completed = completedRaw
        .map((type) => _parseVerificationType(type))
        .whereType<VerificationType>()
        .toList();

    if (json['emailVerified'] == true &&
        !completed.contains(VerificationType.email)) {
      completed.add(VerificationType.email);
    }
    if (json['phoneVerified'] == true &&
        !completed.contains(VerificationType.phone)) {
      completed.add(VerificationType.phone);
    }

    final docs = json['documents'];
    if (docs is List) {
      for (final doc in docs) {
        if (doc is Map) {
          final type = _parseVerificationType(doc['type']);
          if (type != null && !completed.contains(type)) {
            completed.add(type);
          }
        }
      }
    }

    return VerificationStatus(
      status: VerificationStatusType.values.firstWhere(
        (e) => e.toString() == 'VerificationStatusType.$statusRaw',
        orElse: () => VerificationStatusType.unverified,
      ),
      completedVerifications: completed,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'].toString())
          : null,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  static VerificationType? _parseVerificationType(dynamic type) {
    final raw = type?.toString() ?? '';
    if (raw.isEmpty) return null;
    final normalized = raw.contains('.') ? raw.split('.').last : raw;
    for (final v in VerificationType.values) {
      if (v.toString().split('.').last == normalized) return v;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.toString().split('.').last,
      'completedVerifications': completedVerifications
          .map((type) => type.toString().split('.').last)
          .toList(),
      'verifiedAt': verifiedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
    };
  }
}

enum VerificationType {
  identity,
  phone,
  email,
  address,
  social,
}

class ProfileSettings {
  final bool isProfilePublic;
  final bool showEmail;
  final bool showPhone;
  final bool showLocation;
  final bool allowDirectMessages;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool marketingEmails;
  final String language;
  final String currency;
  final String timezone;
  final double watermarkOpacity; // 0.0 to 1.0, where 1.0 = fully visible
  final bool enableWatermark; // Allow users to disable watermarks entirely

  ProfileSettings({
    this.isProfilePublic = true,
    this.showEmail = false,
    this.showPhone = false,
    this.showLocation = true,
    this.allowDirectMessages = true,
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.marketingEmails = false,
    this.language = 'en',
    this.currency = 'NGN',
    this.timezone = 'UTC',
    this.watermarkOpacity = 1.0,
    this.enableWatermark = true,
  });

  factory ProfileSettings.fromJson(Map<String, dynamic> json) {
    return ProfileSettings(
      isProfilePublic: json['isProfilePublic'] ?? true,
      showEmail: json['showEmail'] ?? false,
      showPhone: json['showPhone'] ?? false,
      showLocation: json['showLocation'] ?? true,
      allowDirectMessages: json['allowDirectMessages'] ?? true,
      emailNotifications: json['emailNotifications'] ?? true,
      pushNotifications: json['pushNotifications'] ?? true,
      marketingEmails: json['marketingEmails'] ?? false,
      language: json['language'] ?? 'en',
      currency: json['currency'] ?? 'NGN',
      timezone: json['timezone'] ?? 'UTC',
      watermarkOpacity: (json['watermarkOpacity'] as num?)?.toDouble() ?? 1.0,
      enableWatermark: json['enableWatermark'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isProfilePublic': isProfilePublic,
      'showEmail': showEmail,
      'showPhone': showPhone,
      'showLocation': showLocation,
      'allowDirectMessages': allowDirectMessages,
      'emailNotifications': emailNotifications,
      'pushNotifications': pushNotifications,
      'marketingEmails': marketingEmails,
      'language': language,
      'currency': currency,
      'timezone': timezone,
      'watermarkOpacity': watermarkOpacity,
      'enableWatermark': enableWatermark,
    };
  }

  ProfileSettings copyWith({
    bool? isProfilePublic,
    bool? showEmail,
    bool? showPhone,
    bool? showLocation,
    bool? allowDirectMessages,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? marketingEmails,
    String? language,
    String? currency,
    String? timezone,
    double? watermarkOpacity,
    bool? enableWatermark,
  }) {
    return ProfileSettings(
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      showLocation: showLocation ?? this.showLocation,
      allowDirectMessages: allowDirectMessages ?? this.allowDirectMessages,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      marketingEmails: marketingEmails ?? this.marketingEmails,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      enableWatermark: enableWatermark ?? this.enableWatermark,
    );
  }
}