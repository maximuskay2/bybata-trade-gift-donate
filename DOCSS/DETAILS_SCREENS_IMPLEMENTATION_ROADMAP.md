# 🚀 Implementation Roadmap: Details Screens Refactor

## Priority Actions & Components to Create

---

## **PHASE 1: Shared Widget Foundation** (3-4 days)
*All components go to: `lib/core/widgets/`*

### Priority 1.1: `DetailCardGrid` ⭐⭐⭐ (Critical)
**File**: `lib/core/widgets/detail_card_grid.dart`

```dart
class DetailCardItem {
  final String label;      // "Condition", "Karma", "Progress"
  final String value;      // "Good", "50 pts", "45%"
  final IconData icon;     // Icons.inventory_2_rounded
  final Color? accentColor;
  final VoidCallback? onTap;
  final bool copyable;     // Copy value to clipboard on tap
  
  DetailCardItem({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.onTap,
    this.copyable = false,
  });
}

class DetailCardGrid extends StatelessWidget {
  final List<DetailCardItem> items;
  final int columns; // Responsive: 2 on small, 3 on normal, 4 on tablet
  
  // Handles: responsive grid, padding, spacing, tap feedback
  // No code duplication across Trade/Gift/Campaign
}
```

**Usage**:
```dart
DetailCardGrid(
  items: [
    DetailCardItem(
      label: "Condition",
      value: "Excellent",
      icon: Icons.stars_rounded,
      accentColor: Colors.green,
    ),
    // ... more items
  ],
)
```

**Replaces**:
- `TradeDetailsScreen._buildDetailsGrid()` (12 lines saved)
- `GiftDetailsScreen._buildSpecifications()` equivalent
- `CampaignDetailsScreen._buildProgressMetrics()` equivalent

---

### Priority 1.2: `CreatorCard` ⭐⭐⭐ (Critical)
**File**: `lib/core/widgets/creator_card.dart`

```dart
class CreatorCard extends StatelessWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final double rating;
  final bool isVerified;
  final String subtitle;  // "User Rating: 4.8 ★" or "Campaign Creator"
  final bool showButtons;
  
  final VoidCallback? onViewProfile;
  final VoidCallback? onMessage;
  final VoidCallback? onSecondaryAction; // Follow/Support
  final String? secondaryButtonLabel;    // "Follow", "Subscribe"
  
  // Layout: Horizontal (Avatar | Name/Rating | Buttons)
  // Touch targets: 44px minimum
  // Verified badge: Inline with name
}
```

**Replaces**:
- `TradeDetailsScreen._buildOwnerCard()` (50 lines)
- `GiftDetailsScreen._buildGiverInfo()` (40 lines)
- `CampaignDetailsScreen._buildCreatorSection()` (45 lines)

**Total savings**: 135 lines

---

### Priority 1.3: `MediaCarousel` ⭐⭐⭐ (Critical)
**File**: `lib/core/widgets/media_carousel.dart`

```dart
class MediaCarousel extends StatefulWidget {
  final List<String> mediaUrls;     // HTTP URLs or media keys
  final String heroTag;             // For Hero animation
  final bool showPageIndicator;
  final bool enableZoom;
  final bool autoResolveMediaKeys;  // Auto-fetch from storage API
  final Function(int)? onPageChanged;
  final Duration autoPlayDuration;  // null = no autoplay
  
  // Handles:
  // - Media key resolution (S3 key → signed URL)
  // - Image caching via CachedNetworkImage
  // - Error handling (placeholder image)
  // - Lazy loading for large galleries
  // - Responsive height
}
```

**Features**:
```dart
// Beautiful dot indicators (animated width change)
// Pinch-to-zoom support (optional)
// Hero animation on tap
// Automatic retry on network error
// Placeholder loading state
```

**Replaces**:
- `TradeDetailsScreen._build3DSliverAppBar()` image carousel (80 lines)
- `GiftDetailsScreen._buildSliverAppBar()` carousel (70 lines)
- `CampaignDetailsScreen` image carousel (60 lines)

