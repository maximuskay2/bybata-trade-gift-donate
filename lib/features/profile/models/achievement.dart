enum AchievementType {
  trade,
  gift,
  donation,
  community,
  karma,
  social,
  milestone,
  special,
}

enum AchievementRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final AchievementType type;
  final AchievementRarity rarity;
  final int karmaReward;
  final Map<String, dynamic> requirements;
  final bool isHidden;
  final DateTime? unlockedAt;
  final double? progress;
  final String? category;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    this.rarity = AchievementRarity.common,
    this.karmaReward = 0,
    this.requirements = const {},
    this.isHidden = false,
    this.unlockedAt,
    this.progress,
    this.category,
  });

  bool get isUnlocked => unlockedAt != null;
  
  String get typeDisplayName {
    switch (type) {
      case AchievementType.trade:
        return 'Trade';
      case AchievementType.gift:
        return 'Gift';
      case AchievementType.donation:
        return 'Donation';
      case AchievementType.community:
        return 'Community';
      case AchievementType.karma:
        return 'KARMA';
      case AchievementType.social:
        return 'Social';
      case AchievementType.milestone:
        return 'Milestone';
      case AchievementType.special:
        return 'Special';
    }
  }

  String get rarityDisplayName {
    switch (rarity) {
      case AchievementRarity.common:
        return 'Common';
      case AchievementRarity.uncommon:
        return 'Uncommon';
      case AchievementRarity.rare:
        return 'Rare';
      case AchievementRarity.epic:
        return 'Epic';
      case AchievementRarity.legendary:
        return 'Legendary';
    }
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      type: AchievementType.values.firstWhere(
        (e) => e.toString() == 'AchievementType.${json['type']}',
        orElse: () => AchievementType.milestone,
      ),
      rarity: AchievementRarity.values.firstWhere(
        (e) => e.toString() == 'AchievementRarity.${json['rarity']}',
        orElse: () => AchievementRarity.common,
      ),
      karmaReward: json['karmaReward'] ?? 0,
      requirements: Map<String, dynamic>.from(json['requirements'] ?? {}),
      isHidden: json['isHidden'] ?? false,
      unlockedAt: json['unlockedAt'] != null 
        ? DateTime.parse(json['unlockedAt'])
        : null,
      progress: json['progress']?.toDouble(),
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'type': type.toString().split('.').last,
      'rarity': rarity.toString().split('.').last,
      'karmaReward': karmaReward,
      'requirements': requirements,
      'isHidden': isHidden,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'progress': progress,
      'category': category,
    };
  }

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    AchievementType? type,
    AchievementRarity? rarity,
    int? karmaReward,
    Map<String, dynamic>? requirements,
    bool? isHidden,
    DateTime? unlockedAt,
    double? progress,
    String? category,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      karmaReward: karmaReward ?? this.karmaReward,
      requirements: requirements ?? this.requirements,
      isHidden: isHidden ?? this.isHidden,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      category: category ?? this.category,
    );
  }
}

class UserAchievement {
  final String userId;
  final Achievement achievement;
  final DateTime unlockedAt;
  final Map<String, dynamic>? metadata;

  UserAchievement({
    required this.userId,
    required this.achievement,
    required this.unlockedAt,
    this.metadata,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      userId: json['userId'] ?? '',
      achievement: Achievement.fromJson(json['achievement'] ?? {}),
      unlockedAt: DateTime.parse(json['unlockedAt'] ?? DateTime.now().toIso8601String()),
      metadata: json['metadata'] != null 
        ? Map<String, dynamic>.from(json['metadata'])
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'achievement': achievement.toJson(),
      'unlockedAt': unlockedAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}