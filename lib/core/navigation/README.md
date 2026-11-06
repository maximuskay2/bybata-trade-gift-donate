# Navigation & Routing Guide

This guide explains how to navigate between screens in the bYbata app.

## Quick Start

### Using AppRoutes Helper (Recommended)

The `AppRoutes` class provides convenient methods for navigation:

```dart
import '../../core/navigation/app_routes.dart';

// Navigate to Create Trade Screen
AppRoutes.navigateToCreateTrade(context);

// Navigate to My Trades Screen  
AppRoutes.navigateToMyTrades(context);

// Navigate to Trade Offers Screen
AppRoutes.navigateToTradeOffers(context);

// Navigate to Trade Details with data
AppRoutes.navigateToTradeDetails(context, tradeObject);

// Navigate to Negotiation Screen
AppRoutes.navigateToNegotiation(
  context,
  targetTrade: trade,
  userTrades: userTradesList,
);

// Show coming soon message
AppRoutes.showComingSoon(context, 'Feature Name');
```

### Using Direct Navigation

If you need more control, use Flutter's standard navigation:

```dart
// Simple navigation
Navigator.pushNamed(context, '/create-trade');

// Navigation with arguments
Navigator.pushNamed(
  context, 
  '/trade-details',
  arguments: tradeObject,
);
```

## Available Routes

### Static Routes (defined in main.dart)
- `/main` - Main Navigation (Home screen with drawer)
- `/login` - Login Screen  
- `/register` - Registration Screen
- `/forgot-password` - Password Reset Screen
- `/create-trade` - Create Trade Screen
- `/my-trades` - My Trades Screen
- `/trade-offers` - Trade Offers Screen

### Dynamic Routes (handled in onGenerateRoute)
- `/email-verification` - Email Verification (requires email argument)
- `/trade-details` - Trade Details (requires Trade object argument)
- `/negotiation` - Negotiation Screen (requires targetTrade and userTrades)
- `/trade-offers-filtered` - Trade Offers with filter (requires Trade object)

## Trade Module Navigation Flow

```
HomeScreen (Quick Action) 
    ↓
CreateTradeScreen
    ↓
TradeScreen (My Trades tab)
    ↓ 
MyTradesScreen
    ↓
TradeDetailsScreen
    ↓
NegotiationScreen
    ↓
TradeOffersScreen
```

## Adding New Routes

1. **Add route constant** in `app_constants.dart`:
```dart
static const String newFeatureRoute = '/new-feature';
```

2. **Add route to main.dart**:
```dart
routes: {
  '/new-feature': (context) => const NewFeatureScreen(),
}
```

3. **Add helper method** in `app_routes.dart`:
```dart
static void navigateToNewFeature(BuildContext context) {
  Navigator.pushNamed(context, AppConstants.newFeatureRoute);
}
```

4. **Use the helper** in your screens:
```dart
AppRoutes.navigateToNewFeature(context);
```

## Best Practices

1. **Use AppRoutes helper methods** instead of direct Navigator calls
2. **Pass complex objects** through route arguments for dynamic routes
3. **Show coming soon messages** for unimplemented features
4. **Handle navigation errors** gracefully
5. **Test navigation flows** thoroughly

## Error Handling

If a route is not found, Flutter will show a default error screen. Make sure all routes are properly defined in `main.dart`.

## Examples

### From FloatingActionButton
```dart
FloatingActionButton(
  onPressed: () => AppRoutes.navigateToCreateTrade(context),
  child: const Icon(Icons.add),
)
```

### From Button Press
```dart
ElevatedButton(
  onPressed: () => AppRoutes.navigateToMyTrades(context),
  child: const Text('View My Trades'),
)
```

### From List Item Tap
```dart
ListTile(
  onTap: () => AppRoutes.navigateToTradeDetails(context, trade),
  title: Text(trade.title),
)
```