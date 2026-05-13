import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/group_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final Set<String> _dietaryRestrictions = {};
  double _maxDistance = 10;

  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;
  String? _error;
  String? _success;

  static const _dietaryOptions = [
    ('🥗', 'Vegetarian'),
    ('🌱', 'Vegan'),
    ('🌾', 'Gluten-Free'),
    ('🥛', 'Dairy-Free'),
    ('☪️', 'Halal'),
    ('🥜', 'Nut Allergy'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ApiService.instance.getMyProfile();
      _nameController.text = profile['display_name'] as String? ?? '';
      _bioController.text = profile['bio'] as String? ?? '';
      _maxDistance =
          ((profile['max_travel_distance_km'] as num?)?.toDouble()) ?? 10;
      final restrictions = profile['dietary_restrictions'] as List? ?? [];
      _dietaryRestrictions.addAll(restrictions.cast<String>());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; _success = null; });
    try {
      await ApiService.instance.updateMyProfile({
        'display_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'dietary_restrictions': _dietaryRestrictions.toList(),
        'max_travel_distance_km': _maxDistance.round(),
      });
      setState(() { _success = 'Profile saved!'; _editMode = false; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _initials {
    final name = _nameController.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  String get _email =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  String get _memberSince {
    final created =
        Supabase.instance.client.auth.currentUser?.createdAt;
    if (created == null) return '';
    final dt = DateTime.parse(created);
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Member since ${months[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final groupCount = context.watch<GroupProvider>().groups.length;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Gradient hero header ───────────────────────────
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Gradient background
                      Container(
                        height: topPad + 180,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(32)),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_ios_new,
                                      color: Colors.white, size: 20),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _editMode = !_editMode),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              Colors.white.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _editMode
                                              ? Icons.close
                                              : Icons.edit_outlined,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _editMode ? 'Cancel' : 'Edit',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Avatar — centered, overlapping header bottom
                      Positioned(
                        bottom: -52,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5)
                                        .withOpacity(0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _initials,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Name + email + member since ────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 68, 20, 0),
                    child: Column(
                      children: [
                        Text(
                          _nameController.text.isEmpty
                              ? 'Your Name'
                              : _nameController.text,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        if (_memberSince.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _memberSince,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // ── Stats row ────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatPill(
                              icon: Icons.people_rounded,
                              value: '$groupCount',
                              label: groupCount == 1 ? 'Group' : 'Groups',
                              color: const Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 12),
                            _StatPill(
                              icon: Icons.straighten_rounded,
                              value: '${_maxDistance.round()} km',
                              label: 'Travel Range',
                              color: const Color(0xFF0EA5E9),
                            ),
                            const SizedBox(width: 12),
                            _StatPill(
                              icon: Icons.restaurant_menu_rounded,
                              value: '${_dietaryRestrictions.length}',
                              label: 'Prefs',
                              color: const Color(0xFF0D9488),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Bio card ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'About',
                    icon: Icons.person_outline_rounded,
                    child: _editMode
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _EditField(
                                controller: _nameController,
                                label: 'Display Name',
                                hint: 'Your name',
                                textCapitalization: TextCapitalization.words,
                                onChanged: () => setState(() {}),
                              ),
                              const SizedBox(height: 14),
                              _EditField(
                                controller: _bioController,
                                label: 'Bio',
                                hint: 'Always hungry 🍜',
                                maxLines: 3,
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_bioController.text.isNotEmpty)
                                Text(
                                  _bioController.text,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF334155),
                                    height: 1.5,
                                  ),
                                )
                              else
                                const Text(
                                  'No bio yet. Tap Edit to add one.',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF94A3B8),
                                      fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                  ),
                ),

                // ── Dietary restrictions ───────────────────────────
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Dietary Preferences',
                    icon: Icons.restaurant_rounded,
                    subtitle: 'Shared with your group when planning',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dietaryOptions.map((opt) {
                        final emoji = opt.$1;
                        final label = opt.$2;
                        final selected = _dietaryRestrictions.contains(label);
                        return GestureDetector(
                          onTap: _editMode
                              ? () => setState(() => selected
                                  ? _dietaryRestrictions.remove(label)
                                  : _dietaryRestrictions.add(label))
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF4F46E5).withOpacity(0.1)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(emoji,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.check_circle,
                                      size: 14, color: Color(0xFF4F46E5)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // ── Travel distance ────────────────────────────────
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Travel Distance',
                    icon: Icons.place_outlined,
                    subtitle:
                        'Max distance you\'re willing to travel for a hangout',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('How far will you go?',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF4F46E5).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_maxDistance.round()} km',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF4F46E5),
                            inactiveTrackColor:
                                const Color(0xFF4F46E5).withOpacity(0.15),
                            thumbColor: const Color(0xFF4F46E5),
                            overlayColor:
                                const Color(0xFF4F46E5).withOpacity(0.12),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _maxDistance,
                            min: 1,
                            max: 50,
                            divisions: 49,
                            onChanged: _editMode
                                ? (v) => setState(() => _maxDistance = v)
                                : null,
                          ),
                        ),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1 km',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                            Text('50 km',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Feedback / save ────────────────────────────────
                if (_editMode)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Column(
                        children: [
                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDED),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Color(0xFFEF4444), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                          GestureDetector(
                            onTap: _saving ? null : _save,
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: _saving
                                    ? null
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xFF4F46E5),
                                          Color(0xFF0EA5E9)
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                color: _saving
                                    ? const Color(0xFFE2E8F0)
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _saving
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5)
                                              .withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF4F46E5)))
                                    : const Text('Save Changes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        )),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_success != null && !_editMode)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF16A34A), size: 16),
                            const SizedBox(width: 8),
                            Text(_success!,
                                style: const TextStyle(
                                    color: Color(0xFF16A34A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Account section ────────────────────────────────
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Account',
                    icon: Icons.manage_accounts_outlined,
                    child: Column(
                      children: [
                        _AccountRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _email,
                          iconColor: const Color(0xFF4F46E5),
                        ),
                        const Divider(height: 24),
                        GestureDetector(
                          onTap: () async {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDED),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.logout_rounded,
                                    color: Color(0xFFEF4444), size: 18),
                                SizedBox(width: 12),
                                Text('Sign Out',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    )),
                                Spacer(),
                                Icon(Icons.chevron_right,
                                    color: Color(0xFFEF4444), size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }
}

// ── Stat pill ───────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

// ── Section card ────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF4F46E5).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                      size: 16, color: const Color(0xFF4F46E5)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Edit field ──────────────────────────────────────────────────
class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final VoidCallback? onChanged;

  const _EditField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          onChanged: onChanged != null ? (_) => onChanged!() : null,
          style: const TextStyle(
              fontSize: 15, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF4F46E5), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Account row ─────────────────────────────────────────────────
class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF94A3B8))),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A))),
          ],
        ),
      ],
    );
  }
}
