import 'package:flutter/material.dart';

/// Shared design tokens for the HomeScreen V2 module.
///
/// The new home is built around flat matte content cards on top of a purple
/// ambient-orb chrome. Glass effects are intentionally limited to top chrome
/// (app bar / search pill / lock hints) so long scrollable content doesn't
/// pay the blur cost on every frame.
class HomeV2Tokens {
  HomeV2Tokens._();

  /// Corner radius for content cards (feed card, rail card).
  ///
  /// Kept at 20 for legacy non-listing cards. The new 3D Glass
  /// ListingCard uses [kListingCardRadius] (28) per the design brief.
  static const double kCardRadius = 20.0;

  /// Corner radius for the new 3D Glass ListingCard.
  static const double kListingCardRadius = 22.0;

  /// Aspect ratio for the new 3D Glass ListingCard (portrait 4:5).
  static const double kListingCardAspect = 4 / 5;

  /// Default fixed width for discovery sliders (Near you, Trending).
  static const double kListingCardWidth = 168.0;

  /// Portrait listing card height derived from [kListingCardWidth].
  static double get kListingCardHeight =>
      kListingCardWidth / kListingCardAspect;

  /// Active-campaign rail tile width (landscape 16:9 hero + footer).
  static const double kCampaignRailWidth = 188.0;

  /// ListView height for the active-campaign rail.
  static const double kCampaignRailHeight = 172.0;

  /// Gap before the first discovery slider (below search / create tiles).
  static const double kDiscoveryLeadGap = 16.0;

  /// Vertical gap between discovery sections (Near you → Trending → …).
  static const double kSliderGap = 20.0;

  /// Breathing room below each section's horizontal rail.
  static const double kSliderSectionTailGap = 4.0;

  /// Gap between a section title row and its slider (no extra chips).
  static const double kRailHeaderGap = 8.0;

  /// Gap between filter chips (or similar) and the slider below.
  static const double kSliderToRailGap = 8.0;

  /// Horizontal gap between cards inside a slider rail (Near you, Trending).
  static const double kRailItemGap = 6.0;

  /// Legacy alias — prefer [kDiscoveryLeadGap] / [kSliderGap].
  static const double kSectionGap = kDiscoveryLeadGap;

  /// Horizontal page padding. Matches the home app bar padding.
  static const double kHorizontalPad = 16.0;

  /// Brand purple anchor — same color as the native launch screen so
  /// cold-start -> splash -> home reads as one continuous surface.
  static const Color kBrandPurple = Color(0xFF5E35B1);

  /// Bottom clearance for scroll content above the command pill.
  static const double kBottomNavClearance = 24.0;
}
