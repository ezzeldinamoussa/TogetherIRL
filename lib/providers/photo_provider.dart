// ─────────────────────────────────────────────────────────────
// photo_provider.dart  –  State for the shared photo album
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/sample_data.dart';

class PhotoProvider extends ChangeNotifier {
  List<Photo> _photos = samplePhotos;
  List<Quest> _quests = sampleQuests;
  bool _isLocked = false;

  List<Photo> get photos => _photos;
  List<Quest> get quests => _quests;
  bool get isLocked => _isLocked;

  void likePhoto(String photoId) {
    for (final p in _photos) {
      if (p.id == photoId) p.likes++;
    }
    notifyListeners();
  }

  void addPhoto(Photo photo) {
    _photos = [photo, ..._photos];
    notifyListeners();
  }

  void toggleLock() {
    _isLocked = !_isLocked;
    notifyListeners();
  }
}
