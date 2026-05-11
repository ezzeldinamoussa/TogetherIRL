import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../config/env.dart';
import '../config/supabase_client.dart';
import '../middleware/auth_middleware.dart';

class BillsController {
  final _db = SupabaseClient.admin;
  final _uuid = const Uuid();

  Router get router {
    final router = Router();
    final auth = requireAuth();

    // POST   /api/bills                    create a bill with items
    // GET    /api/bills/group/<groupId>    list bills for a group
    // GET    /api/bills/<billId>           get one bill with totals
    // PUT    /api/bills/<billId>           update bill (items + assignments)
    // DELETE /api/bills/<billId>           delete a bill

    router.post('/scan', Pipeline().addMiddleware(auth).addHandler(_scanBill));
    router.post('/', Pipeline().addMiddleware(auth).addHandler(_createBill));
    router.get('/group/<groupId>', Pipeline().addMiddleware(auth).addHandler(_getGroupBills));
    router.get('/<billId>', Pipeline().addMiddleware(auth).addHandler(_getBill));
    router.put('/<billId>', Pipeline().addMiddleware(auth).addHandler(_updateBill));
    router.delete('/<billId>', Pipeline().addMiddleware(auth).addHandler(_deleteBill));

    return router;
  }

  // ─────────────────────────────────────────
  // POST /scan
  // Body: { "image": "<base64 jpeg>" }
  // Returns: { "items": [{ "name": "...", "price": 0.00 }] }
  // ─────────────────────────────────────────
  Future<Response> _scanBill(Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final base64Image = body['image'] as String?;
    if (base64Image == null || base64Image.isEmpty) {
      return _badRequest('image is required');
    }

    try {
      final ocrRes = await http.post(
        Uri.parse('https://api.ocr.space/parse/image'),
        headers: {'apikey': Env.ocrSpaceApiKey},
        body: {
          'base64Image': 'data:image/jpeg;base64,$base64Image',
          'language': 'eng',
          'isOverlayRequired': 'false',
          'detectOrientation': 'true',
          'isTable': 'true',
          'filetype': 'JPG',
        },
      );

      final ocrBody = jsonDecode(ocrRes.body) as Map<String, dynamic>;
      final results = ocrBody['ParsedResults'] as List?;
      if (results == null || results.isEmpty) {
        return _badRequest('Could not read the receipt. Try a clearer photo.');
      }

      final rawText = (results.first as Map)['ParsedText'] as String? ?? '';
      final items = _parseReceiptText(rawText);

      if (items.isEmpty) {
        return _badRequest('No items found. Try a clearer photo or enter manually.');
      }

      return _ok({'items': items, 'raw_text': rawText});
    } catch (e) {
      return _serverError('OCR failed: $e');
    }
  }

  List<Map<String, dynamic>> _parseReceiptText(String text) {
    final items = <Map<String, dynamic>>[];
    final lines = text.split('\n');

    // Matches: "Item Name   12.50" or "Item Name $12.50"
    final pricePattern = RegExp(r'^(.+?)\s+\$?(\d+\.\d{2})\s*$');
    final skipKeywords = [
      'total', 'subtotal', 'tax', 'tip', 'gratuity', 'service',
      'discount', 'change', 'cash', 'card', 'amount due', 'balance',
      'visa', 'mastercard', 'amex', 'credit', 'debit', 'thank',
      'receipt', 'order', 'table', 'server', 'guest', 'check',
    ];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final lower = trimmed.toLowerCase();
      if (skipKeywords.any((k) => lower.contains(k))) continue;

      final match = pricePattern.firstMatch(trimmed);
      if (match == null) continue;

      final name = match.group(1)!.trim();
      final price = double.tryParse(match.group(2)!);
      if (price == null || price <= 0 || price > 500) continue;
      if (name.length < 2) continue;

      items.add({'name': _cleanItemName(name), 'price': price});
    }