**Total savings**: 210 lines

---

### Priority 1.4: `DetailsDataManager` ⭐⭐ (High)
**File**: `lib/core/managers/details_data_manager.dart`

```dart
class DetailsDataManager {
  final String itemId;
  final String itemType; // 'TRADE' | 'GIFT' | 'CAMPAIGN'
  
  final Map<String, dynamic> _mediaCache = {};
  final Map<String, dynamic> _commentsCache = {};
  final Map<String, dynamic> _similarCache = {};
  
  // Image Resolution
  Future<List<String>> resolveMediaUrls() async {
    // Handles: HTTP URLs, media keys, error states
    // Returns: List of resolved image URLs
    // Caches results in-memory
  }
  
  // Comments Loading (Paginated)
  Future<List<Map>> loadComments({
    int limit = 10,
    int offset = 0,
  }) async {
    // Paginates comments
    // Auto-formats timestamps
    // Caches on-disk
  }
  
  // Similar Items
  Future<List<dynamic>> loadSimilarItems({int limit = 8}) async {
    // Type-aware fetching (Trade → Trade, Gift → Gift, etc.)
    // Handles pagination
    // Caches results
  }
  
  // Error Handling Wrapper
  Future<T> fetchWithErrorHandling<T>(
    Future<T> Function() fn,
    String fallbackMessage,
  ) async {
    // Centralized error handling
    // User-friendly error messages
  }
}
```

**Replaces**:
- `TradeDetailsScreen._loadUserActiveTrades()` logic
- `TradeDetailsScreen._loadComments()` logic
- `TradeDetailsScreen._resolveTradeImages()` logic
- Similar methods in Gift & Campaign screens

**Total savings**: 150+ lines of duplicated loading logic

---

### Priority 1.5: `CommentsSection` ⭐⭐ (High)
**File**: `lib/core/widgets/comments_section.dart`

```dart
class CommentsSection extends StatefulWidget {
  final String itemId;
  final String itemType;           // 'TRADE' | 'GIFT' | 'CAMPAIGN'
  final bool allowCommenting;
  final int initialDisplayCount;   // Show 3, load more on tap
  final VoidCallback? onCommentAdded;
  
  // Handles:
  // - Real-time comment loading
  // - Lazy loading with "Load more" button
  // - Comment input field + validation
  // - Auto-refresh after posting
  // - Avatar generation
  // - Time formatting (2h, 1d, etc.)
}
```

**Replaces**:
- `TradeDetailsScreen._buildCommentsSection()` (50 lines)
- `GiftDetailsScreen._buildCommentsSection()` (50 lines)
- `CampaignDetailsScreen._buildCommentsSection()` (50 lines)

**Total savings**: 150 lines

---

### Priority 1.6: `ExpandableDescription` ⭐ (Medium)
**File**: `lib/core/widgets/expandable_description.dart`

```dart
class ExpandableDescription extends StatefulWidget {
  final String text;
  final int collapseLines;    // Default: 4
  final TextStyle? style;
  final bool autoExpand;      // true if < 150 chars
  final VoidCallback? onExpand;
  
  // Handles:
  // - Automatic line counting
  // - Smooth expand/collapse animation
  // - "Read more" / "Read less" button
  // - Text selection inside
}
```

**Replaces**:
- `TradeDetailsScreen._buildDescriptionCard()` logic (30 lines)
- `GiftDetailsScreen` description logic (30 lines)
- `CampaignDetailsScreen` story section (30 lines)

**Total savings**: 90 lines

---

### Priority 1.7: `CollapsibleSection` ⭐ (Medium)
**File**: `lib/core/widgets/collapsible_section.dart`

```dart
class CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget content;
  final int? itemCount;           // Shows count in title
  final bool defaultExpanded;     // Usually false
  final VoidCallback? onExpand;
  final String? learnMoreLink;
  
  // Handles:
  // - Smooth expand/collapse with animation
  // - Custom header with title + count
  // - "See all" / "View more" pattern
  // - Memory optimization (lazy build content)
}
```

