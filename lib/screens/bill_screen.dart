import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/bill_provider.dart';
import '../providers/group_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  Group? _selectedGroup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final groups = context.read<GroupProvider>().groups;
    if (_selectedGroup == null && groups.isNotEmpty) {
      _selectedGroup = groups.first;
      context.read<BillProvider>().loadBills(_selectedGroup!.id);
    }
  }

  void _selectGroup(Group group) {
    setState(() => _selectedGroup = group);
    context.read<BillProvider>().loadBills(group.id);
  }

  void _showCreateBill() {
    if (_selectedGroup == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CreateBillScreen(group: _selectedGroup!),
      ),
    );
  }

  double _myOwed(List<Map<String, dynamic>> bills) {
    double total = 0;
    for (final b in bills) {
      final share = b['my_share'];
      if (share != null) total += (share as num).toDouble();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupProvider>().groups;
    final billProvider = context.watch<BillProvider>();

    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🧾', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              Text('No groups yet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('Create a group on the Home tab first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.mutedForeground)),
            ],
          ),
        ),
      );
    }

    final bills = _selectedGroup != null
        ? billProvider.billsFor(_selectedGroup!.id)
        : <Map<String, dynamic>>[];

    final myOwed = _myOwed(bills);

    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header ───────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
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
                          Text('Bills',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          SizedBox(height: 4),
                          Text('Split expenses fairly',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white70)),
                        ],
                      ),
                    ),
                    if (bills.isNotEmpty)
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
                            const Icon(Icons.attach_money_rounded,
                                size: 14, color: Color(0xFF0D9488)),
                            const SizedBox(width: 2),
                            Text(
                              'You owe: \$${myOwed.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: groups.map((group) {
                      final selected = _selectedGroup?.id == group.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _selectGroup(group),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(group.emoji,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  group.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? const Color(0xFF4F46E5)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Bills list ───────────────────────────────────────
          Expanded(
            child: billProvider.loading
                ? const Center(child: CircularProgressIndicator())
                : bills.isEmpty
                    ? _EmptyBillsState(onCreateTap: _showCreateBill)
                    : RefreshIndicator(
                        onRefresh: () =>
                            billProvider.loadBills(_selectedGroup!.id),
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: bills.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BillCard(
                              bill: bills[i],
                              group: _selectedGroup!,
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _selectedGroup != null
          ? FloatingActionButton.extended(
              onPressed: _showCreateBill,
              backgroundColor: const Color(0xFF4F46E5),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Bill',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

// ── Bill summary card ──────────────────────────────────────────
class _BillCard extends StatefulWidget {
  final Map<String, dynamic> bill;
  final Group group;

  const _BillCard({required this.bill, required this.group});

  @override
  State<_BillCard> createState() => _BillCardState();
}

class _BillCardState extends State<_BillCard> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Bill',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Delete "${widget.bill['title'] ?? 'this bill'}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ApiService.instance.deleteBill(widget.bill['id'] as String);
      if (mounted) {
        context.read<BillProvider>().removeBill(
            widget.group.id, widget.bill['id'] as String);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final grandTotal = (bill['grand_total'] as num?)?.toDouble();
    final myShare = (bill['my_share'] as num?)?.toDouble();
    final isSettled = bill['settled'] == true;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BillDetailScreen(billId: bill['id'] as String),
        ),
      ),
      child: Container(
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF0D9488), size: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill['title'] ?? 'Bill',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSettled
                              ? AppTheme.green.withOpacity(0.1)
                              : const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSettled ? 'Settled' : 'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSettled
                                ? AppTheme.green
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      if (myShare != null && myShare > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'You: \$${myShare.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (grandTotal != null)
                  Text(
                    '\$${grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                const SizedBox(height: 6),
                _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : GestureDetector(
                        onTap: _confirmDelete,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFEF4444), size: 16),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create bill screen ─────────────────────────────────────────
class _CreateBillScreen extends StatefulWidget {
  final Group group;
  const _CreateBillScreen({required this.group});

  @override
  State<_CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<_CreateBillScreen> {
  final _titleController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();
  int _tipPercent = 18;
  bool _saving = false;
  bool _scanning = false;
  bool _loadingMembers = true;
  String? _error;
  List<GroupMember> _members = [];

  // Local items: { name, price, assigned_to: Set<userId> }
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final data = await ApiService.instance.getGroup(widget.group.id);
      final rawMembers = data['members'] as List? ?? [];
      setState(() {
        _members = rawMembers
            .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      setState(() => _members = widget.group.members);
    } finally {
      setState(() => _loadingMembers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _itemNameController.dispose();
    _itemPriceController.dispose();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() { _scanning = true; _error = null; });
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final items = await ApiService.instance.scanBill(base64Image);
      setState(() {
        for (final item in items) {
          _items.add({
            'name': item['name'] as String,
            'price': (item['price'] as num).toDouble(),
            'assigned_to': <String>{},
          });
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _scanning = false);
    }
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final price = double.tryParse(_itemPriceController.text.trim());
    if (name.isEmpty || price == null || price <= 0) return;
    setState(() {
      _items.add({'name': name, 'price': price, 'assigned_to': <String>{}});
      _itemNameController.clear();
      _itemPriceController.clear();
    });
  }

  void _toggleAssignment(int itemIndex, String userId) {
    setState(() {
      final assigned = _items[itemIndex]['assigned_to'] as Set<String>;
      if (assigned.contains(userId)) {
        assigned.remove(userId);
      } else {
        assigned.add(userId);
      }
    });
  }

  double get _subtotal =>
      _items.fold(0, (sum, i) => sum + (i['price'] as double));
  double get _tipAmount => _subtotal * _tipPercent / 100;
  double get _grandTotal => _subtotal + _tipAmount;

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this bill a title');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      final members = _members;
      await context.read<BillProvider>().createBill({
        'group_id': widget.group.id,
        'title': title,
        'tip_percent': _tipPercent,
        'items': _items.map((item) {
          final assigned = item['assigned_to'] as Set<String>;
          // If nobody assigned, default to all members
          final assignedList = assigned.isEmpty
              ? members.map((m) => m.userId).toList()
              : assigned.toList();
          return {
            'name': item['name'],
            'price': item['price'],
            'assigned_to': assignedList,
          };
        }).toList(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.group.emoji),
          const SizedBox(width: 8),
          const Text('New Bill'),
        ]),
        actions: [
          TextButton(
            onPressed: (_saving || _loadingMembers) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scan receipt banner
          GestureDetector(
            onTap: _scanning ? null : _scanReceipt,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.document_scanner_outlined,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Scan Receipt',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        Text(
                          _scanning
                              ? 'Reading receipt...'
                              : 'Take a photo to auto-fill items',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_scanning)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.arrow_forward,
                        color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Bill title',
              hintText: 'e.g., Dinner at Tony\'s',
            ),
          ),
          const SizedBox(height: 20),

          // Tip selector
          const Text('Tip', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [15, 18, 20, 25].map((pct) {
              final sel = _tipPercent == pct;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _tipPercent = pct),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primary : AppTheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$pct%',
                        style: TextStyle(
                          color: sel ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Add item row
          const Text('Items', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _itemNameController,
                  decoration: const InputDecoration(hintText: 'Item name'),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _itemPriceController,
                  decoration: const InputDecoration(
                      hintText: '0.00', prefixText: '\$ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addItem,
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14)),
                child: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items list
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No items yet — add one above.',
                  style: TextStyle(color: AppTheme.mutedForeground)),
            )
          else
            ..._items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final assigned = item['assigned_to'] as Set<String>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          '\$${(item['price'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.green),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _items.removeAt(i)),
                          child: const Icon(Icons.close,
                              size: 16, color: AppTheme.mutedForeground),
                        ),
                      ],
                    ),
                    if (_members.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Split with:',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.mutedForeground)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: _members.asMap().entries.map((e) {
                          final mi = e.key;
                          final m = e.value;
                          final sel = assigned.contains(m.userId);
                          final color = AppTheme
                              .memberColors[mi % AppTheme.memberColors.length];
                          return GestureDetector(
                            onTap: () => _toggleAssignment(i, m.userId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: sel
                                    ? color.withOpacity(0.15)
                                    : AppTheme.secondary,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: sel ? color : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                m.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: sel ? color : AppTheme.mutedForeground,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),

          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _TotalRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 4),
                  _TotalRow('Tip ($_tipPercent%)',
                      '\$${_tipAmount.toStringAsFixed(2)}'),
                  const Divider(height: 14),
                  _TotalRow('Total', '\$${_grandTotal.toStringAsFixed(2)}',
                      bold: true),
                ],
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Bill detail screen ─────────────────────────────────────────
class BillDetailScreen extends StatefulWidget {
  final String billId;
  const BillDetailScreen({super.key, required this.billId});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  Map<String, dynamic>? _bill;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bill = await context.read<BillProvider>().getBillDetail(widget.billId);
      setState(() { _bill = bill; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_bill == null) {
      return const Scaffold(body: Center(child: Text('Could not load bill.')));
    }

    final bill = _bill!;
    final items = bill['items'] as List? ?? [];
    final perPerson = bill['per_person'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(bill['title'] ?? 'Bill')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Items
          const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          ...items.map((item) {
            final assigned = (item['assigned_to'] as List? ?? []);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        if (assigned.isNotEmpty)
                          Text(
                            assigned.map((a) => a['display_name']).join(', '),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.mutedForeground),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${(item['price'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Totals
          _TotalRow('Subtotal',
              '\$${(bill['subtotal'] as num).toStringAsFixed(2)}'),
          const SizedBox(height: 4),
          _TotalRow('Tip (${bill['tip_percent']}%)',
              '\$${(bill['tip_amount'] as num).toStringAsFixed(2)}'),
          const SizedBox(height: 4),
          _TotalRow('Total',
              '\$${(bill['grand_total'] as num).toStringAsFixed(2)}',
              bold: true),

          const SizedBox(height: 24),

          // Per person
          const Text('Per Person',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          ...perPerson.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value as Map<String, dynamic>;
            final color =
                AppTheme.memberColors[i % AppTheme.memberColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color,
                    child: Text(
                      (p['display_name'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p['display_name'] as String? ?? 'Member',
                        style:
                            const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    '\$${(p['owes'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────
class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _TotalRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
        ],
      );
}

class _EmptyBillsState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyBillsState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🧾', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('No bills yet',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Create a bill after a hangout and split it with your group.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.mutedForeground),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add),
                label: const Text('Create a Bill'),
                style:
                    FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ],
          ),
        ),
      );
}
