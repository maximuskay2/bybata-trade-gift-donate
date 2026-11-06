import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool isVerified;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool marketingEmails;
  final String language;
  final String currency;
  final bool timeFormat24h;
  final bool enableAnimations;
  final bool hapticFeedback;
  final bool isProfilePublic;
  final bool showEmail;
  final bool showPhone;
  final bool showLocation;
  final bool allowDirectMessages;
  final bool showOnlineStatus;
  final bool twoFactorEnabled;
  final bool autoSync;
  final bool debugMode;
  final bool highContrast;
  final double textScale;
  final bool reduceMotion;
  final String themeMode;
  final bool useDynamicColors;
  final bool compactMode;
  final bool showAnimations;
  final bool analyticsEnabled;
  final bool crashReportsEnabled;
  final bool readReceipts;
  final bool biometricAuth;
  final bool developerMode;
  final String region;

  const AppSettings({
    this.isVerified = false,
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.marketingEmails = false,
    this.language = 'en',
    this.currency = 'NGN',
    this.timeFormat24h = false,
    this.enableAnimations = true,
    this.hapticFeedback = true,
    this.isProfilePublic = true,
    this.showEmail = false,
    this.showPhone = false,
    this.showLocation = true,
    this.allowDirectMessages = true,
    this.showOnlineStatus = true,
    this.twoFactorEnabled = false,
    this.autoSync = true,
    this.debugMode = false,
    this.highContrast = false,
    this.textScale = 1.0,
    this.reduceMotion = false,
    this.themeMode = 'system',
    this.useDynamicColors = true,
    this.compactMode = false,
    this.showAnimations = true,
    this.analyticsEnabled = true,
    this.crashReportsEnabled = true,
    this.readReceipts = true,
    this.biometricAuth = false,
    this.developerMode = false,
    this.region = 'United States',
  });

  AppSettings copyWith({
    bool? isVerified,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? marketingEmails,
    String? language,
    String? currency,
    bool? timeFormat24h,
    bool? enableAnimations,
    bool? hapticFeedback,
    bool? isProfilePublic,
    bool? showEmail,
    bool? showPhone,
    bool? showLocation,
    bool? allowDirectMessages,
    bool? showOnlineStatus,
    bool? twoFactorEnabled,
    bool? autoSync,
    bool? debugMode,
    bool? highContrast,
    double? textScale,
    bool? reduceMotion,
    String? themeMode,
    bool? useDynamicColors,
    bool? compactMode,
    bool? showAnimations,
    bool? analyticsEnabled,
    bool? crashReportsEnabled,
    bool? readReceipts,
    bool? biometricAuth,
    bool? developerMode,
    String? region,
  }) {
    return AppSettings(
      isVerified: isVerified ?? this.isVerified,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      marketingEmails: marketingEmails ?? this.marketingEmails,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      timeFormat24h: timeFormat24h ?? this.timeFormat24h,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      isProfilePublic: isProfilePublic ?? this.isProfilePublic,
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      showLocation: showLocation ?? this.showLocation,
      allowDirectMessages: allowDirectMessages ?? this.allowDirectMessages,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      autoSync: autoSync ?? this.autoSync,
      debugMode: debugMode ?? this.debugMode,
      highContrast: highContrast ?? this.highContrast,
      textScale: textScale ?? this.textScale,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      themeMode: themeMode ?? this.themeMode,
      useDynamicColors: useDynamicColors ?? this.useDynamicColors,
      compactMode: compactMode ?? this.compactMode,
      showAnimations: showAnimations ?? this.showAnimations,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportsEnabled: crashReportsEnabled ?? this.crashReportsEnabled,
      readReceipts: readReceipts ?? this.readReceipts,
      biometricAuth: biometricAuth ?? this.biometricAuth,
      developerMode: developerMode ?? this.developerMode,
      region: region ?? this.region,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('settings_pushNotifications', pushNotifications),
      prefs.setBool('settings_emailNotifications', emailNotifications),
      prefs.setBool('settings_marketingEmails', marketingEmails),
      prefs.setString('settings_language', language),
      prefs.setString('settings_currency', currency),
      prefs.setBool('settings_timeFormat24h', timeFormat24h),
      prefs.setBool('settings_enableAnimations', enableAnimations),
      prefs.setBool('settings_hapticFeedback', hapticFeedback),
      prefs.setBool('settings_isProfilePublic', isProfilePublic),
      prefs.setBool('settings_showEmail', showEmail),
      prefs.setBool('settings_showPhone', showPhone),
      prefs.setBool('settings_showLocation', showLocation),
      prefs.setBool('settings_allowDirectMessages', allowDirectMessages),
      prefs.setBool('settings_showOnlineStatus', showOnlineStatus),
      prefs.setBool('settings_autoSync', autoSync),
      prefs.setBool('settings_debugMode', debugMode),
      prefs.setBool('settings_highContrast', highContrast),
      prefs.setDouble('settings_textScale', textScale),
      prefs.setBool('settings_reduceMotion', reduceMotion),
      prefs.setString('settings_themeMode', themeMode),
      prefs.setBool('settings_useDynamicColors', useDynamicColors),
      prefs.setBool('settings_compactMode', compactMode),
      prefs.setBool('settings_showAnimations', showAnimations),
      prefs.setBool('settings_analyticsEnabled', analyticsEnabled),
      prefs.setBool('settings_crashReportsEnabled', crashReportsEnabled),
      prefs.setBool('settings_readReceipts', readReceipts),
      prefs.setBool('settings_biometricAuth', biometricAuth),
      prefs.setBool('settings_developerMode', developerMode),
      prefs.setString('settings_region', region),
    ]);
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      pushNotifications: prefs.getBool('settings_pushNotifications') ?? true,
      emailNotifications: prefs.getBool('settings_emailNotifications') ?? true,
      marketingEmails: prefs.getBool('settings_marketingEmails') ?? false,
      language: prefs.getString('settings_language') ?? 'en',
      currency: prefs.getString('settings_currency') ?? 'NGN',
      timeFormat24h: prefs.getBool('settings_timeFormat24h') ?? false,
      enableAnimations: prefs.getBool('settings_enableAnimations') ?? true,
      hapticFeedback: prefs.getBool('settings_hapticFeedback') ?? true,
      isProfilePublic: prefs.getBool('settings_isProfilePublic') ?? true,
      showEmail: prefs.getBool('settings_showEmail') ?? false,
      showPhone: prefs.getBool('settings_showPhone') ?? false,
      showLocation: prefs.getBool('settings_showLocation') ?? true,
      allowDirectMessages: prefs.getBool('settings_allowDirectMessages') ?? true,
      showOnlineStatus: prefs.getBool('settings_showOnlineStatus') ?? true,
      autoSync: prefs.getBool('settings_autoSync') ?? true,
      debugMode: prefs.getBool('settings_debugMode') ?? false,
      highContrast: prefs.getBool('settings_highContrast') ?? false,
      textScale: prefs.getDouble('settings_textScale') ?? 1.0,
      reduceMotion: prefs.getBool('settings_reduceMotion') ?? false,
      themeMode: prefs.getString('settings_themeMode') ?? 'system',
      useDynamicColors: prefs.getBool('settings_useDynamicColors') ?? true,
      compactMode: prefs.getBool('settings_compactMode') ?? false,
      showAnimations: prefs.getBool('settings_showAnimations') ?? true,
      analyticsEnabled: prefs.getBool('settings_analyticsEnabled') ?? true,
      crashReportsEnabled: prefs.getBool('settings_crashReportsEnabled') ?? true,
      readReceipts: prefs.getBool('settings_readReceipts') ?? true,
      biometricAuth: prefs.getBool('settings_biometricAuth') ?? false,
      developerMode: prefs.getBool('settings_developerMode') ?? false,
      region: prefs.getString('settings_region') ?? 'United States',
    );
  }

  static AppSettings loadFromStorage() {
    return const AppSettings(); // Simplified for now
  }
}