**Replaces**:
- Manual expand/collapse logic scattered in all 3 screens
- Comments section collapse pattern
- Similar items section collapse pattern
- Updates section collapse pattern
- Donations list collapse pattern

**Total savings**: 200+ lines across screens

---

### Priority 1.8: `MetadataBadge` ⭐ (Low-Medium)
**File**: `lib/core/widgets/metadata_badge.dart`

```dart
enum MetadataBadgeType {
  verified(icon: Icons.verified, bgColor: Colors.blue),
  featured(icon: Icons.star, bgColor: Colors.amber),
  urgent(icon: Icons.priority_high, bgColor: Colors.red),
  popular(icon: Icons.trending_up, bgColor: Colors.green),
  saved(icon: Icons.bookmark, bgColor: Colors.purple),
}

class MetadataBadge extends StatelessWidget {
  final String label;
  final MetadataBadgeType type;
  
  // Consistent badge styling across all screens
}
```

**Replaces**:
- Scattered badge implementations
- Status indicators (Verified, Featured, etc.)

---

## **PHASE 2: Screen Refactors** (4-5 days)

### Priority 2.1: Refactor `TradeDetailsScreen`
**File**: `lib/features/trade/screens/trade_details_screen.dart`

**Checklist**:
- [ ] Replace `_buildOwnerCard()` with `CreatorCard`
- [ ] Replace `_build3DSliverAppBar()` carousel with `MediaCarousel`
- [ ] Replace `_buildDetailsGrid()` with `DetailCardGrid`
- [ ] Replace `_buildDescriptionCard()` with `ExpandableDescription`
- [ ] Replace `_buildCommentsSection()` with `CommentsSection`
- [ ] Create `DetailsDataManager` for all data loading
- [ ] Remove duplicate loading methods
- [ ] Add lazy loading for similar items
- [ ] Simplify state management (use manager instead)
- [ ] Test all user interactions

**Expected Line Reduction**: 848 → 450 lines (47% smaller)

---

### Priority 2.2: Refactor `GiftDetailsScreen`
**File**: `lib/features/gifting/screens/gift_details_screen.dart`

**Checklist**:
- [ ] Remove ambient orb animations OR move to `DetailsScreenAnimations` mixin
- [ ] Replace `_buildGiverInfo()` with `CreatorCard`
- [ ] Replace image carousel with `MediaCarousel`
- [ ] Replace gift stats section with `DetailCardGrid`
- [ ] Replace description with `ExpandableDescription`
- [ ] Replace comments with `CommentsSection`
- [ ] Move type-specific info to `CollapsibleSection`
- [ ] Use `DetailsDataManager` for all API calls
- [ ] Collapse similar gifts section by default
- [ ] Test gift claiming flow (critical!)

**Expected Line Reduction**: 1,526 → 700 lines (54% smaller)

---

### Priority 2.3: Refactor `CampaignDetailsScreen`
**File**: `lib/features/donations/screens/campaign_details_screen.dart`

**Checklist**:
- [ ] Replace tab-based layout with scrollable sections
- [ ] Use `CollapsibleSection` for: About, Updates, Donors, Gallery, Comments
- [ ] Replace creator section with `CreatorCard`
- [ ] Create reusable `ProgressIndicator` widget for donation progress
- [ ] Replace media carousel with `MediaCarousel`
- [ ] Replace comments with `CommentsSection`
- [ ] Use `DetailsDataManager` for all data loading
- [ ] Keep real-time updates functionality (provider-level)
- [ ] Test donation flow (critical!)
- [ ] Ensure "Post Update" flow still works for creator

**Expected Line Reduction**: 2,172 → 1,000 lines (54% smaller)

---

## **PHASE 3: Utilities & Validations** (2-3 days)

### Priority 3.1: Create Animation Mixin
**File**: `lib/core/mixins/details_screen_animations.dart`

