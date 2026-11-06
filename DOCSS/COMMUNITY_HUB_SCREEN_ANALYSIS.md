# CommunityHubScreen Analysis & Implementation Requirements

## Current Status
**File:** `lib/features/community/screens/community_hub_screen.dart`
**Status:** ⚠️ **PLACEHOLDER ONLY** - Currently shows a basic scaffold with community name and ID

## Expected Structure (Based on Documentation & Backend)

### Main Layout
The CommunityHubScreen should be a **tabbed interface** with the following tabs:

1. **Feed Tab** (Primary)
2. **Events Tab**
3. **Chat Tab**
4. **Members Tab**

Plus a **FloatingActionButton** for creating new posts.

---

## Tab 1: Feed Tab

### Purpose
Display community posts in a feed format with engagement features.

### Features Required:
- ✅ **Display Posts List** - Show all posts from the community
- ✅ **Post Types Supported:**
  - TEXT posts
  - IMAGE posts
  - VIDEO posts
  - POLL posts
  - EVENT posts
  - RESOURCE posts
  - SUCCESS_STORY posts
  - ANNOUNCEMENT posts
- ✅ **Post Actions:**
  - Like/Unlike posts
  - Comment on posts
  - View comments
  - Share posts
- ✅ **Post Engagement:**
  - Like count display
  - Comment count display
  - Share count display
- ✅ **Post Filtering:**
  - Filter by post type
  - Sort by (newest, most liked, pinned)
  - Show pinned posts first
- ✅ **Infinite Scroll/Pagination** - Load more posts as user scrolls

### Backend API Calls Available:

#### ✅ Get Posts
```dart
// Service Method
getCommunityPostsFromApi(
  String communityId, {
  int page = 1,
  int size = 20,
  String? type,
})

// API Endpoint
GET /v1/communities/{communityId}/posts?page=1&size=20&type=TEXT
```

#### ✅ Create Post
```dart
// Service Method
createPostViaApi({
  required String communityId,
  String? title,
  String? content,
  String type = 'TEXT',
  List<String>? images,
  String? location,
  List<String>? tags,
  Map<String, dynamic>? pollData,
  Map<String, dynamic>? eventData,
  Map<String, dynamic>? resourceData,
})

// API Endpoint
POST /v1/communities/{communityId}/posts
```

#### ✅ Like/Unlike Post
```dart
// API Endpoint
POST /v1/communities/{communityId}/posts/{postId}/like
DELETE /v1/communities/{communityId}/posts/{postId}/like
```

#### ✅ Get Comments
```dart
// API Endpoint
GET /v1/communities/{communityId}/posts/{postId}/comments?page=1&size=50
```

#### ✅ Create Comment
```dart
// API Endpoint
POST /v1/communities/{communityId}/posts/{postId}/comments
Body: { content: string, parentCommentId?: string }
```

#### ✅ Like/Unlike Comment
```dart
// API Endpoint
POST /v1/communities/{communityId}/posts/{postId}/comments/{commentId}/like
DELETE /v1/communities/{communityId}/posts/{postId}/comments/{commentId}/like
```

---

## Tab 2: Events Tab

### Purpose
Display and manage community events (upcoming and past).

### Features Required:
- ✅ **Display Events List** - Show community events
- ✅ **Event Filtering:**
  - Filter by status (UPCOMING, ONGOING, COMPLETED, CANCELLED)
  - Filter by date range
- ✅ **Event Actions:**
  - View event details
  - Register for events
  - Unregister from events
  - View attendees list
- ✅ **Event Display:**
  - Event title and description
  - Start/End dates
  - Location (physical or virtual)
  - Capacity and current attendee count
  - Registration deadline
- ✅ **Create Event** (for owners/admins)

### Backend API Calls Available:

#### ✅ Get Events
```dart
// Service Method
getCommunityEventsFromApi(
  String communityId, {
  int page = 1,
  int size = 20,
  bool upcoming = true,
})

// API Endpoint
GET /v1/communities/{communityId}/events?page=1&size=20&upcoming=true
```

#### ✅ Create Event
```dart
// API Endpoint
POST /v1/communities/{communityId}/events
Body: {
  title: string (required),
  description?: string,
  startDate: ISO date string (required),
  endDate: ISO date string (required),
  location?: string,
  isOnline?: boolean,
  onlineLink?: string,
  maxAttendees?: number,
  price?: string,
  currency?: string,
  tags?: string[],
  registrationDeadline?: ISO date string
}
```

#### ✅ Register for Event
```dart
// API Endpoint
POST /v1/communities/events/{eventId}/register
```

#### ✅ Get Event Attendees
```dart
// Service Method (Not found in current API - may need to add)
// Expected endpoint:
GET /v1/communities/events/{eventId}/attendees
```

---

## Tab 3: Chat Tab

### Purpose
Community group chat interface for real-time messaging.

### Features Required:
- ✅ **Display Messages** - Show community chat messages
- ✅ **Send Messages** - Post messages to community chat
- ✅ **Real-time Updates** - Receive new messages instantly
- ✅ **Message Features:**
  - Text messages
  - Media messages (images, files)
  - Typing indicators
  - Read receipts
- ⚠️ **Note:** This may need integration with the existing chat system

### Backend API Calls Available:
- ⚠️ **No dedicated community chat endpoints found** - May need to use generic chat system
- ⚠️ **May need to implement** - Community-specific chat room functionality

---

## Tab 4: Members Tab

### Purpose
Display community member directory with roles and member management.

### Features Required:
- ✅ **Display Members List** - Show all community members
- ✅ **Member Information:**
  - Avatar and name
  - Role (OWNER, ADMIN, MEMBER, MODERATOR)
  - Status (ACTIVE, PENDING, BANNED)
  - Join date
  - Expert level
  - Contribution score
  - Badges
