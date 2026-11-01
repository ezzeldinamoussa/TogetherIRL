import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../providers/group_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  List<Map<String, dynamic>> _activeSessions = [];
  List<Map<String, dynamic>> _pastSessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Independent requests, so they go out together.
      final results = await Future.wait([
        ApiService.instance.getActiveSessions(),
        ApiService.instance.getPastSessions(),
      ]);
      _activeSessions = results[0];
      _pastSessions = results[1];
    } catch (e) {
      // Swallowing this made a dead backend look exactly like "no memories
      // yet", which sent us hunting through the database for missing rows.
      _error = 'Could not load your memories. Pull down to try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showCreateSession() {
    final groups = context.read<GroupProvider>().groups;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateSessionSheet(groups: groups, onCreated: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // ── Gradient header ───────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                          20,
                          MediaQuery.of(context).padding.top + 16,
                          20,
                          24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Memories',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Capture your hangouts',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              // Active sessions count pill
                              if (_activeSessions.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_activeSessions.length} active',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF22C55E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Load failure ──────────────────────────────
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off_rounded,
                                size: 18, color: Color(0xFFDC2626)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFFB91C1C))),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Active sessions horizontal scroll ─────────
                  if (_activeSessions.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Text(
                          'Active Collections',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          itemCount: _activeSessions.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _ActiveSessionChip(
                              session: _activeSessions[i],
                              onTap: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Full detail cards
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ActiveSessionCard(
                              session: _activeSessions[i],
                              onRefresh: _load,
                            ),
                          ),
                          childCount: _activeSessions.length,
                        ),
                      ),
                    ),
                  ],

                  // ── Stats ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: '${_activeSessions.length}',
                              label: 'Active',
                              icon: Icons.photo_album_rounded,
                              iconColor: const Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              value: '${_pastSessions.length}',
                              label: 'Memories',
                              icon: Icons.auto_awesome_rounded,
                              iconColor: const Color(0xFF7C3AED),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              value: '${context.read<GroupProvider>().groups.length}',
                              label: 'Groups',
                              icon: Icons.people_rounded,
                              iconColor: const Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Past collections ──────────────────────────
                  if (_pastSessions.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                        child: Text(
                          'Your Memories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child:
                                _PastSessionCard(session: _pastSessions[i]),
                          ),
                          childCount: _pastSessions.length,
                        ),
                      ),
                    ),
                  ],

                  // ── Empty state or start prompt ───────────────
                  if (_activeSessions.isEmpty && _pastSessions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.photo_library_outlined,
                                  size: 36, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No memories yet',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start a photo collection during your next hangout and everyone can upload their shots.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: _showCreateSession,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Start a Collection',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
      floatingActionButton: (_activeSessions.isNotEmpty ||
              _pastSessions.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _showCreateSession,
              backgroundColor: const Color(0xFF4F46E5),
              icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
              label: const Text('New Collection',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

// ── Horizontal active session chip card ───────────────────────
class _ActiveSessionChip extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;

  const _ActiveSessionChip({required this.session, required this.onTap});

  String _closesLabel() {
    try {
      final closes =
          DateTime.parse(session['closes_at'] as String).toLocal();
      final now = DateTime.now();
      final diff = closes.difference(now);
      if (diff.inHours > 0) return '${diff.inHours}h left';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m left';
      return 'Closing soon';
    } catch (_) {
      return 'Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = session['groups'] as Map<String, dynamic>? ?? {};
    final groupEmoji = group['emoji'] as String? ?? '🎉';
    final groupName = group['name'] as String? ?? 'Group';
    final title = session['title'] as String? ?? 'Photo Collection';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(groupEmoji, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                // Live dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              groupName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _closesLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Stacked, not a row: three of these sit side by side and a fixed
      // 40px icon beside the text left the label no room to lay out.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.mutedForeground)),
        ],
      ),
    );
  }
}

// ── Active session card ────────────────────────────────────────
class _ActiveSessionCard extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onRefresh;

  const _ActiveSessionCard({required this.session, required this.onRefresh});

  @override
  State<_ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends State<_ActiveSessionCard> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _acting = false;
  String? _progressLabel;
  String? _detailError;

  String get _myUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _detailError = null;
    });
    try {
      _detail = await ApiService.instance
          .getPhotoSession(widget.session['id'] as String);
    } catch (e) {
      // Swallowing this is what hid a 500 on this route: the card fell back
      // to its empty state, so a failing request was indistinguishable from
      // a collection nobody had responded to yet.
      _detailError = "Couldn't load this collection.";
    }
    if (mounted) setState(() => _loading = false);
  }

  // The window is a rolling 24 hours from when the collection was created
  // (see _createSession), not midnight, so this counts down instead of
  // naming a time of day that was never what the backend does.
  String _closesLabel() {
    try {
      final closes =
          DateTime.parse(widget.session['closes_at'] as String).toLocal();
      final diff = closes.difference(DateTime.now());
      if (diff.isNegative) return 'Closed';
      if (diff.inHours > 0) return 'Closes in ${diff.inHours}h';
      if (diff.inMinutes > 0) return 'Closes in ${diff.inMinutes}m';
      return 'Closing now';
    } catch (_) {
      return 'Open';
    }
  }

  // Photos travel as base64 inside a JSON body, which inflates them by a
  // third, so they are capped on the way out of the picker — a raw phone
  // photo is several MB and a handful of them built one request large enough
  // to stall on a phone connection.
  static const _maxDimension = 1600.0;
  static const _uploadChunkSize = 3;

  Future<void> _uploadPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
    );
    if (images.isEmpty) return;

    setState(() {
      _acting = true;
      _progressLabel = 'Preparing ${images.length} photo(s)…';
    });

    var sent = 0;
    try {
      // Sent in small batches instead of one request. The backend appends
      // each batch, so a dropped connection costs only the batch in flight
      // rather than the whole upload.
      for (var start = 0; start < images.length; start += _uploadChunkSize) {
        final end = math.min(start + _uploadChunkSize, images.length);

        final base64Chunk = await Future.wait(
          images
              .sublist(start, end)
              .map((img) async => base64Encode(await img.readAsBytes())),
        );

        await ApiService.instance.uploadSessionPhotos(
            widget.session['id'] as String, base64Chunk);

        sent = end;
        if (mounted) {
          setState(() =>
              _progressLabel = 'Uploaded $sent of ${images.length}…');
        }
      }
      await _loadDetail();
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sent == 0
              ? 'Upload failed — nothing was saved. $e'
              : 'Uploaded $sent of ${images.length}, then failed. '
                  'Tap Upload Photos again to send the rest.'),
        ));
      }
    }
    if (mounted) {
      setState(() {
        _acting = false;
        _progressLabel = null;
      });
    }
  }

  Future<void> _skip() async {
    await _act(
      () => ApiService.instance.skipPhotoSession(widget.session['id'] as String),
      'Could not skip',
    );
  }

  Future<void> _undo() async {
    await _act(
      () => ApiService.instance.undoPhotoAction(widget.session['id'] as String),
      'Could not undo',
    );
  }

  /// Runs [action], then reloads. A failure used to be swallowed, which left
  /// the card showing the old state as though the tap had worked.
  Future<void> _act(Future<void> Function() action, String failureMessage) async {
    setState(() => _acting = true);
    try {
      await action();
      await _loadDetail();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$failureMessage: $e')));
      }
    }
    if (mounted) setState(() => _acting = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final group = session['groups'] as Map<String, dynamic>? ?? {};
    final groupName = group['name'] as String? ?? 'Group';
    final groupEmoji = group['emoji'] as String? ?? '🎉';
    final title = session['title'] as String? ?? 'Photo Collection';

    final detail = _detail;
    final myStatus = detail?['my_status'] as String? ?? 'pending';
    final responded = detail?['responded'] as int? ?? 0;
    final total = detail?['total'] as int? ?? 0;
    final members =
        (detail?['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final allPhotos =
        (detail?['all_photos'] as List?)?.cast<String>() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient top strip
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$responded / $total responded',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Flexible so a long group name shortens instead of
                    // pushing the countdown off the right edge.
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(groupEmoji,
                                style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(groupName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 3),
                    Text(_closesLabel(),
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_detailError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 18, color: AppTheme.mutedForeground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_detailError!,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.mutedForeground)),
                  ),
                  TextButton(
                      onPressed: _loadDetail, child: const Text('Retry')),
                ],
              ),
            )
          else ...[
            // Member statuses
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: const Text('Upload status',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            ...members.asMap().entries.map((e) {
              final i = e.key;
              final m = e.value;
              final status = m['status'] as String? ?? 'pending';
              final isMe = m['user_id'] == _myUserId;
              final color = AppTheme
                  .memberColors[i % AppTheme.memberColors.length];
              final name = isMe
                  ? 'You'
                  : (m['display_name'] as String? ?? 'Member');

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color,
                      child: Text(name[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500)),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // Action row
            Padding(
              padding: const EdgeInsets.all(16),
              child: _acting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        if (_progressLabel != null) ...[
                          const SizedBox(width: 12),
                          Text(_progressLabel!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.mutedForeground)),
                        ],
                      ],
                    )
                  : myStatus == 'uploaded'
                      ? Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppTheme.green, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "You've uploaded your photos",
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.green,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(
                                onPressed: _undo,
                                child: const Text('Undo')),
                          ],
                        )
                      : myStatus == 'skipped'
                          ? Row(
                              children: [
                                const Icon(Icons.cancel_outlined,
                                    color: AppTheme.mutedForeground,
                                    size: 18),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text('You skipped',
                                      style: TextStyle(
                                          color:
                                              AppTheme.mutedForeground)),
                                ),
                                TextButton(
                                    onPressed: _undo,
                                    child: const Text('Undo')),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _uploadPhotos,
                                    icon: const Icon(Icons.upload,
                                        size: 16),
                                    label:
                                        const Text('Upload Photos'),
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.primary),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                    onPressed: _skip,
                                    child: const Text('Skip')),
                              ],
                            ),
            ),

            // Uploaded photos grid
            if (allPhotos.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: allPhotos.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () =>
                        openPhotoViewer(context, allPhotos, i, title),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: NetImage(allPhotos[i]),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'uploaded':
        return const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle, color: AppTheme.green, size: 16),
          SizedBox(width: 4),
          Text('Done',
              style: TextStyle(
                  color: AppTheme.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]);
      case 'skipped':
        return const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cancel_outlined,
              color: AppTheme.mutedForeground, size: 16),
          SizedBox(width: 4),
          Text('Skipped',
              style:
                  TextStyle(color: AppTheme.mutedForeground, fontSize: 13)),
        ]);
      default:
        return const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.schedule,
              color: AppTheme.mutedForeground, size: 16),
          SizedBox(width: 4),
          Text('Pending',
              style:
                  TextStyle(color: AppTheme.mutedForeground, fontSize: 13)),
        ]);
    }
  }
}

