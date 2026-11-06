# Safe Areas for ByBata 3D Glass UI

Handling Safe Areas in immersive, edge-to-edge glass UIs requires **selective padding** rather than wrapping the whole screen in `SafeArea()`. A full-screen `SafeArea` creates ugly solid-colored bands at the notch and home indicator, ruining the 3D aesthetic.

## 5 Rules for 3D Glass Screens

### 1. Scaffold Configuration

Never wrap the entire Scaffold body in `SafeArea`. Use these flags:

```dart
Scaffold(
  extendBodyBehindAppBar: true,
  extendBody: true,  // Crucial for bottom glass overlays
  backgroundColor: const Color(0xFFE8EEF2),  // or dark mode equivalent
  // ...
)
```

### 2. Backgrounds Ignore Safe Areas

Ambient glowing orbs (`Container` with `BoxShape.circle` and heavy `blurRadius`) should sit at the bottom of the `Stack` with **no** Safe Area constraints. Let them float off the edges.

### 3. Glass App Bar Handles the Top

Use `PreferredSize` with `ClipRRect` > `BackdropFilter` > `AppBar`. Flutter's AppBar automatically calculates the top Safe Area (notch), while the frosted glass bleeds to the bezel.

```dart
appBar: PreferredSize(
  preferredSize: const Size.fromHeight(kToolbarHeight),
  child: ClipRRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: AppBar(/* glass styling */),
    ),
  ),
),
```

### 4. Floating Bottom Dock Uses MediaQuery

For floating docks (e.g. "Claim Gift", "Send BYC"), **do not** wrap in SafeArea. Inject device padding into the bottom margin:

```dart
padding: EdgeInsets.fromLTRB(
  16, 8, 16,
  MediaQuery.of(context).padding.bottom + 16,  // device safe area + spacing
),
```

### 5. Scroll Content Needs Bottom Clearance

Add bottom padding to scrollable areas so the last item isn't hidden behind the floating dock:

```dart
padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),  // adjust 120 for dock height + safe area
```

For scroll content, use `SafeArea(bottom: false)` so the background bleeds at the bottom:

```dart
SafeArea(
  bottom: false,  // Let it bleed at the bottom
  child: ListView(
    padding: const EdgeInsets.only(bottom: 120),
    children: [ ... ],
  ),
),
```

## Skeletal Structure

```dart
Scaffold(
  extendBodyBehindAppBar: true,
  extendBody: true,
  appBar: PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AppBar(/* ... */),
      ),
    ),
  ),
  body: Stack(
    children: [
      // 1. Ambient Orbs (No Safe Area)
      Positioned(top: -50, right: -50, child: OrbWidget()),

      // 2. Scrollable Content
      SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [ ... ],
        ),
      ),

      // 3. Floating Bottom Dock
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
          child: GlassBottomDock(),
        ),
      ),
    ],
  ),
)
```