- ✅ **Member Actions (for owners/admins):**
  - View member profile
  - Update member role
  - Remove/ban member
  - Approve pending members
- ✅ **Member Filtering:**
  - Filter by role
  - Filter by status
  - Search members

### Backend API Calls Available:

#### ✅ Get Members
```dart
// Service Method
getCommunityMembersFromApi(
  String communityId, {
  int page = 1,
  int size = 50,
})

// API Endpoint
GET /v1/communities/{communityId}/members?page=1&size=50
```

#### ✅ Update Member Role
```dart
// Service Method
updateMemberRole(
  String communityId,
  String userId, {
  required String role,
})

// API Endpoint
PATCH /v1/communities/{communityId}/members/{memberId}/role
Body: { role: string }
```

#### ✅ Remove Member
```dart
// Service Method
removeMember(String communityId, String userId)

// API Endpoint
DELETE /v1/communities/{communityId}/members/{memberId}?banReason=optional
```

---

## Additional Features

### Community Info Header
- ✅ **Community Details** - Name, description, avatar, banner
- ✅ **Member Count** - Total members
- ✅ **Post Count** - Total posts
- ✅ **Event Count** - Total events
- ✅ **Join/Leave Button** - For non-members or members
- ✅ **Settings Button** - For owners/admins

### Backend API Calls Available:

#### ✅ Get Community Details
```dart
// Service Method
getCommunityFromApi(String communityId)

// API Endpoint
GET /v1/communities/{communityId}
```

#### ✅ Join Community
```dart
// Service Method
joinCommunityViaApi(String communityId)

// API Endpoint
POST /v1/communities/{communityId}/join
```

#### ✅ Leave Community
```dart
// Service Method
leaveCommunityViaApi(String communityId)

// API Endpoint
POST /v1/communities/{communityId}/leave
```

#### ✅ Check Membership
```dart
// Service Method
isUserMemberOfCommunity(String communityId)

// API Endpoint
GET /v1/communities/{communityId}/members/me
```

---

## FloatingActionButton (FAB)

### Purpose
Quick access to create new posts.

### Features:
- ✅ **Create Post Action** - Navigate to post creation screen
- ✅ **Icon:** Add/Post icon
- ✅ **Position:** Bottom right corner
- ✅ **Permissions:** Only visible for members

---

## UI Components Needed

### Existing Components (Check if available):
1. ✅ `CommunityCard` - For community display
2. ❌ `PostItem` / `PostCard` - Need to create for post display
3. ❌ `CommentItem` - Need to create for comments
4. ❌ `EventCard` - Need to create for events
5. ❌ `MemberCard` - Need to create for member display
6. ❌ `CreatePostWidget` - Need to create for post creation

### Post Display Components:
- Post header (avatar, name, timestamp)
- Post content (text, images, videos)
- Post actions (like, comment, share)
- Post engagement (likes count, comments count)
- Comments section (expandable)

---

## Implementation Priority

### Phase 1 - Core Functionality (Critical):
1. ✅ Fetch and display community details
2. ✅ Create tab navigation (Feed, Events, Chat, Members)
3. ✅ Implement Feed Tab with posts list
4. ✅ Implement post like/comment functionality
5. ✅ Implement Members Tab with member list

### Phase 2 - Enhanced Features:
1. ✅ Implement Events Tab with events list
2. ✅ Implement event registration
3. ✅ Add Create Post FAB
4. ✅ Implement post creation
5. ✅ Add pull-to-refresh

### Phase 3 - Advanced Features:
1. ✅ Implement Chat Tab
2. ✅ Add real-time updates
3. ✅ Add post filtering and sorting
4. ✅ Add member management actions
5. ✅ Add moderation features

---

## Data Models Available

### Community Model
- `CommunityApi` - Available in `lib/features/community/models/community_api.dart`

### Post Model
- `CommunityPost` - Available in `lib/features/community/models/community_post.dart`
- Posts returned as `Map<String, dynamic>` from API

### Event Model
- Events returned as `Map<String, dynamic>` from API

### Member Model
- Members returned as `Map<String, dynamic>` from API

---

## Service Layer

### Available Service:
`CommunityApiService` - Located in `lib/features/community/services/community_api_service.dart`

**Key Methods:**
- `getCommunityFromApi(String communityId)`
- `getCommunityPostsFromApi(String communityId, {page, size, type})`
- `createPostViaApi({required communityId, ...})`
- `getCommunityMembersFromApi(String communityId, {page, size})`
- `getCommunityEventsFromApi(String communityId, {page, size, upcoming})`
- `joinCommunityViaApi(String communityId)`
- `leaveCommunityViaApi(String communityId)`
- `isUserMemberOfCommunity(String communityId)`

---

## Summary

### ✅ Backend APIs Implemented:
- Community CRUD operations
- Posts CRUD and engagement (like, comment)
- Events CRUD and registration
- Members management
- Join/Leave functionality

### ❌ Frontend Implementation Status:
- **CommunityHubScreen**: ⚠️ Placeholder only
- **Feed Tab**: ❌ Not implemented
- **Events Tab**: ❌ Not implemented  
- **Chat Tab**: ❌ Not implemented
- **Members Tab**: ❌ Not implemented
- **Post Components**: ❌ Not created
- **Event Components**: ❌ Not created
- **Member Components**: ❌ Not created

### Next Steps:
1. Implement the main tabbed layout structure
2. Implement Feed Tab with post listing and engagement
3. Implement Events Tab
4. Implement Members Tab
5. Add Create Post functionality
6. Implement Chat Tab (may require chat system integration)
7. Add real-time updates
8. Add member management for admins/owners

