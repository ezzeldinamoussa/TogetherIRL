// ─────────────────────────────────────────────────────────────
// bill_provider.dart  –  State management for the bill splitter
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/sample_data.dart';

class BillProvider extends ChangeNotifier {
  List<BillItem> _items = sampleBillItems;
  int _tipPercent = 18;

  List<BillItem> get items => _items;
  int get tipPercent => _tipPercent;

  // Total before tip
  double get subtotal =>
      _items.fold(0, (sum, item) => sum + item.price);

  // Tip amount
  double get tipAmount => subtotal * _tipPercent / 100;

  // Grand total
  double get grandTotal => subtotal + tipAmount;

  // Toggle whether a member selected an item
  void toggleItem(String itemId, String memberId) {
    _items = _items.map((item) {
      if (item.id != itemId) return item;
      final updated = List<String>.from(item.selectedBy);
      if (updated.contains(memberId)) {
        updated.remove(memberId);
      } else {
        updated.add(memberId);
      }
      return item.copyWith(selectedBy: updated);
    }).toList();
    notifyListeners();
  }

  // Update tip percentage
  void setTip(int percent) {
    _tipPercent = percent;
    notifyListeners();
  }

  // Calculate what one member owes (their share of items + proportional tip)
  double memberTotal(String memberId) {
    double food = 0;
    for (final item in _items) {
      if (item.selectedBy.contains(memberId)) {
        food += item.price / item.selectedBy.length;
      }
    }
    final foodShare = subtotal > 0 ? food / subtotal : 0;
    return food + (tipAmount * foodShare);
  }
}
