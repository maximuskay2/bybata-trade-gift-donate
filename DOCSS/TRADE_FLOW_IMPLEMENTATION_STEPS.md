# Trade Flow - Critical Action Items
**Status:** Ready for Implementation  
**Priority:** HIGH (Blocking Production Release)

---

## ⚠️ CRITICAL ISSUE: Race Condition on Trade Acceptance

### The Problem
When User B offers their Trade-2 for User A's Trade-1:
1. Offer is created (PENDING)
2. Both trades stay OPEN ← **PROBLEM**
3. User C can simultaneously offer for Trade-1 ← **Race condition!**
4. Both offers could be accepted → **Data corruption**

### Why This Matters
- Two trades can't be completed with two different users
- Payment/item conflicts
- Broken inventory state
- User frustration

---

## 🔧 Solution: Add IN_OFFER Status

### 1. Database Update
**File:** `apps/api/prisma/schema.prisma`

**Change:**
```prisma
enum TradeStatus {
  OPEN           // Available for offers
  IN_OFFER       // ← NEW: Offer pending, waiting response
  CLOSED         // Accepted/Completed
  CANCELLED      // Manually cancelled
}
```

**Migration:** Run `prisma migrate dev --name add_in_offer_status`

---

### 2. Backend Logic Update
**File:** `apps/api/src/trades/trades.service.ts`

**Function: createOffer (line ~565)**
```typescript
// BEFORE:
async createOffer(...) {
  // Validates trade, creates offer
  // Trade status stays OPEN
}

// AFTER:
async createOffer(...) {
  // ... existing validations ...
  
  // NEW: Lock both trades to IN_OFFER
  const targetTrade = await this.prisma.trade.update({
    where: { id: tradeId },
    data: { status: TradeStatus.IN_OFFER }
  });
  
  if (data.offeredTradeId) {
    await this.prisma.trade.update({
      where: { id: data.offeredTradeId },
      data: { status: TradeStatus.IN_OFFER }
    });
  }
  
  // Create offer (existing logic)
  const offer = await this.prisma.tradeOffer.create({
    data: {
      tradeId,
      bidderId: currentUserId,
      offeredTradeId: data.offeredTradeId,
      status: OfferStatus.PENDING,
      message: data.message
    }
  });
  
  return offer;
}
```

**Function: acceptOffer (line ~772)**
```typescript
// BEFORE:
async acceptOffer(...) {
  // Updates trade: status = CLOSED
}

// AFTER:
async acceptOffer(...) {
  // Validation: trade MUST be IN_OFFER
  if (trade.status !== TradeStatus.IN_OFFER) {
    throw new BadRequestException(
      'Can only accept offers for trades in negotiation'
    );
  }
  
  // IN_OFFER → CLOSED (existing logic, no change needed)
  await tx.trade.update({
    where: { id: trade.id },
    data: { 
      status: TradeStatus.CLOSED,
      closedAt: new Date(),
      acceptedOfferId: offer.id 
    }
  });
  
  // Same for offered trade...
}
```

**Function: rejectOffer (line ~910)**
```typescript
// BEFORE:
async rejectOffer(...) {
  // Sets offer.status = REJECTED
  // Trade status unchanged
}

// AFTER:
async rejectOffer(...) {
  // Validation: trade MUST be IN_OFFER
  if (trade.status !== TradeStatus.IN_OFFER) {
    throw new BadRequestException(
      'Can only reject active offers'
    );
  }
  
  // IN_OFFER → OPEN (revert)
  await this.prisma.trade.update({
    where: { id: trade.id },
    data: { status: TradeStatus.OPEN }
  });
  
  if (offer.offeredTradeId) {
    await this.prisma.trade.update({
      where: { id: offer.offeredTradeId },
      data: { status: TradeStatus.OPEN }
    });
  }
  
  // Update offer.status = REJECTED (existing logic)
  await this.prisma.tradeOffer.update({
    where: { id: offerId },
    data: { status: OfferStatus.REJECTED }
  });
}
```

