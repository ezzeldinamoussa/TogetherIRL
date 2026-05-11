import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class HangoutProvider extends ChangeNotifier {
  // Hangouts keyed by groupId so each group's list is cached separately
  final Map<String, List<Map<String, dynamic>>> _byGroup = {};
  final Map<String, bool> _loading = {};
  String? error;

  List<Map<String, dynamic>> hangoutsFor(String groupId) =>
      _byGroup[groupId] ?? [];

  bool isLoading(String groupId) => _loading[groupId] ?? false;

  Future<void> loadHangouts(String groupId) async {
    _loading[groupId] = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiService.instance.getGroupHangouts(groupId);
      _byGroup[groupId] = data;
    } catch (e) {
      error = e.toString();
    } finally {
      _loading[groupId] = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createHangout(String groupId, String title, {String? plannedFor}) async {
    final hangout = await ApiService.instance.createHangout(groupId, title: title, plannedFor: plannedFor);
    _byGroup[groupId] = [hangout, ...(_byGroup[groupId] ?? [])];
    notifyListeners();
    return hangout;
  }

  Future<void> deleteHangout(String hangoutId, String groupId) async {
    await ApiService.instance.deleteHangout(hangoutId);
    _byGroup[groupId] = (_byGroup[groupId] ?? [])
        .where((h) => h['id'] != hangoutId)
        .toList();
    notifyListeners();
  }

  Future<void> submitPreferences(String hangoutId, String groupId, Map<String, dynamic> prefs) async {
    await ApiService.instance.submitPreferences(hangoutId, prefs);
    // Reload so response_summary updates
    await loadHangouts(groupId);
  }
}
