import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class BillProvider extends ChangeNotifier {
  final Map<String, List<Map<String, dynamic>>> _byGroup = {};
  bool loading = false;
  String? error;

  List<Map<String, dynamic>> billsFor(String groupId) =>
      _byGroup[groupId] ?? [];

  Future<void> loadBills(String groupId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _byGroup[groupId] = await ApiService.instance.getGroupBills(groupId);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createBill(Map<String, dynamic> data) async {
    final bill = await ApiService.instance.createBill(data);
    final groupId = data['group_id'] as String;
    _byGroup[groupId] = [bill, ...(_byGroup[groupId] ?? [])];
    notifyListeners();
    return bill;
  }

  Future<Map<String, dynamic>> getBillDetail(String billId) async {
    return ApiService.instance.getBill(billId);
  }

  Future<void> saveBill(String billId, Map<String, dynamic> data) async {
    await ApiService.instance.updateBill(billId, data);
  }

  void removeBill(String groupId, String billId) {
    _byGroup[groupId] = (_byGroup[groupId] ?? [])
        .where((b) => b['id'] != billId)
        .toList();
    notifyListeners();
  }
}
