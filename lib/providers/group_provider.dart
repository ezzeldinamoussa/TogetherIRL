import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class GroupProvider extends ChangeNotifier {
  List<Group> groups = [];
  bool loading = false;
  String? error;
  RealtimeChannel? _channel;

  Future<void> loadGroups() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiService.instance.getMyGroups();
      groups = data.map(Group.fromJson).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void subscribeRealtime(String userId) {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('group_members_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_members',
          callback: (_) => loadGroups(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'group_members',
          callback: (_) => loadGroups(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'group_members',
          callback: (_) => loadGroups(),
        )
        .subscribe();
  }

  void unsubscribeRealtime() {
    _channel?.unsubscribe();
    _channel = null;
  }

  Future<Group> createGroup(String name, String emoji, {String? description}) async {
    final data = await ApiService.instance.createGroup(name, emoji, description: description);
    final group = Group.fromJson(data);
    groups = [group, ...groups];
    notifyListeners();
    return group;
  }

  Future<void> inviteMember(String groupId, String email) async {
    await ApiService.instance.inviteMember(groupId, email);
  }

  Future<void> deleteGroup(String groupId) async {
    await ApiService.instance.deleteGroup(groupId);
    groups = groups.where((g) => g.id != groupId).toList();
    notifyListeners();
  }

  Future<void> leaveGroup(String groupId) async {
    await ApiService.instance.leaveGroup(groupId);
    groups = groups.where((g) => g.id != groupId).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeRealtime();
    super.dispose();
  }
}
