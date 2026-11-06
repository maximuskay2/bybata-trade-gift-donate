# Home Page Navigation Flow - Testing Guide

## Overview
The app now shows a browse home page to unauthenticated users after onboarding, allowing them to explore content before forcing login.

## Navigation Flow

### Current Flow (After Changes)
```
OnboardingScreen 
  ↓ (user completes onboarding)
BrowseHomeScreen (unauthenticated)
  ├─ Home tab (welcome + feature overview)
  ├─ Browse Trades (read-only trades list)
  ├─ Browse Gifts (read-only gifts list)
  ├─ Donations (read-only campaigns)
  ├─ Community (read-only community list)
  └─ [Sign In button in AppBar]
       ↓
  LoginScreen
       ↓
  EmailVerificationScreen (if not verified)
       ↓
  MainNavigation (full authenticated access)
```

## Test Cases

### 1. First-Time App Launch (No Onboarding)
- **Expected**: OnboardingScreen displays
- **Action**: Complete onboarding (skip/next buttons)
- **Expected Result**: BrowseHomeScreen displays

### 2. Browsing Content Without Login
- **Location**: BrowseHomeScreen
- **Actions to Test**:
  - [ ] Click on "Browse Trades" tab → Shows trade list
  - [ ] Click on "Browse Gifts" tab → Shows gifts list
  - [ ] Click on "Donations" tab → Shows donation campaigns
  - [ ] Click on "Community" tab → Shows community list
  - [ ] Click on trade/gift/donation item → Shows details (read-only)
  - [ ] All screens should be read-only (no edit/create options visible)

### 3. Create Trade - Auth Required
- **Location**: BrowseHomeScreen → Browse Trades tab
- **Action**: Click create trade button/icon
- **Expected Result**: 
  - [ ] Login required dialog appears
  - [ ] Dialog shows "Sign In Required" message
  - [ ] "Cancel" button closes dialog
  - [ ] "Sign In" button navigates to LoginScreen

### 4. Create Gift - Auth Required
- **Location**: BrowseHomeScreen → Browse Gifts tab
- **Action**: Click create gift button
- **Expected Result**: 
  - [ ] Login required dialog appears
  - [ ] Redirects to LoginScreen on "Sign In"

### 5. Make Donation - Auth Required
- **Location**: BrowseHomeScreen → Donations tab
- **Action**: Try to donate to a campaign
- **Expected Result**: 
  - [ ] Login required dialog appears
  - [ ] Redirects to LoginScreen on "Sign In"

### 6. Create Community - Auth Required
- **Location**: BrowseHomeScreen → Community tab
- **Action**: Click create community button
- **Expected Result**: 
  - [ ] Login required dialog appears
  - [ ] Redirects to LoginScreen on "Sign In"

### 7. Edit Profile - Auth Required
- **Location**: BrowseHomeScreen → Browse any screen
- **Action**: Try to access profile edit
- **Expected Result**: 
  - [ ] Login required dialog appears
  - [ ] Redirects to LoginScreen on "Sign In"

### 8. Sign In Flow
- **Location**: BrowseHomeScreen
- **Action**: Click "Sign In" button in AppBar
- **Expected Result**: 
  - [ ] LoginScreen displays
  - [ ] User can enter credentials
  - [ ] After login → EmailVerificationScreen (if not verified)
  - [ ] After verification → MainNavigation displays

### 9. After Login - Full Access
- **Location**: MainNavigation
- **Expected**: 
  - [ ] Create Trade button works (no dialog)
  - [ ] Create Gift button works (no dialog)
  - [ ] Create Campaign button works (no dialog)
  - [ ] All features available without auth dialogs

### 10. Logout - Back to Browse
- **Location**: MainNavigation → Settings
- **Action**: Logout
- **Expected Result**: 
  - [ ] User returns to BrowseHomeScreen
  - [ ] Browse mode active (no authenticated features)

### 11. Back Button Behavior
- **Location**: BrowseHomeScreen
- **Tests**:
  - [ ] In any non-Home tab → back button returns to Home tab
  - [ ] In Home tab → back button closes app or returns to previous screen
  - [ ] After login → back navigation in MainNavigation works normally

### 12. Sign In Button Visibility
- **Location**: BrowseHomeScreen
- **Expected**: 
  - [ ] AppBar shows "Sign In" button at all times
  - [ ] Button is clickable from any tab
  - [ ] Button navigates to LoginScreen

### 13. Home Tab Content
- **Location**: BrowseHomeScreen → Home tab
- **Expected Elements**:
  - [ ] Welcome header with app name/tagline
  - [ ] "Ready to join?" CTA section with Sign In button
  - [ ] "Browse Available" grid showing Trade, Gift, Donation, Community cards
  - [ ] "Available After Sign In" section listing locked features:
    - Create and manage trades
    - Send and receive gifts
    - Make donations
    - Chat functionality
    - Earn karma points
    - Wallet management

## Visual Verification

### BrowseHomeScreen Visual Elements
- [ ] Gradient header with Bybata branding
- [ ] Sign In button in AppBar with proper styling
- [ ] Browse cards have proper icons and descriptions
- [ ] Bottom navigation bar has 5 tabs (Home, Trades, Gifts, Donations, Community)
- [ ] No floating action button for unauthenticated users
- [ ] All text is readable and properly aligned

### Login Dialog Visual Elements
- [ ] Dialog title: "Sign In Required"
- [ ] Dialog message explains need to sign in
- [ ] Cancel and Sign In buttons are properly styled
- [ ] Dialog appears on top of current content

## Performance Checks
- [ ] BrowseHomeScreen loads quickly
- [ ] Navigation between tabs is smooth
- [ ] Login dialog appears immediately without lag
- [ ] No memory leaks when switching tabs

## Edge Cases
- [ ] Network error during trade list fetch → Error message displays
- [ ] Going back from LoginScreen → Returns to BrowseHomeScreen
- [ ] Screen rotation while in BrowseHomeScreen → State preserved
- [ ] App restart while in BrowseHomeScreen → BrowseHomeScreen displays

## Regression Tests
- [ ] Authenticated users still see MainNavigation after login
- [ ] Email verification flow still works
- [ ] All existing features still work after login
- [ ] Chat functionality still works
- [ ] Notifications still work
- [ ] Deep linking still works

## Success Criteria
✅ All test cases pass
✅ No compilation errors
✅ No runtime errors in logs
✅ Navigation flow matches design
✅ Auth redirects work as expected
✅ Browse functionality works without authentication
✅ No regressions in authenticated flows

## Rollback Plan
If issues are found:
1. Revert commit: `git revert dc41061`
2. Original flow will restore (OnboardingScreen → LoginScreen → MainNavigation)
3. Push revert commit to main
