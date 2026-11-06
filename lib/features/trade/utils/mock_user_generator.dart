import 'dart:math';
import 'package:flutter/material.dart';
import '../models/trade_models.dart';

class MockUserGenerator {
  static final Random _random = Random();
  
  static final List<String> _firstNames = [
    'Alex', 'Sarah', 'Mike', 'Emma', 'Chris', 'Jessica', 'Daniel', 'Ashley',
    'Ryan', 'Taylor', 'Jordan', 'Morgan', 'Casey', 'Jamie', 'Parker', 'Riley',
    'Sam', 'Quinn', 'Blake', 'Drew', 'Cameron', 'Avery', 'Reese', 'Sage'
  ];
  
  static final List<String> _lastNames = [
    'Thompson', 'Johnson', 'Davis', 'Wilson', 'Rodriguez', 'Miller', 'Kim',
    'Brown', 'Garcia', 'Martinez', 'Smith', 'Lee', 'Williams', 'Chen', 'Jones',
    'Anderson', 'Taylor', 'Moore', 'Jackson', 'Martin', 'White', 'Clark'
  ];
  
  static final List<String> _locations = [
    'New York, NY', 'Los Angeles, CA', 'Chicago, IL', 'Houston, TX',
    'Phoenix, AZ', 'Philadelphia, PA', 'San Antonio, TX', 'San Diego, CA',
    'Dallas, TX', 'San Jose, CA', 'Austin, TX', 'Jacksonville, FL',
    'Fort Worth, TX', 'Columbus, OH', 'Charlotte, NC', 'San Francisco, CA',
    'Indianapolis, IN', 'Seattle, WA', 'Denver, CO', 'Washington, DC'
  ];
  
  static final List<String> _bios = [
    'Passionate about sustainable trading and helping the community.',
    'Love finding unique items and giving them new homes.',
    'Environmentally conscious trader who believes in reuse and recycle.',
    'Collector of vintage items with an eye for quality.',
    'Local community member who enjoys meeting new people through trading.',
    'Tech enthusiast always looking for the latest gadgets.',
    'Books lover who enjoys sharing great reads with others.',
    'Minimalist who prefers quality over quantity.',
    'Parent looking to trade kids\' outgrown items.',
    'Student trying to be budget-conscious and eco-friendly.',
  ];
  
  static final List<TrustBadge> _availableBadges = [
    TrustBadge.fromType(type: TrustBadgeType.reliableTrader, earnedAt: DateTime.now()),
    TrustBadge.fromType(type: TrustBadgeType.fastTrader, earnedAt: DateTime.now()),
    TrustBadge.fromType(type: TrustBadgeType.friendlyTrader, earnedAt: DateTime.now()),
    TrustBadge.fromType(type: TrustBadgeType.expertTrader, earnedAt: DateTime.now()),
    TrustBadge.fromType(type: TrustBadgeType.communityHelper, earnedAt: DateTime.now()),
    TrustBadge.fromType(type: TrustBadgeType.safeMeeter, earnedAt: DateTime.now()),
    TrustBadge.fromType(type: TrustBadgeType.responseChamp, earnedAt: DateTime.now()),
  ];
  
  static TradeUser generateRealisticUser([String? id]) {
    final firstName = _firstNames[_random.nextInt(_firstNames.length)];
    final lastName = _lastNames[_random.nextInt(_lastNames.length)];
    final name = '$firstName $lastName';
    final email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}@example.com';
    
    // Generate realistic stats
    final completedTrades = _random.nextInt(50) + 5; // 5-55 trades
    final rating = 3.5 + (_random.nextDouble() * 1.5); // 3.5-5.0 rating
    final karmaPoints = _random.nextInt(2000) + 100; // 100-2100 karma
    final trustScore = 0.4 + (_random.nextDouble() * 0.6); // 0.4-1.0 trust
    final isVerified = _random.nextBool();
    
    // Generate 1-3 random badges
    final numBadges = _random.nextInt(3) + 1;
    final shuffledBadges = List<TrustBadge>.from(_availableBadges)..shuffle();
    final badges = shuffledBadges.take(numBadges).toList();
    
    return TradeUser(
      id: id ?? 'user_${_random.nextInt(10000)}',
      name: name,
      username: email,
      rating: rating,
      completedTrades: completedTrades,
      joinedDate: DateTime.now().subtract(
        Duration(days: _random.nextInt(1095) + 30), // 30 days to 3 years ago
      ),
      isVerified: isVerified,
      location: _locations[_random.nextInt(_locations.length)],
      karmaPoints: karmaPoints,
      trustScore: trustScore,
      trustBadges: badges,
      bio: _bios[_random.nextInt(_bios.length)],
    );
  }
  
  static TradeUser generateUserFromId(String id) {
    // Use the ID as a seed for consistent generation
    final seed = id.hashCode.abs();
    final seededRandom = Random(seed);
    
    final firstName = _firstNames[seededRandom.nextInt(_firstNames.length)];
    final lastName = _lastNames[seededRandom.nextInt(_lastNames.length)];
    final name = '$firstName $lastName';
    final email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}@example.com';
    
    // Generate consistent stats based on ID
    final completedTrades = seededRandom.nextInt(50) + 5;
    final rating = 3.5 + (seededRandom.nextDouble() * 1.5);
    final karmaPoints = seededRandom.nextInt(2000) + 100;
    final trustScore = 0.4 + (seededRandom.nextDouble() * 0.6);
    final isVerified = seededRandom.nextBool();
    
    // Generate consistent badges
    final numBadges = seededRandom.nextInt(3) + 1;
    final badgeIndices = <int>{};
    while (badgeIndices.length < numBadges) {
      badgeIndices.add(seededRandom.nextInt(_availableBadges.length));
    }
    final badges = badgeIndices.map((i) => _availableBadges[i]).toList();
    
    return TradeUser(
      id: id,
      name: name,
      username: email,
      rating: rating,
      completedTrades: completedTrades,
      joinedDate: DateTime.now().subtract(
        Duration(days: seededRandom.nextInt(1095) + 30),
      ),
      isVerified: isVerified,
      location: _locations[seededRandom.nextInt(_locations.length)],
      karmaPoints: karmaPoints,
      trustScore: trustScore,
      trustBadges: badges,
      bio: _bios[seededRandom.nextInt(_bios.length)],
    );
  }
}