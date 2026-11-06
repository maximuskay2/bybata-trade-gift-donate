# 3D Shadow System for bYbata App

This document explains the consistent 3D shadow system implemented across the bYbata app to provide visual depth and modern aesthetics.

## Components

### 1. ShadowStyles (`lib/core/theme/shadow_styles.dart`)
A centralized class containing predefined shadow configurations:

- **lightShadow**: Subtle elevation for minor elements
- **mediumShadow**: Standard cards and content containers
- **heavyShadow**: Prominent cards, dialogs, and important elements
- **floatingShadow**: Floating action buttons and elevated elements
- **pressedShadow**: Reduced shadow for pressed/active states
- **glassShadow**: Special shadows for glass theme
- **coloredShadow()**: Dynamic colored shadows that adapt to theme colors

### 2. ShadowCard (`lib/core/widgets/shadow_card.dart`)
A flexible card widget with built-in 3D shadow effects:

#### Features:
- **Animated press effects**: Cards scale and shadow reduces when pressed
- **Theme awareness**: Automatically adjusts shadows based on light/dark/glass themes
- **Gradient support**: Can display gradients while maintaining shadows
- **Customizable intensity**: Choose from light, medium, heavy, or floating shadow levels

#### Basic Usage:
```dart
ShadowCard(
  child: Text('Your content here'),
  shadowIntensity: ShadowIntensity.medium,
  onTap: () => doSomething(),
)
```

### 3. Specialized Shadow Cards

#### ActionShadowCard
For interactive buttons and action items:
```dart
ActionShadowCard(
  onTap: () => handleAction(),
  child: Column(
    children: [
      Icon(Icons.add),
      Text('Add Item'),
    ],
  ),
)
```

#### StatsShadowCard
For displaying important information and statistics:
```dart
StatsShadowCard(
  gradient: LinearGradient(
    colors: [AppColors.primaryLight, AppColors.primary],
  ),
  child: Column(
    children: [
      Text('Balance'),
      Text('\$1,250'),
    ],
  ),
)
```

#### ListShadowCard
For list items and feed content:
```dart
ListShadowCard(
  onTap: () => showDetails(),
  child: ListTile(
    title: Text('Item Title'),
    subtitle: Text('Description'),
  ),
)
```

#### FloatingShadowCard
For dialogs and floating panels:
```dart
FloatingShadowCard(
  width: 300,
  height: 200,
  child: Text('Floating content'),
)
```

## Shadow Intensity Levels

1. **ShadowIntensity.light**: Minimal shadow for subtle elevation
2. **ShadowIntensity.medium**: Standard shadow for most cards
3. **ShadowIntensity.heavy**: Prominent shadow for important elements
4. **ShadowIntensity.floating**: Maximum shadow for floating elements

## Theme Integration

The shadow system automatically adapts to different themes:

- **Light Theme**: Full shadow opacity for maximum contrast
- **Dark Theme**: Reduced shadow opacity (60% of light theme)
- **Glass Theme**: Special glass morphism shadows with highlight effects

## Implementation Guidelines

### When to Use Each Shadow Level:

1. **Light Shadow**:
   - Secondary buttons
   - List items
   - Minor content cards
   - Step indicators

2. **Medium Shadow**:
   - Primary cards
   - Content containers
   - Action buttons
   - Feature showcases

3. **Heavy Shadow**:
   - Hero cards
   - Statistics displays
   - Welcome messages
   - Important announcements

4. **Floating Shadow**:
   - Floating action buttons
   - Dialogs and modals
   - Tooltips and overlays
   - Navigation drawers

### Best Practices:

1. **Consistency**: Use the same shadow level for similar UI elements
2. **Hierarchy**: Higher shadows = more important content
3. **Context**: Consider the background and surrounding elements
4. **Performance**: Limit the number of heavily shadowed elements on screen
5. **Accessibility**: Ensure shadows don't interfere with readability

## Animation Features

The shadow cards include built-in animations:

- **Scale Animation**: Slightly reduces size when pressed (98% scale)
- **Shadow Animation**: Reduces shadow intensity during press
- **Smooth Transitions**: 200ms duration with easeInOut curve

Disable animations by setting:
```dart
ShadowCard(
  animated: false,
  enablePressEffect: false,
  child: yourContent,
)
```

## Examples in the App

### Home Screen
- Welcome card: `StatsShadowCard` with gradient
- User stats: `ShadowCard` with medium intensity
- Quick actions: `ActionShadowCard` with press effects
- Activity items: `ListShadowCard` for feed content

### Trade Screen
- Header card: `StatsShadowCard` with gradient
- Category grid: `ActionShadowCard` for each category
- How-it-works steps: `ShadowCard` with light intensity
- Call-to-action: `ActionShadowCard` with primary color

### Wallet Screen
- Balance card: `StatsShadowCard` with purple gradient
- Quick actions: `ActionShadowCard` in a row
- Earning opportunities: `ListShadowCard` for each item
- How it works: `ShadowCard` with informational content

## Customization

For special cases, you can create custom shadows:

```dart
Container(
  decoration: BoxDecoration(
    boxShadow: ShadowStyles.coloredShadow(
      Colors.purple,
      opacity: 0.3,
    ),
  ),
  child: yourWidget,
)
```

Or use theme-aware shadows directly:
```dart
Container(
  decoration: BoxDecoration(
    boxShadow: ShadowStyles.getThemeAwareShadow(
      context,
      isGlass: themeProvider.isGlassTheme,
      intensity: ShadowIntensity.heavy,
    ),
  ),
  child: yourWidget,
)
```

## Visual Design Goals

The 3D shadow system achieves:

1. **Depth Perception**: Clear visual hierarchy through elevation
2. **Modern Aesthetics**: Contemporary card-based design language
3. **Interactive Feedback**: Visual response to user interactions
4. **Brand Consistency**: Uniform shadow treatment across all screens
5. **Platform Feel**: Native-feeling depth and materiality

This system ensures that all cards and elevated elements in the bYbata app have a consistent, professional, and engaging appearance while providing clear visual feedback for user interactions.