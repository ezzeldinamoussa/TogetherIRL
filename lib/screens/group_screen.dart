import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/group_provider.dart';
import '../providers/group_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();

    return Scaffold(
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.groups.isEmpty
              ? _EmptyGroupsView(
                  onCreateGroup: () => _showCreateSheet(context, provider),
                )
              : RefreshIndicator(
                  onRefresh: provider.loadGroups,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: provider.groups.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GroupTile(
                        group: provider.groups[i],
                        onTap: () => _openGroup(context, provider.groups[i]),
                      ),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showCreateSheet(BuildContext context, GroupProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateGroupSheet(provider: provider),
    );
  }

  void _openGroup(BuildContext context, Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
    );
  }
}

// ── Group tile ─────────────────────────────────────────────────
class _GroupTile extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;

  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(group.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.members.isEmpty
                        ? 'Just you'
                        : '${group.members.length} member${group.members.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
                  ),
                ],
              ),
            ),
            if (group.myRole == 'admin')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}

// ── Create group sheet ─────────────────────────────────────────
class _CreateGroupSheet extends StatefulWidget {
  final GroupProvider provider;
  const _CreateGroupSheet({required this.provider});

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '🎉';
  bool _loading = false;
  String? _error;

  static const _emojis = [
    '🎉', '🍕', '🎮', '🏖️', '🍜', '☕',
    '🏕️', '🎬', '🎵', '🍔', '🥂', '🏃',
    '🎨', '🌮', '🍣', '🎭', '🧗', '🎲',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Group name is required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.provider.createGroup(name, _selectedEmoji);
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
          // Handle
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
          const Text(
            'Create a Group',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Give your crew a name and a vibe.',
            style: TextStyle(color: AppTheme.mutedForeground),
          ),
          const SizedBox(height: 20),

          // Group name
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'e.g., Friday Crew, Foodie Gang',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),

          // Emoji picker
          const Text(
            'Pick an emoji',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojis.map((e) {
              final selected = e == _selectedEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = e),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withOpacity(0.15)
                        : AppTheme.secondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Group', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Group detail screen ────────────────────────────────────────
class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _emailController = TextEditingController();
  bool _inviting = false;
  String? _inviteError;
  String? _inviteSuccess;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Group?'),
        content: const Text('This will permanently delete the group, all members, hangouts, and bills. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await context.read<GroupProvider>().deleteGroup(widget.group.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() { _inviting = true; _inviteError = null; _inviteSuccess = null; });
    try {
      await ApiService.instance.inviteMember(widget.group.id, email);
      _emailController.clear();
      setState(() => _inviteSuccess = 'Invite sent to $email');
    } on ApiException catch (e) {
      setState(() => _inviteError = e.message);
    } finally {
      setState(() => _inviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(group.emoji),
            const SizedBox(width: 8),
            Text(group.name),
          ],
        ),
        actions: [
          if (group.myRole == 'admin')
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete group',
              onPressed: _deleteGroup,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Members ─────────────────────────────────────────
          const Text(
            'Members',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          if (group.members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No members loaded. Pull to refresh.',
                style: TextStyle(color: AppTheme.mutedForeground),
              ),
            )
          else
            ...group.members.asMap().entries.map((e) {
              final i = e.key;
              final m = e.value;
              final color = AppTheme.memberColors[i % AppTheme.memberColors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color,
                      child: Text(
                        m.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        m.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (m.role == 'admin')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ── Invite ───────────────────────────────────────────
          const Text(
            'Invite someone',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'They need to have a TogetherIRL account first.',
            style: TextStyle(fontSize: 13, color: AppTheme.mutedForeground),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'friend@email.com'),
                  onSubmitted: (_) => _invite(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _inviting ? null : _invite,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                child: _inviting
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Invite'),
              ),
            ],
          ),
          if (_inviteError != null) ...[
            const SizedBox(height: 8),
            Text(_inviteError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          if (_inviteSuccess != null) ...[
            const SizedBox(height: 8),
            Text(_inviteSuccess!, style: const TextStyle(color: AppTheme.green, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────
class _EmptyGroupsView extends StatelessWidget {
  final VoidCallback onCreateGroup;
  const _EmptyGroupsView({required this.onCreateGroup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🫂', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              'No groups yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a group to start planning hangouts with your friends.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.mutedForeground),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create a Group'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