**Function: createOffer - Add Validation**
```typescript
// NEW validation at start of createOffer:
if (trade.status !== TradeStatus.OPEN) {
  throw new BadRequestException(
    `Cannot offer for ${trade.status} trade. Only OPEN trades accept offers.`
  );
}

if (data.offeredTradeId) {
  const offeredTrade = await this.prisma.trade.findUnique({ 
    where: { id: data.offeredTradeId } 
  });
  
  if (offeredTrade.status !== TradeStatus.OPEN) {
    throw new BadRequestException(
      `Cannot offer ${offeredTrade.status} trade. Only OPEN trades can be offered.`
    );
  }
}
```

---

### 3. API Controller Update
**File:** `apps/api/src/trades/offers.controller.ts`

No changes needed - service layer handles all logic

---

### 4. Frontend Model Update
**File:** `lib/features/trade/models/trade_models.dart`

**Find TradeStatus enum (line ~350):**
```dart
// BEFORE:
enum TradeStatus {
  active,
  closed,
  cancelled,
}

// AFTER:
enum TradeStatus {
  active,        // OPEN in backend
  inOffer,       // IN_OFFER in backend (negotiation pending)
  closed,        // CLOSED in backend
  cancelled,     // CANCELLED in backend
}

// Add conversion helper:
static TradeStatus fromBackendStatus(String status) {
  switch (status.toUpperCase()) {
    case 'OPEN': return TradeStatus.active;
    case 'IN_OFFER': return TradeStatus.inOffer;
    case 'CLOSED': return TradeStatus.closed;
    case 'CANCELLED': return TradeStatus.cancelled;
    default: return TradeStatus.active;
  }
}

String get backendStatus {
  switch (this) {
    case TradeStatus.active: return 'OPEN';
    case TradeStatus.inOffer: return 'IN_OFFER';
    case TradeStatus.closed: return 'CLOSED';
    case TradeStatus.cancelled: return 'CANCELLED';
  }
}
```

---

### 5. Frontend UI Updates
**File:** `lib/features/trade/screens/trade_screen.dart`

**Function: _buildBrowseTradesTab (line ~305)**
```dart
// BEFORE:
final filtered = _availableTrades.where((t) {
  final q = _searchQuery;
  final inCategory = _selectedCategory == 'All' || t['category'] == _selectedCategory;
  if (q.isEmpty) return inCategory;
  return inCategory && t['title'].toString().toLowerCase().contains(q);
}).toList();

// AFTER:
final filtered = _availableTrades.where((t) {
  final q = _searchQuery;
  final inCategory = _selectedCategory == 'All' || t['category'] == _selectedCategory;
  final status = t['status']?.toString().toUpperCase() ?? 'OPEN';
  
  // Only show OPEN trades (not IN_OFFER or CLOSED)
  final isAvailable = status == 'OPEN';
  
  if (!isAvailable) return false;
  if (q.isEmpty) return inCategory;
  return inCategory && t['title'].toString().toLowerCase().contains(q);
}).toList();
```

**Add visual indicator for trade cards:**
```dart
// In _buildTradeCard function, add status badge:
Widget _buildTradeCard(Map<String, dynamic> trade) {
  final status = trade['status']?.toString().toUpperCase() ?? 'OPEN';
  final isInOffer = status == 'IN_OFFER';
  
  return Stack(
    children: [
      // Existing card...
      _build3DContainer(
        child: /* existing content */
      ),
      
      // Add lock overlay if IN_OFFER
      if (isInOffer)
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.lock_outline, color: Colors.white, size: 16),
          ),
        ),
    ],
  );
}
```

---

## 📋 Implementation Checklist

### Phase 1: Backend (2-3 hours)
```
☐ Update Prisma schema with IN_OFFER
☐ Run migration: prisma migrate dev --name add_in_offer_status
☐ Update createOffer to set IN_OFFER
☐ Update acceptOffer validation (IN_OFFER check)
☐ Update rejectOffer to revert from IN_OFFER
☐ Add OPEN-only validation in createOffer
☐ Test with Postman/curl:
  - Create offer → verify trades IN_OFFER
  - Accept offer → verify trades CLOSED
  - Reject offer → verify trades OPEN
  - Try second offer on IN_OFFER trade → should fail
```

