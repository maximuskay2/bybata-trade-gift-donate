import 'package:flutter/foundation.dart';

/// Notifies profile screens when follow state changes so counts stay in sync.
class ProfileSocialNotifier extends ChangeNotifier {
  ProfileSocialNotifier._();
  static final ProfileSocialNotifier instance = ProfileSocialNotifier._();

  void notifyFollowChanged() {
    notifyListeners();
  }
}