// ── Create session sheet ───────────────────────────────────────
class _CreateSessionSheet extends StatefulWidget {
  final List<Group> groups;
  final VoidCallback onCreated;
  const _CreateSessionSheet({required this.groups, required this.onCreated});

  @override
  State<_CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<_CreateSessionSheet> {
  final _titleController = TextEditingController();
  Group? _selectedGroup;
  bool _loading = false;
  String? _error;

  // Hangouts belonging to the selected group. Linking a collection to one is
  // optional, but it is what lets a finished memory say which hangout it came
  // from instead of only naming the group.
  List<Map<String, dynamic>> _hangouts = [];
  String? _selectedHangoutId;
  bool _loadingHangouts = false;

  @override
  void initState() {
    super.initState();
    if (widget.groups.isNotEmpty) {
      _selectedGroup = widget.groups.first;
      _loadHangouts();
    }
  }

  Future<void> _loadHangouts() async {
    final group = _selectedGroup;
    if (group == null) return;
    setState(() {
      _loadingHangouts = true;
      _hangouts = [];
      _selectedHangoutId = null;
    });
    try {
      final all = await ApiService.instance.getGroupHangouts(group.id);
      // Only hangouts that have actually happened are worth attaching
      // photos to, newest first.
      _hangouts = all
          .where((h) => h['status'] != 'cancelled')
          .take(8)
          .toList();
    } catch (_) {
      // A collection does not need a hangout, so a failure here just leaves
      // the picker empty rather than blocking the whole sheet.
      _hangouts = [];
    }
    if (mounted) setState(() => _loadingHangouts = false);
  }

  void _selectGroup(Group g) {
    if (_selectedGroup?.id == g.id) return;
    setState(() => _selectedGroup = g);
    _loadHangouts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_selectedGroup == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this collection a title');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.instance.createPhotoSession(
        _selectedGroup!.id,
        title,
        hangoutPlanId: _selectedHangoutId,
      );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Start Photo Collection',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Opens a 24hr window for everyone to upload.',
              style: TextStyle(color: AppTheme.mutedForeground)),
          const SizedBox(height: 20),