```dart
mixin DetailsScreenAnimations on TickerProviderStateMixin {
  late AnimationController fadeController;
  late AnimationController slideController;
  
  void initDetailsAnimations() { ... }
  void disposeDetailsAnimations() { ... }
}
```

---

### Priority 3.2: Responsive Layout Helper
**File**: `lib/core/utils/responsive_utils.dart`

```dart
extension ResponsiveExtension on BuildContext {
  bool get isSmallPhone => width < 380;
  bool get isPhone => width < 540;
  bool get isTablet => width >= 540;
  
  double get horizontalPadding => isTablet ? 32 : (isPhone ? 16 : 12);
  int get detailCardColumns => isTablet ? 4 : (isPhone ? 3 : 2);
}
```

---

### Priority 3.3: Media Resolution Service
**File**: `lib/core/services/media_resolution_service.dart`

```dart
class MediaResolutionService {
  static Future<String> resolveMediaUrl(String input) async {
    // If HTTP URL → return as-is
    // If media key → fetch signed URL
    // If error → return placeholder
  }
  
  static Future<List<String>> resolveBatch(
    List<String> inputs,
    {int concurrency = 3}
  ) async {
    // Parallel resolution with concurrency limit
  }
}
```

---

### Priority 3.4: Testing & Validation
- [ ] Unit tests for `DetailCardGrid` responsive behavior
- [ ] Widget tests for `CreatorCard` with different states
- [ ] Integration tests for `MediaCarousel` loading
- [ ] Performance profiling: before vs after
- [ ] Screenshots on different devices (4", 5", 7")
- [ ] Dark mode testing
- [ ] RTL (right-to-left) testing

---

## **Timeline Estimate**

| Phase | Task | Days | Effort |
|-------|------|------|--------|
| 1 | Core Widgets | 3-4 | 24h |
| 2.1 | Trade Refactor | 1.5 | 12h |
| 2.2 | Gift Refactor | 1.5 | 12h |
| 2.3 | Campaign Refactor | 2 | 16h |
| 3 | Utils & Testing | 2-3 | 18h |
| **Total** | | **10-13** | **82h** |

---

## **Success Criteria**

✅ Code Quality:
- [ ] No duplicate code across screens
- [ ] All business logic preserved (100% feature parity)
- [ ] Type-safe (no dynamic casting)
- [ ] Zero breaking changes to APIs
- [ ] All comments in code preserved

✅ Performance:
- [ ] Time to interactive < 1.2s (was 2.8s)
- [ ] Comments lazy-load (first 3 only)
- [ ] Similar items load on scroll
- [ ] Memory usage reduced 25%+
- [ ] No jank in animations (60fps)

✅ User Experience:
- [ ] Consistent visual design across all screens
- [ ] Responsive on all phone sizes
- [ ] Touch targets ≥ 44x44 px
- [ ] Accessible (contrast ratio ≥ 4.5:1)
- [ ] Fast initial load

✅ Testing:
- [ ] All original flows still work
- [ ] No regression in core features
- [ ] User testing green-light
- [ ] A/B test metrics baseline

---

## **Risk Mitigation**

| Risk | Mitigation |
|------|-----------|
| **Breaking APIs** | Create new widgets, keep old screens as-is during transition |
| **Data Loss** | Full backup of original screens in `/backups/` |
| **Performance Regression** | Profiling after each major change |
| **Visual Inconsistency** | Design system doc + color/typography constants |
| **User Confusion** | Gradual rollout: 1 screen at a time |

---

## **Next Steps**

1. **Approve Plan**: Get stakeholder sign-off ✋
2. **Create Widgets**: Start Phase 1 in priority order
3. **Unit Test**: Test each widget in isolation
4. **Refactor Trade Screen**: Start Phase 2.1 as reference
5. **Iterate**: Trade → Gift → Campaign
6. **Validate**: Performance testing + user feedback
7. **Deploy**: Gradual rollout with feature flags

---

**Owner**: [Your Name]  
**Start Date**: [To Be Scheduled]  
**Target Completion**: [10-13 days from start]  
**Status**: Ready for execution 🚀