    return items;
  }

  String _cleanItemName(String name) {
    // Remove leading numbers like "1 " or "2x "
    return name.replaceFirst(RegExp(r'^\d+[x\s]+', caseSensitive: false), '').trim();
  }

  // ─────────────────────────────────────────
  // POST /
  // Body: {
  //   "group_id": "uuid",
  //   "title": "Dinner at Tony's",
  //   "tip_percent": 18,
  //   "items": [
  //     { "name": "Pizza", "price": 18.00, "assigned_to": ["userId1", "userId2"] }
  //   ]
  // }
  // ─────────────────────────────────────────
  Future<Response> _createBill(Request req) async {
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final groupId = body['group_id'] as String?;

    if (groupId == null) return _badRequest('group_id is required');

    final membership = await _getMembership(groupId, userId);
    if (membership == null) return _forbidden('Not a group member');

    try {
      final bill = await _db.insert('hangout_bills', {
        'id': _uuid.v4(),
        'group_id': groupId,
        'created_by': userId,
        'title': body['title'] ?? 'Bill',
        'tip_percent': body['tip_percent'] ?? 18,
      });

      final billId = bill['id'] as String;
      final items = body['items'] as List? ?? [];
      await _insertItems(billId, items);

      return Response(201, body: jsonEncode(bill), headers: _jsonHeader);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /group/<groupId>
  // ─────────────────────────────────────────
  Future<Response> _getGroupBills(Request req) async {
    final groupId = req.params['groupId']!;
    final userId = req.userId;

    final membership = await _getMembership(groupId, userId);
    if (membership == null) return _forbidden('Not a group member');

    try {
      final bills = await _db.select(
        'hangout_bills',
        filters: {'group_id': 'eq.$groupId', 'order': 'created_at.desc'},
        columns: 'id,title,tip_percent,created_at,created_by',
      );
      return _ok(bills);
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // GET /<billId>
  // Returns bill + items + assignments + per-person totals
  // ─────────────────────────────────────────
  Future<Response> _getBill(Request req) async {
    final billId = req.params['billId']!;
    final userId = req.userId;

    try {
      final bills = await _db.select(
        'hangout_bills',
        filters: {'id': 'eq.$billId'},
        single: true,
      );
      if (bills.isEmpty) return _notFound('Bill not found');
      final bill = bills.first;

      final membership = await _getMembership(bill['group_id'] as String, userId);
      if (membership == null) return _forbidden('Not a group member');

      // Get items
      final items = await _db.select(
        'bill_items',
        filters: {'bill_id': 'eq.$billId'},
      );

      // Get assignments for all items (no profile join — auth.users != public.profiles)
      final itemIds = items.map((i) => i['id'] as String).toList();
      List<Map<String, dynamic>> assignments = [];
      if (itemIds.isNotEmpty) {
        assignments = await _db.select(
          'bill_assignments',
          filters: {'bill_item_id': 'in.(${itemIds.join(',')})'},
          columns: 'bill_item_id,user_id',
        );
      }

      // Look up display names from profiles separately
      final assignedUserIds = assignments.map((a) => a['user_id'] as String).toSet().toList();
      final Map<String, String> displayNames = {};
      if (assignedUserIds.isNotEmpty) {
        final profiles = await _db.select(
          'profiles',
          filters: {'id': 'in.(${assignedUserIds.join(',')})'},
          columns: 'id,display_name',
        );
        for (final p in profiles) {
          displayNames[p['id'] as String] = p['display_name'] as String? ?? 'Member';
        }
      }

      // Attach assignments to each item
      final enrichedItems = items.map((item) {
        final itemAssignments = assignments
            .where((a) => a['bill_item_id'] == item['id'])
            .map((a) => {
                  'user_id': a['user_id'],
                  'display_name': displayNames[a['user_id']] ?? 'Member',
                })
            .toList();
        return {...item, 'assigned_to': itemAssignments};
      }).toList();

      // Calculate per-person totals
      final tipPercent = (bill['tip_percent'] as num).toDouble();
      final subtotal = enrichedItems.fold<double>(
        0,
        (sum, item) => sum + (item['price'] as num).toDouble(),
      );
      final tipAmount = subtotal * tipPercent / 100;
      final grandTotal = subtotal + tipAmount;

      final Map<String, double> personTotals = {};
      for (final item in enrichedItems) {
        final assigned = item['assigned_to'] as List;
        if (assigned.isEmpty) continue;
        final share = (item['price'] as num).toDouble() / assigned.length;
        for (final a in assigned) {
          final uid = a['user_id'] as String;
          personTotals[uid] = (personTotals[uid] ?? 0) + share;
        }
      }

      // Add proportional tip to each person's total
      final perPerson = personTotals.entries.map((e) {
        final foodShare = subtotal > 0 ? e.value / subtotal : 0;
        final withTip = e.value + tipAmount * foodShare;
        return {
          'user_id': e.key,
          'display_name': displayNames[e.key] ?? 'Member',
          'owes': double.parse(withTip.toStringAsFixed(2)),
        };
      }).toList();

      return _ok({
        ...bill,
        'items': enrichedItems,
        'subtotal': subtotal,
        'tip_amount': double.parse(tipAmount.toStringAsFixed(2)),
        'grand_total': double.parse(grandTotal.toStringAsFixed(2)),
        'per_person': perPerson,
      });
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // PUT /<billId>
  // Full replace of title, tip, items, and assignments.
  // ─────────────────────────────────────────
  Future<Response> _updateBill(Request req) async {
    final billId = req.params['billId']!;
    final userId = req.userId;
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

    try {
      final bills = await _db.select(
        'hangout_bills',
        filters: {'id': 'eq.$billId'},
        single: true,
      );
      if (bills.isEmpty) return _notFound('Bill not found');

      if (bills.first['created_by'] != userId) {
        return _forbidden('Only the bill creator can edit it');
      }

      // Update top-level bill fields
      await _db.update(
        'hangout_bills',
        {
          if (body.containsKey('title')) 'title': body['title'],
          if (body.containsKey('tip_percent')) 'tip_percent': body['tip_percent'],
        },
        filters: {'id': 'eq.$billId'},
      );

      // Replace items if provided
      if (body.containsKey('items')) {
        // Delete old items (cascade deletes assignments too)
        await _db.update(
          'bill_items',
          {'bill_id': billId},
          filters: {'bill_id': 'eq.$billId'},
        );
        // Re-insert — simpler than diffing
        final items = body['items'] as List? ?? [];
        await _insertItems(billId, items);
      }

      return _ok({'message': 'Bill updated'});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─────────────────────────────────────────
  // DELETE /<billId>
  // ─────────────────────────────────────────
  Future<Response> _deleteBill(Request req) async {
    final billId = req.params['billId']!;
    final userId = req.userId;

    try {
      final bills = await _db.select(
        'hangout_bills',
        filters: {'id': 'eq.$billId'},
        single: true,
      );
      if (bills.isEmpty) return _notFound('Bill not found');
      if (bills.first['created_by'] != userId) {
        return _forbidden('Only the bill creator can delete it');
      }

      await _db.update(
        'hangout_bills',
        {'id': billId},
        filters: {'id': 'eq.$billId'},
      );

      return _ok({'message': 'Bill deleted'});
    } on SupabaseException catch (e) {
      return _serverError(e.body);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────

  Future<void> _insertItems(String billId, List items) async {
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      final itemId = _uuid.v4();
      await _db.insert('bill_items', {
        'id': itemId,
        'bill_id': billId,
        'name': itemMap['name'],
        'price': itemMap['price'],
      });
      final assignedTo = itemMap['assigned_to'] as List? ?? [];
      for (final uid in assignedTo) {
        await _db.insert('bill_assignments', {
          'bill_item_id': itemId,
          'user_id': uid,
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _getMembership(String groupId, String userId) async {
    try {
      final rows = await _db.select(
        'group_members',
        filters: {'group_id': 'eq.$groupId', 'user_id': 'eq.$userId', 'status': 'eq.active'},
        single: true,
      );
      return rows.firstOrNull;
    } on SupabaseException {
      return null;
    }
  }
}

const _jsonHeader = {'Content-Type': 'application/json'};
Response _ok(dynamic data) => Response.ok(jsonEncode(data), headers: _jsonHeader);
Response _badRequest(String msg) => Response(400, body: jsonEncode({'error': msg}), headers: _jsonHeader);
Response _forbidden(String msg) => Response.forbidden(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _notFound(String msg) => Response.notFound(jsonEncode({'error': msg}), headers: _jsonHeader);
Response _serverError(String msg) => Response.internalServerError(body: jsonEncode({'error': msg}), headers: _jsonHeader);