### Phase 2: Frontend (1-2 hours)
```
☐ Update TradeStatus enum in models
☐ Add status parsing logic
☐ Update browse tab filter
☐ Add lock indicator on trade cards
☐ Test with real backend
☐ Verify IN_OFFER trades don't appear in browse
☐ Verify accepted trades in history (once implemented)
```

### Phase 3: Testing (1 hour)
```
☐ End-to-end flow:
  - Create Trade A
  - Create Trade B
  - Offer B for A (check: both IN_OFFER)
  - Offer another trade for A (check: fails with error)
  - Accept offer (check: both CLOSED)
  - Verify can't offer closed trades
☐ Rejection flow:
  - Create new trades
  - Offer one (IN_OFFER)
  - Reject (check: both revert to OPEN)
  - Offer again (should work)
```

---

## 🚀 Implementation Order

1. **First:** Deploy Prisma migration (requires database change)
2. **Second:** Update backend logic in trades.service.ts
3. **Third:** Update frontend models and UI
4. **Fourth:** Deploy and test

---

## ✅ After Implementation

**Expected Behavior:**
```
✅ Offer made → Both trades locked (IN_OFFER)
✅ No other offers accepted while negotiating
✅ Accept → Both trades CLOSED
✅ Reject → Both trades revert to OPEN
✅ Prevents double-trading
✅ Prevents race conditions
✅ Clean data integrity
```

---

## Additional: Implement History Tab

**File:** `lib/features/trade/screens/trade_screen.dart`

**Replace empty placeholder (line ~1010):**
```dart
// BEFORE:
Widget _buildTradeHistoryTab() 
  => _buildEmptyState("History", "Your completed barters appear here.", Icons.history);

// AFTER:
Widget _buildTradeHistoryTab() {
  return _isLoading 
    ? const Center(child: CircularProgressIndicator())
    : RefreshIndicator(
        onRefresh: _loadTradeHistory,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_completedTrades.isEmpty)
              _buildEmptyState(
                "No Completed Trades Yet",
                "Your finished trades will appear here.",
                Icons.history,
              )
            else
              ..._completedTrades.map((trade) => _buildHistoryTradeCard(trade)),
            const SizedBox(height: 100),
          ],
        ),
      );
}

Future<void> _loadTradeHistory() async {
  setState(() => _isLoading = true);
  try {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tradeProvider = Provider.of<TradeBackendProvider>(context, listen: false);
    
    if (auth.currentUser == null) return;
    
    // Fetch closed trades for current user
    final res = await tradeProvider.listMyTrades(
      ownerId: auth.currentUser!.id, 
      status: 'CLOSED',  // ← Filter for completed trades
      page: 1, 
      size: 20
    );
    
    if (mounted) {
      setState(() {
        _completedTrades = (res['items'] as List? ?? [])
          .map<Map<String, dynamic>>((t) => {
            'id': t['id'],
            'title': t['title'],
            'image': t['mediaKeys']?.isNotEmpty ?? false ? t['mediaKeys'][0] : null,
            'closedAt': t['closedAt'],
            'acceptedOfferId': t['acceptedOfferId'],
            'category': _mapCategory(t['category']),
          })
          .toList();
      });
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

Widget _buildHistoryTradeCard(Map<String, dynamic> trade) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _build3DContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade['title'] ?? 'Trade',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trade['category'] ?? 'General',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge('COMPLETED', AppTheme.successColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Completed on ${_formatDate(trade['closedAt'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatDate(dynamic dateStr) {
  try {
    final date = DateTime.parse(dateStr.toString());
    return '${date.month}/${date.day}/${date.year}';
  } catch (_) {
    return 'Unknown date';
  }
}
```

---

## Summary

| Task | Time | Difficulty | Impact |
|------|------|-----------|--------|
| Add IN_OFFER status | 30m | Easy | Critical |
| Backend logic update | 1h | Medium | Critical |
| Frontend UI update | 1h | Medium | Important |
| History tab | 45m | Easy | Important |
| **Total** | **3-4 hours** | **Medium** | **Production Ready** |

**Once completed:** Trade flow will be race-condition free and production-ready! ✅
