import 'dart:convert';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _activeSessions = await ApiService.instance.getActiveSessions();
    } catch (_) {
      _activeSessions = [];
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
                              onTap: () {
                                // Expand detail below; for now tap shows the full card
                              },
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
                              label: 'Collections',
                              icon: Icons.photo_album_rounded,
                              iconColor: const Color(0xFF4F46E5),
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

                  // ── Empty state or start prompt ───────────────
                  if (_activeSessions.isEmpty)
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
      floatingActionButton: _activeSessions.isNotEmpty
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
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.mutedForeground)),
            ],
          ),
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

  String get _myUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      _detail = await ApiService.instance
          .getPhotoSession(widget.session['id'] as String);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _closesLabel() {
    final closes =
        DateTime.parse(widget.session['closes_at'] as String).toLocal();
    return 'Closes ${closes.month}/${closes.day} at midnight';
  }

  Future<void> _uploadPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 70);
    if (images.isEmpty) return;

    setState(() => _acting = true);
    try {
      final base64List = await Future.wait(
        images.map((img) async {
          final bytes = await img.readAsBytes();
          return base64Encode(bytes);
        }),
      );
      await ApiService.instance.uploadSessionPhotos(
          widget.session['id'] as String, base64List);
      await _loadDetail();
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
    if (mounted) setState(() => _acting = false);
  }

  Future<void> _skip() async {
    setState(() => _acting = true);
    try {
      await ApiService.instance
          .skipPhotoSession(widget.session['id'] as String);
      await _loadDetail();
    } catch (_) {}
    if (mounted) setState(() => _acting = false);
  }

  Future<void> _undo() async {
    setState(() => _acting = true);
    try {
      await ApiService.instance
          .undoPhotoAction(widget.session['id'] as String);
      await _loadDetail();
    } catch (_) {}
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
                    Container(
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
                          Text(groupName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
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
                  ? const Center(child: CircularProgressIndicator())
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
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: NetImage(allPhotos[i]),
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

  @override
  void initState() {
    super.initState();
    if (widget.groups.isNotEmpty) _selectedGroup = widget.groups.first;
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
      await ApiService.instance
          .createPhotoSession(_selectedGroup!.id, title);
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
                      onTap: () => setState(() => _selectedGroup = g),
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

