import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../manager/shipment_details_page.dart';

class ShipmentSearchDialog extends StatefulWidget {
  const ShipmentSearchDialog({super.key});

  /// افتحيه كدا:
  /// final pickedId = await ShipmentSearchDialog.open(context);
  static Future<int?> open(BuildContext context) {
    return showDialog<int?>(
      context: context,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(width: 520, child: ShipmentSearchDialog()),
      ),
    );
  }

  @override
  State<ShipmentSearchDialog> createState() => _ShipmentSearchDialogState();
}

class _ShipmentSearchDialogState extends State<ShipmentSearchDialog> {
  final _api = ApiClient();

  final _q = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _q.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.removeListener(_onQueryChanged);
    _q.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final t = _q.text.trim();
      if (t.isEmpty) {
        setState(() => _results = []);
        return;
      }
      _search(t);
    });
  }

  Future<void> _search(String text) async {
    setState(() {
      _loading = true;
      _results = [];
    });

    List<Map<String, dynamic>> _parse(dynamic data) {
      final List raw = data is List
          ? data
          : (data is Map && data['results'] is List)
          ? data['results'] as List
          : (data is Map && data['data'] is List)
          ? data['data'] as List
          : const [];
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    try {
      final q = Uri.encodeComponent(text);

      // الـ API الرسمي عندك
      List<Map<String, dynamic>> items =
      _parse(await _api.getJson('api/autocomplete/shipments?q=$q', auth: true));

      // احتياطي لمسارات بديلة لو احتجتي
      if (items.isEmpty) {
        try {
          items = _parse(await _api.getJson('api/shipments/autocomplete?q=$q', auth: true));
        } catch (_) {}
      }

      setState(() => _results = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل البحث: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('بحث عن شحنة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    decoration: InputDecoration(
                      labelText: 'ابحث برقم الشحنة / المنتج / العميل',
                      prefixIcon: _loading
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : const Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (t) {
                      final s = t.trim();
                      if (s.isNotEmpty) _search(s);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : () => _search(_q.text.trim()),
                  icon: const Icon(Icons.manage_search),
                  label: const Text('بحث'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 360),
                child: _results.isEmpty
                    ? const Center(child: Text('لا نتائج بعد. اكتب للبحث.'))
                    : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = _results[i];
                    final id = m['id'];
                    final code = (m['code'] ?? '#$id').toString();
                    final product = (m['product'] ?? '').toString();
                    final customer = (m['customer'] ?? '').toString();
                    final status = (m['status'] ?? m['current_status'] ?? '').toString();

                    return ListTile(
                      leading: CircleAvatar(child: Text('$id')),
                      title: Text(product.isNotEmpty ? product : code),
                      subtitle: Text(
                        [
                          if (customer.isNotEmpty) 'عميل: $customer',
                          if (status.isNotEmpty) 'حالة: $status',
                        ].join(' • '),
                      ),
                      onTap: () => Navigator.pop(context, id as int),
                      trailing: IconButton(
                        tooltip: 'فتح التفاصيل',
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () async {
                          // افتح صفحة التفاصيل من غير ما تقفلي الدايالوج
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ShipmentDetailsPage(shipmentId: id as int),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('إغلاق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
