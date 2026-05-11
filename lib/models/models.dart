// ─────────────────────────────────────────────────────────────
// models.dart  –  All plain-data classes used across the app
// ─────────────────────────────────────────────────────────────

// ── Group ────────────────────────────────────────────────────
class Group {
  final String id;
  final String name;
  final String emoji;
  final String? description;
  final String? myRole;
  final List<GroupMember> members;
  final String? createdAt;

  const Group({
    required this.id,
    required this.name,
    this.emoji = '🎉',
    this.description,
    this.myRole,
    this.members = const [],
    this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List? ?? [];
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '🎉',
      description: json['description'] as String?,
      myRole: json['my_role'] as String?,
      members: rawMembers
          .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as String?,
    );
  }
}

// ── GroupMember ──────────────────────────────────────────────
class GroupMember {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role;

  const GroupMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = 'member',
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};
    return GroupMember(
      userId: json['user_id'] as String? ?? '',
      displayName: profile['display_name'] as String? ?? 'Member',
      avatarUrl: profile['avatar_url'] as String?,
      role: json['role'] as String? ?? 'member',
    );
  }
}

// ── Member (legacy — used by BillScreen) ─────────────────────
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

// ── Photo collection window ──────────────────────────────────
enum UploadStatus { pending, done, skipped }

class PhotoCollection {
  final String hangoutId;
  final String hangoutTitle;
  final String groupName;
  final List<Member> members;
  final DateTime hangoutDate;
  final DateTime deadline; // midnight at end of day after hangout
  final Map<String, UploadStatus> memberStatuses; // memberId → status

  PhotoCollection({
    required this.hangoutId,
    required this.hangoutTitle,
    required this.groupName,
    required this.members,
    required this.hangoutDate,
    required this.deadline,
    required this.memberStatuses,
  });

  int get totalResponded =>
      memberStatuses.values.where((s) => s != UploadStatus.pending).length;
  bool get allResponded => totalResponded == members.length;
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
