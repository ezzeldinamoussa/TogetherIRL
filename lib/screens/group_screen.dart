// ─────────────────────────────────────────────────────────────
// group_screen.dart  –  Create a group & set preferences
// Mirrors the React <GroupManager> component
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _groupNameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),

          // ── Group name ───────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Group Details'),
                  const SizedBox(height: 4),
                  const SubTitle('Give your group a fun name'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., College Squad, Foodie Friends',
                    ),
                    onChanged: provider.setGroupName,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Members ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Group Members'),
                  const SizedBox(height: 4),
                  const SubTitle('Invite friends to join'),
                  const SizedBox(height: 12),

                  // Invite row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            hintText: 'friend@email.com',
                          ),
                          onSubmitted: (_) => _addMember(provider),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _addMember(provider),
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('Invite'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Member list
                  ...provider.members.asMap().entries.map((entry) {
                    final i = entry.key;
                    final member = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            MemberAvatar(name: member.name, colorIndex: i),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        member.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      if (!member.preferencesSet) ...[
                                        const SizedBox(width: 6),
                                        const AppBadge(
                                          'Pending preferences',
                                          outlined: true,
                                        ),
                                      ],
                                    ],
                                  ),
                                  SubTitle(member.email),
                                ],
                              ),
                            ),
                            if (member.id != '1')
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () =>
                                    provider.removeMember(member.id),
                                color: AppTheme.mutedForeground,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Preferences ──────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Set Your Preferences'),
                  const SizedBox(height: 4),
                  const SubTitle(
                      'Help us plan the perfect day for your group'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showPreferencesSheet(context),
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Configure Preferences'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Create button ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.canCreate ? () {} : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Create Group & Start Planning'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
    );
  }

  void _addMember(GroupProvider provider) {
    provider.addMember(_emailController.text.trim());
    _emailController.clear();
  }

  // ── Preferences bottom sheet ───────────────────────────────
  void _showPreferencesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PreferencesSheet(),
    );
  }
}

// ── Preferences bottom sheet content ──────────────────────────
class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet();

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  final Set<String> _selectedCuisines = {};
  final Set<String> _selectedDiets = {};
  final Set<String> _selectedActivities = {};
  final _budgetController = TextEditingController();
  final _distanceController = TextEditingController();

  static const _cuisines = ['Italian', 'Mexican', 'Asian', 'American', 'Mediterranean'];
  static const _diets = ['Vegetarian', 'Vegan', 'Gluten-Free', 'Dairy-Free', 'Halal'];
  static const _activities = ['Dining', 'Coffee', 'Dessert', 'Activities', 'Shopping'];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('Your Preferences'),
            const SizedBox(height: 4),
            const SubTitle('Tell us what you like and any dietary restrictions'),
            const SizedBox(height: 20),

            _prefSection(
              'Favorite Cuisines',
              _cuisines,
              _selectedCuisines,
            ),
            const SizedBox(height: 16),
            _prefSection(
              'Dietary Restrictions',
              _diets,
              _selectedDiets,
            ),
            const SizedBox(height: 16),

            const Text('Budget per person',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: r'$50', prefixText: r'$ '),
            ),
            const SizedBox(height: 16),

            _prefSection(
              'Activity Types',
              _activities,
              _selectedActivities,
            ),
            const SizedBox(height: 16),

            const Text('Max Travel Distance',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _distanceController,
              decoration: const InputDecoration(hintText: '5 miles'),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Save Preferences'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _prefSection(String title, List<String> options, Set<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  selected.remove(option);
                } else {
                  selected.add(option);
                }
              }),
              child: AppBadge(
                option,
                color: isSelected ? AppTheme.primary : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
