import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

class InviteProvider extends ChangeNotifier {
  List<Map<String, dynamic>> pendingInvites = [];
  bool loading = false;
  RealtimeChannel? _channel;

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

  void subscribeRealtime(String userId) {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('invite_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'invited_user_id',
            value: userId,
          ),
          callback: (_) => loadPendingInvites(),
        )
        .subscribe();
  }

  void unsubscribeRealtime() {
    _channel?.unsubscribe();
    _channel = null;
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

  @override
  void dispose() {
    unsubscribeRealtime();
    super.dispose();
  }
}