          if (widget.groups.length > 1) ...[
            const Text('Group',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.groups.map((g) {
                  final sel = _selectedGroup?.id == g.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _selectGroup(g),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.primary
                              : AppTheme.secondary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${g.emoji} ${g.name}',
                            style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_loadingHangouts || _hangouts.isNotEmpty) ...[
            const Text('Hangout (optional)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_loadingHangouts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _hangouts.map((h) {
                    final id = h['id'] as String;
                    final sel = _selectedHangoutId == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        // Tapping the selected chip clears it, since the
                        // link is optional and there is no other way out.
                        onTap: () => setState(
                            () => _selectedHangoutId = sel ? null : id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                sel ? AppTheme.primary : AppTheme.secondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (h['title'] as String?) ?? 'Hangout',
                            style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
          ],

          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g., Brunch & Dessert Adventure',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _create,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primary,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Start Collection',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Full-screen photo viewer ───────────────────────────────────
// Opens from any photo grid. Before this the grids were the only way to see
// an uploaded photo, at thumbnail size.
void openPhotoViewer(
  BuildContext context,
  List<String> photos,
  int initialIndex,
  String title,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _PhotoViewer(
        photos: photos,
        initialIndex: initialIndex,
        title: title,
      ),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final String title;

  const _PhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            Text('${_index + 1} of ${widget.photos.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: NetImage(widget.photos[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ── A closed collection ────────────────────────────────────────
// The finished memory. Everything here comes from GET /api/photos/past,
// which is the only route that returns collections whose window has shut.
class _PastSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _PastSessionCard({required this.session});

  static const _previewCount = 6;
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _dateLabel() {
    try {
      final closed = DateTime.parse(session['closes_at'] as String).toLocal();
      return '${_months[closed.month - 1]} ${closed.day}, ${closed.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = (session['photos'] as List?)?.cast<String>() ?? const [];
    final group = session['groups'] as Map<String, dynamic>? ?? {};
    final hangout = session['hangout_plans'] as Map<String, dynamic>?;
    final title = session['title'] as String? ?? 'Photo Collection';

    final preview = photos.take(_previewCount).toList();
    final hidden = photos.length - preview.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          // The group name gives way first; the date is a
                          // fixed width and always worth showing in full.
                          Flexible(
                            child: Text(
                              '${group['emoji'] ?? '🎉'} ${group['name'] ?? 'Group'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mutedForeground),
                            ),
                          ),
                          const Text('  ·  ',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mutedForeground)),
                          Text(_dateLabel(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mutedForeground)),
                        ],
                      ),
                      if (hangout != null && hangout['title'] is String) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.event_rounded,
                                size: 12, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(hangout['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_rounded,
                          size: 12, color: AppTheme.mutedForeground),
                      const SizedBox(width: 4),
                      Text('${photos.length}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: preview.length,
              itemBuilder: (context, i) {
                // The last preview tile carries the overflow count, and still
                // opens the viewer at its own photo.
                final isOverflowTile = hidden > 0 && i == preview.length - 1;
                return GestureDetector(
                  onTap: () => openPhotoViewer(context, photos, i, title),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NetImage(preview[i]),
                        if (isOverflowTile)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            alignment: Alignment.center,
                            child: Text('+$hidden',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
