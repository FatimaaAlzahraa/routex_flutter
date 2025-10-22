import 'package:flutter/material.dart';
import '../../core/api_client.dart';

// Helpers
int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
String _str(dynamic v, [String fallback = '']) {
  final s = (v ?? '').toString();
  return s.isEmpty ? fallback : s;
}

class ShipmentDetailsPage extends StatefulWidget {
  final int shipmentId;
  const ShipmentDetailsPage({super.key, required this.shipmentId});

  @override
  State<ShipmentDetailsPage> createState() => _ShipmentDetailsPageState();
}

class _ShipmentDetailsPageState extends State<ShipmentDetailsPage> {
  final api = ApiClient();
  final _form = GlobalKey<FormState>();

  Map<String, dynamic>? _details;

  // selections
  int? _productId;
  int? _warehouseId;
  int? _driverId;
  int? _customerId;
  String? _customerAddress;
  String? _notes;

  // lists
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _customers = [];
  List<String> _addresses = [];

  bool _loading = true;
  bool _loadingAddresses = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  List<Map<String, dynamic>> _normalizeList(dynamic d) {
    if (d is List) return d.cast<Map<String, dynamic>>();
    if (d is Map) {
      final r = (d['results'] as List?) ?? (d['data'] as List?) ?? const [];
      return r.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        api.getJson('api/shipments/${widget.shipmentId}', auth: true), // details
        api.getJson('api/products',   auth: true),
        api.getJson('api/warehouses', auth: true),
        api.getJson('api/drivers',    auth: true),
        api.getJson('api/customers',  auth: true),
      ]);

      final details = res[0] as Map<String, dynamic>;
      _details = details;

      setState(() {
        _products   = _normalizeList(res[1]);
        _warehouses = _normalizeList(res[2]);
        _drivers    = _normalizeList(res[3]);
        _customers  = _normalizeList(res[4]);

        // initial selections
        _productId  = _int(details['product']);
        _warehouseId= _int(details['warehouse']);
        _driverId   = details['driver'] == null ? null : _int(details['driver']);
        _customerId = details['customer'] == null ? null : _int(details['customer']);
        _customerAddress = _str(details['customer_address']);
        _notes = _str(details['notes']);
      });

      if (_customerId != null) {
        await _loadAddressesFor(_customerId!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحميل التفاصيل: $e')));
      Navigator.pop(context, false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAddressesFor(int customerId) async {
    setState(() {
      _loadingAddresses = true;
      _addresses = [];
      _customerAddress = null;
    });
    try {
      final data = await api.getJson('customers/$customerId/addresses', auth: true);

      List<String> addrs = [];
      if (data is Map && data['addresses'] is List) {
        addrs = (data['addresses'] as List).map((e) => e.toString()).toList();
      } else if (data is List) {
        for (final e in data) {
          if (e is String) addrs.add(e);
          else if (e is Map) {
            final v = (e['address'] ?? e['addr'] ?? '').toString();
            if (v.isNotEmpty) addrs.add(v);
          }
        }
      } else if (data is Map && data['results'] is List) {
        for (final e in (data['results'] as List)) {
          if (e is String) addrs.add(e);
          else if (e is Map) {
            final v = (e['address'] ?? e['addr'] ?? '').toString();
            if (v.isNotEmpty) addrs.add(v);
          }
        }
      }
      addrs = addrs.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();

      setState(() {
        _addresses = addrs;
        // لو عندنا قيمة سابقة من التفاصيل، رجّعها لو موجودة في اللستة
        final prev = _str(_details?['customer_address']);
        if (prev.isNotEmpty && _addresses.contains(prev)) {
          _customerAddress = prev;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل جلب عناوين العميل: $e')));
    } finally {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_customerId != null && (_customerAddress == null || _customerAddress!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر عنوان العميل')));
      return;
    }
    _form.currentState!.save();

    final payload = <String, dynamic>{
      'warehouse': _warehouseId,
      'product'  : _productId,
      'driver'   : _driverId,                       // null allowed
      'customer' : _customerId,                     // null allowed
      'customer_address': _customerId == null ? null : _customerAddress,
      'notes'    : (_notes ?? '').trim(),           // string always
    };

    setState(() => _saving = true);
    try {
      await api.patchJson('api/shipments/${widget.shipmentId}', payload, auth: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
      Navigator.pop(context, true); // refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الشحنة'),
        content: const Text('هل تريد حذف هذه الشحنة؟ هذا الإجراء لا يمكن التراجع عنه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await api.delete('api/shipments/${widget.shipmentId}', auth: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الشحنة')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل وتعديل الشحنة #${widget.shipmentId}'),
          actions: [
            IconButton(onPressed: _delete, icon: const Icon(Icons.delete_forever), color: Colors.red),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // المنتج
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'المنتج'),
                    items: _products
                        .map((p) => DropdownMenuItem(
                      value: _int(p['id']),
                      child: Text(_str(p['name'], 'بدون اسم')),
                    ))
                        .toList(),
                    value: _productId,
                    onChanged: (v) => setState(() => _productId = v),
                    validator: (v) => v == null ? 'اختر المنتج' : null,
                  ),
                  const SizedBox(height: 12),

                  // المستودع
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'المستودع'),
                    items: _warehouses
                        .map((w) => DropdownMenuItem(
                      value: _int(w['id']),
                      child: Text(_str(w['name'] ?? w['code'], 'مستودع')),
                    ))
                        .toList(),
                    value: _warehouseId,
                    onChanged: (v) => setState(() => _warehouseId = v),
                    validator: (v) => v == null ? 'اختر المستودع' : null,
                  ),
                  const SizedBox(height: 12),

                  // السائق (اختياري)
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'السائق (اختياري)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('بدون سائق')),
                      ..._drivers.map((d) => DropdownMenuItem(
                        value: _int(d['id']),
                        child: Text(_str(d['name'], 'سائق')),
                      )),
                    ],
                    value: _driverId,
                    onChanged: (v) => setState(() => _driverId = v),
                  ),
                  const SizedBox(height: 12),

                  // العميل (اختياري)
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'العميل (اختياري)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('بدون عميل')),
                      ..._customers.map((c) => DropdownMenuItem(
                        value: _int(c['id']),
                        child: Text(_str(c['name'], 'عميل')),
                      )),
                    ],
                    value: _customerId,
                    onChanged: (v) async {
                      setState(() {
                        _customerId = v;
                        _customerAddress = null;
                        _addresses = [];
                      });
                      if (v != null) await _loadAddressesFor(v);
                    },
                  ),

                  if (_customerId != null) ...[
                    const SizedBox(height: 12),
                    _loadingAddresses
                        ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                        : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'عنوان العميل'),
                      items: _addresses.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                      value: _customerAddress,
                      onChanged: (v) => setState(() => _customerAddress = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'اختر عنوان العميل' : null,
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _notes ?? '',
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 3,
                    onSaved: (v) => _notes = (v ?? '').trim(),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('حفظ التعديلات'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
