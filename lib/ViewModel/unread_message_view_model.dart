import 'package:flutter/foundation.dart';

class UnreadMessagesViewModel extends ChangeNotifier {
  int _totalUnreadCount = 0;

  int get totalUnreadCount => _totalUnreadCount;

  void setTotalUnreadCount(int count) {
    _totalUnreadCount = count;
    notifyListeners();
  }

  void resetUnreadCount() {
    _totalUnreadCount = 0;
    notifyListeners();
  }
}
