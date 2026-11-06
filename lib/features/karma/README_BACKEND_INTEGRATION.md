# Karma System Backend Integration

This document describes the integration of the Flutter Karma system with the backend API.

## Overview

The Karma system has been enhanced to work with both local storage (for offline/demo mode) and backend API integration for real-time data synchronization. The system provides a fallback mechanism that automatically switches to local storage if the API is unavailable.

## Architecture

### Backend API Endpoints

The following API endpoints have been integrated:

- `GET /v1/karma/me` - Get current user's karma account
- `GET /v1/karma/history` - Get karma transaction history with pagination
- `GET /v1/karma/leaderboard` - Get karma leaderboard
- `GET /v1/karma/achievements` - Get user achievements (unlocked and locked)
- `POST /v1/karma/achievements/:id/claim` - Claim an achievement

### Flutter Integration Components

1. **KarmaApiService** (`karma_api_service.dart`)
   - Handles API communication
   - Includes models for API responses
   - Manages HTTP requests with authentication

2. **Enhanced KarmaService** (`karma_service.dart`)
   - Maintains backward compatibility with existing UI
   - Includes API integration methods
   - Provides fallback to local storage
   - Automatic conversion between API models and local models

3. **Model Mapping**
   - API response models → Local Flutter models
   - Trust levels, karma activities, and achievements mapping
   - Automatic data synchronization

## Features

### Backend Integration Features

- ✅ **Real-time Karma Data**: Fetch live karma points, levels, and streaks
- ✅ **Transaction History**: Get complete karma transaction history with pagination
- ✅ **Live Leaderboard**: Real-time leaderboard with rankings
- ✅ **Achievement System**: Backend-managed achievements with unlock criteria
- ✅ **Offline Fallback**: Graceful degradation to local storage
- ✅ **Token-based Authentication**: Secure API access with JWT tokens

### API Data Mapping

| Backend Field | Flutter Model | Notes |
|---------------|---------------|-------|
| `currentPoints` | `totalPoints` | Total karma points |
| `trustLevel` | `trustLevel` | Mapped to enum values |
| `streak` | `currentStreak` | Activity streak days |
| `events` | `recentActivity` | Transaction history |
| `leaderboard` | `leaderboard` | User rankings |
| `achievements` | `achievements` | Unlocked/locked achievements |

## Usage

### Initialize Karma Service

```dart
final karmaService = Provider.of<KarmaService>(context, listen: false);
await karmaService.initialize('user_id_123');
```

### Check API Mode

```dart
bool usingApi = karmaService.isUsingBackendApi;
```

### Toggle API Mode

```dart
karmaService.toggleApiMode(true); // Use backend API
karmaService.toggleApiMode(false); // Use local storage
```

### Refresh Data

```dart
await karmaService.refreshLeaderboard();
```

### Claim Achievement

```dart
await karmaService.claimAchievement('achievement_id');
```

## Error Handling

The system includes comprehensive error handling:

1. **Network Failures**: Automatic fallback to local storage
2. **Authentication Errors**: Token refresh and retry mechanism
3. **Data Validation**: Ensures data integrity between API and local models
4. **User Feedback**: Clear error messages and loading states

## Testing

A test integration screen is available at `/karma/test` route that demonstrates:

- API connection status
- Data synchronization
- Mode switching between API and local storage
- Real-time updates

### Running the Test

1. Navigate to `/karma/test` in the app
2. Observe the API mode indicator
3. Test switching between backend and local modes
4. Verify data loading and display

## Configuration

### API Client Setup

The API client is configured with:
- Base URL: `http://localhost:3000` (configurable)
- Authentication: Bearer token from secure storage
- Timeout: 8 seconds connect, 12 seconds receive
- Automatic token refresh on 401 errors

### Environment Variables

Update `ApiClient` initialization in `KarmaService` for different environments:

```dart
final apiClient = ApiClient('YOUR_API_BASE_URL', storage);
```

## Backward Compatibility

The integration maintains full backward compatibility:

- Existing UI screens work unchanged
- All existing methods continue to function
- Local storage fallback preserves user experience
- No breaking changes to the public API

## Data Synchronization

### API to Local Model Conversion

The system automatically converts between API models and local Flutter models:

1. **Trust Levels**: String → Enum mapping
2. **Karma Activities**: Event types → Activity enum
3. **Timestamps**: ISO strings → DateTime objects
4. **Collections**: Array responses → List objects

### Caching Strategy

- API responses are cached locally for offline access
- Cache is updated on successful API calls
- Fallback to cached data when API is unavailable

## Security

- All API calls use Bearer token authentication
- Tokens are stored securely using Flutter Secure Storage
- Automatic token refresh prevents session expiry
- Sensitive data is not logged in production

## Performance Considerations

- Pagination support for large datasets
- Background data refresh
- Minimal UI blocking during API calls
- Efficient model conversion algorithms

## Future Enhancements

Potential future improvements:

1. **Real-time Updates**: WebSocket integration for live updates
2. **Conflict Resolution**: Handle concurrent karma updates
3. **Bulk Operations**: Batch API calls for better performance
4. **Enhanced Caching**: More sophisticated cache invalidation
5. **Offline Queue**: Queue karma transactions for later sync

## Dependencies

The integration relies on:

- `dio`: HTTP client for API calls
- `flutter_secure_storage`: Secure token storage
- `shared_preferences`: Local data caching
- `provider`: State management

## Troubleshooting

### Common Issues

1. **API Connection Failed**
   - Check network connectivity
   - Verify API endpoint URL
   - Check authentication tokens

2. **Data Not Syncing**
   - Ensure user is authenticated
   - Check API permissions
   - Verify data format consistency

3. **Performance Issues**
   - Monitor API response times
   - Check for memory leaks in conversion methods
   - Optimize pagination parameters

### Debug Mode

Enable debug logging by setting `_useBackendApi = false` temporarily to test local mode functionality.

## Conclusion

The Karma system backend integration provides a robust, scalable solution that enhances the user experience while maintaining reliability through intelligent fallback mechanisms. The architecture supports future growth and additional features while preserving the existing user interface and experience.