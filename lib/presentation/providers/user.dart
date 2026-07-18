import 'package:flutter/material.dart';
import 'package:vcroad/data/models/user.dart';

class UserProvider with ChangeNotifier {
  UserDetails? _user;

  UserDetails? get user => _user;
  UserRole? get role => _user?.role;

  bool get isAdmin => role == UserRole.admin;
  bool get isSysAdmin => role == UserRole.sysadmin;
  bool get isUser => role == UserRole.user;

  bool get isVerified => _user?.isVerified ?? false;
  bool get isBanned => _user?.isBanned ?? false;

  // Only regular users (role == user), verified, and not banned can file reports.
  bool get canReport {
    return isUser && isVerified && !isBanned;
  }

  void setUser(UserDetails userDetails) {
    _user = userDetails;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }

  void updateUser(UserDetails updated) {
    _user = updated;
    notifyListeners();
  }
}
