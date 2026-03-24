// ─────────────────────────────────────────────────────────────
// photos_screen.dart  –  Shared photo album
// Mirrors the React <PhotoAlbum> component
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/sample_data.dart';
import '../providers/photo_provider.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PhotoProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: provider.isLocked
          ? _LockedView(onUnlock: provider.toggleLock)
          : _AlbumView(provider: provider),
    );
  }
}

// ── Locked state ───────────────────────────────────────────────
class _LockedView extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockedView({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F3FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDDD6FE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.lock, size: 36, color: AppTheme.purple),
            ),
            const SizedBox(height: 16),
            const Text(
              'Album Locked Until Tomorrow!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const SubTitle('Photos will be revealed at 8:00 AM on March 9th.\nGet ready for the big reveal! 🎉'),
            const SizedBox(height: 16),
            const Text(
              '12:34:56',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onUnlock,
              child: const Text('Preview (Demo)'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Unlocked album ─────────────────────────────────────────────
class _AlbumView extends StatelessWidget {
  final PhotoProvider provider;
  const _AlbumView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          'Shared Album 📸',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const SubTitle('College Squad • March 8, 2026'),
        const SizedBox(height: 16),

        // Upload card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Add Your Photos'),
                const SizedBox(height: 4),
                const SubTitle('Share your favorite moments from today'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => provider.addPhoto(Photo(
                      id: DateTime.now().toString(),
                      url: imgGroup,
                      uploadedBy: 'You',
                      likes: 0,
                      comments: 0,
                    )),
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Upload Photos'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppBadge('${provider.photos.length} photos'),
                    const SizedBox(width: 6),
                    const AppBadge('4 contributors', outlined: true),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Photo list
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle('Album Photos'),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Download All',
                  style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...provider.photos.asMap().entries.map((entry) {
          final i = entry.key;
          final photo = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PhotoCard(photo: photo, colorIndex: i, provider: provider),
          );
        }),

        const SizedBox(height: 8),

        // Quests card
        Card(
          color: const Color(0xFFF0FDF4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFBBF7D0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SectionTitle('Daily Quests'),
                    const SizedBox(width: 8),
                    AppBadge(
                      '${provider.quests.where((q) => q.completed).length}/${provider.quests.length} Complete',
                      color: AppTheme.green,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const SubTitle('Complete quests to unlock digital stickers!'),
                const SizedBox(height: 12),
                ...provider.quests.map((quest) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: quest.completed
                                    ? AppTheme.green
                                    : Colors.transparent,
                                border: Border.all(
                                  color: quest.completed
                                      ? AppTheme.green
                                      : AppTheme.border,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: quest.completed
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(quest.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: quest.completed
                                      ? const Color(0xFF0F172A)
                                      : AppTheme.mutedForeground,
                                )),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: provider.toggleLock,
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Lock Album (Demo Feature)'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Photo card ─────────────────────────────────────────────────
class _PhotoCard extends StatelessWidget {
  final Photo photo;
  final int colorIndex;
  final PhotoProvider provider;

  const _PhotoCard({
    required this.photo,
    required this.colorIndex,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          AspectRatio(
            aspectRatio: 4 / 3,
            child: NetImage(photo.url),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    MemberAvatar(
                        name: photo.uploadedBy,
                        colorIndex: colorIndex,
                        radius: 14),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(photo.uploadedBy,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 13)),
                        const Text('2 hours ago',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.mutedForeground)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => provider.likePhoto(photo.id),
                      icon: const Icon(Icons.favorite_border, size: 16),
                      label: Text('${photo.likes}'),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4)),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text('${photo.comments}'),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
