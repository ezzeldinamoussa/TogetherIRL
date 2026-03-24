// ─────────────────────────────────────────────────────────────
// group_provider.dart  –  State for group creation
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../models/models.dart';

class GroupProvider extends ChangeNotifier {
  String groupName = '';
  List<Member> members = [
    Member(id: '1', name: 'You', email: 'you@email.com', preferencesSet: true),
  ];

  void setGroupName(String name) {
    groupName = name;
    notifyListeners();
  }

  void addMember(String email) {
    if (email.isEmpty) return;
    members = [
      ...members,
      Member(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: email.split('@')[0],
        email: email,
        preferencesSet: false,
      ),
    ];
    notifyListeners();
  }

  void removeMember(String id) {
    members = members.where((m) => m.id != id).toList();
    notifyListeners();
  }

  bool get canCreate => groupName.isNotEmpty && members.length >= 2;
}
