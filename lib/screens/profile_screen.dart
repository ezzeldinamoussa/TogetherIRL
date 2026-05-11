import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String? _error;
  String? _success;

  static const _dietaryOptions = [
    'Vegetarian', 'Vegan', 'Gluten-Free',
    'Dairy-Free', 'Halal', 'Nut Allergy',
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
      _maxDistance = ((profile['max_travel_distance_km'] as num?)?.toDouble()) ?? 10;
      final restrictions = profile['dietary_restrictions'] as List? ?? [];
      _dietaryRestrictions.addAll(restrictions.cast<String>());
    } catch (_) {}
    setState(() => _loading = false);
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
      setState(() => _success = 'Profile saved!');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Avatar ──────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Display name ────────────────────────────────
                const Text('Display Name',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                // ── Bio ─────────────────────────────────────────
                const Text('Bio',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Always hungry 🍜',
                  ),
                ),
                const SizedBox(height: 20),

                // ── Dietary restrictions ────────────────────────
                const Text('Dietary Restrictions',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text(
                  'These are shared with your group when planning hangouts.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.mutedForeground),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _dietaryOptions.map((option) {
                    final selected = _dietaryRestrictions.contains(option);
                    return GestureDetector(
                      onTap: () => setState(() => selected
                          ? _dietaryRestrictions.remove(option)
                          : _dietaryRestrictions.add(option)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primary.withOpacity(0.1)
                              : AppTheme.secondary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? AppTheme.primary
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── Max travel distance ─────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Max Travel Distance',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${_maxDistance.round()} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _maxDistance,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _maxDistance = v),
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 km', style: TextStyle(fontSize: 11, color: AppTheme.mutedForeground)),
                    Text('50 km', style: TextStyle(fontSize: 11, color: AppTheme.mutedForeground)),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                if (_success != null) ...[
                  const SizedBox(height: 16),
                  Text(_success!,
                      style: const TextStyle(
                          color: AppTheme.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 24),

                // ── Save ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.primary,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Profile',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Sign out ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Supabase.instance.client.auth.signOut(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Sign Out'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
