import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class InviteProvider extends ChangeNotifier {
  List<Map<String, dynamic>> pendingInvites = [];
  bool loading = false;

  int get pendingCount => pendingInvites.length;

  Future<void> loadPendingInvites() async {
    loading = true;
    notifyListeners();
    try {
      pendingInvites = await ApiService.instance.getPendingInvites();
    } catch (_) {
      pendingInvites = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> respond(String inviteId, bool accept) async {
    try {
      await ApiService.instance.respondToInvite(inviteId, accept);
      pendingInvites.removeWhere((i) => i['id'] == inviteId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
