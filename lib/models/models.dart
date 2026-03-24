// ─────────────────────────────────────────────────────────────
// models.dart  –  All plain-data classes used across the app
// ─────────────────────────────────────────────────────────────

// ── Group ────────────────────────────────────────────────────
class Group {
  final String id;
  final String name;
  final List<Member> members;
  final String? nextHangout;
  final String? imageUrl;

  const Group({
    required this.id,
    required this.name,
    required this.members,
    this.nextHangout,
    this.imageUrl,
  });
}

// ── Member ───────────────────────────────────────────────────
class Member {
  final String id;
  final String name;
  final String email;
  final bool preferencesSet;

  const Member({
    required this.id,
    required this.name,
    required this.email,
    this.preferencesSet = false,
  });
}

// ── ItineraryStop ────────────────────────────────────────────
class ItineraryStop {
  final String id;
  final String type;       // e.g. "Brunch", "Coffee", "Dessert"
  final String name;
  final String time;
  final String duration;
  final String address;
  final String distance;
  final String priceRange; // "$", "$$", "$$$"
  final double rating;
  final String imageUrl;
  final int matchScore;    // 0-100

  const ItineraryStop({
    required this.id,
    required this.type,
    required this.name,
    required this.time,
    required this.duration,
    required this.address,
    required this.distance,
    required this.priceRange,
    required this.rating,
    required this.imageUrl,
    required this.matchScore,
  });
}

// ── BillItem ─────────────────────────────────────────────────
class BillItem {
  final String id;
  final String name;
  final double price;
  List<String> selectedBy; // list of member IDs

  BillItem({
    required this.id,
    required this.name,
    required this.price,
    required this.selectedBy,
  });

  BillItem copyWith({List<String>? selectedBy}) => BillItem(
        id: id,
        name: name,
        price: price,
        selectedBy: selectedBy ?? this.selectedBy,
      );
}

// ── Photo ────────────────────────────────────────────────────
class Photo {
  final String id;
  final String url;
  final String uploadedBy;
  int likes;
  int comments;

  Photo({
    required this.id,
    required this.url,
    required this.uploadedBy,
    required this.likes,
    required this.comments,
  });
}

// ── Quest ────────────────────────────────────────────────────
class Quest {
  final String id;
  final String description;
  bool completed;

  Quest({required this.id, required this.description, this.completed = false});
}

// ── Hangout (Scrapbook entry) ────────────────────────────────
class Hangout {
  final String id;
  final String date;
  final String title;
  final String group;
  final List<String> photoUrls;
  final double totalSpent;
  final int places;
  final int rating;
  final List<String> highlights;
  final String foodReview;

  const Hangout({
    required this.id,
    required this.date,
    required this.title,
    required this.group,
    required this.photoUrls,
    required this.totalSpent,
    required this.places,
    required this.rating,
    required this.highlights,
    required this.foodReview,
  });
}
