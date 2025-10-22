// lib/features/manager/add_shipment_page.dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'widgets/customer_picker_dialog.dart'; // نافذة اختيار/إنشاء عميل
import 'shipment_details_page.dart';          // لفتح تفاصيل شحنة من البحث
import 'widgets/shipment_search_dialog.dart'; // نافذة بحث الشحنات (ac-shipments)

// ===== Helpers =====
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

class AddShipmentPage extends StatefulWidget {
  const AddShipmentPage({super.key});

  @override
  State<AddShipmentPage> createState() => _AddShipmentPageState();
}

class _AddShipmentPageState extends State<AddShipmentPage> {
  final api = ApiClient();
  final _form = GlobalKey<FormState>();

  // selections
  int? _productId;           // required
  int? _warehouseId;         // required
  int? _driverId;            // optional
  int? _customerId;          // optional
  String? _customerAddress;  // required if customer selected
  String? _notes;

  // data lists
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _customers = [];
  List<String> _addresses = [];

  bool _loadingAll = true;
  bool _loadingAddresses = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  List<Map<String, dynamic>> _normalizeToMapList(dynamic d) {
    if (d is List) return d.cast<Map<String, dynamic>>();
    if (d is Map) {
      final r = (d['results'] as List?) ?? (d['data'] as List?) ?? const [];
      return r.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> _loadLists() async {
    setState(() => _loadingAll = true);
    try {
      final res = await Future.wait([
        api.getJson('api/products',   auth: true),
        api.getJson('api/warehouses', auth: true),
        api.getJson('api/drivers',    auth: true),
        api.getJson('api/customers',  auth: true),
      ]);

      setState(() {
        _products   = _normalizeToMapList(res[0]);
        _warehouses = _normalizeToMapList(res[1]); // يسمح تكرار الاسم بموقع مختلف
        _drivers    = _normalizeToMapList(res[2]);
        _customers  = _normalizeToMapList(res[3]);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل القوائم: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  Future<void> _onCustomerChanged(int? id) async {
    setState(() {
      _customerId = id;
      _customerAddress = null;
      _addresses = [];
      _loadingAddresses = id != null;
    });
    if (id == null) return;

    try {
      final data = await api.getJson('customers/$id/addresses', auth: true);

      List<String> addrs = [];
      if (data is Map && data['addresses'] is List) {
        addrs = (data['addresses'] as List).map((e) => e.toString()).toList();
      } else if (data is List) {
        for (final e in data) {
          if (e is String) {
            addrs.add(e);
          } else if (e is Map) {
            final v = (e['address'] ?? e['addr'] ?? '').toString();
            if (v.isNotEmpty) addrs.add(v);
          }
        }
      } else if (data is Map && data['results'] is List) {
        for (final e in (data['results'] as List)) {
          if (e is String) {
            addrs.add(e);
          } else if (e is Map) {
            final v = (e['address'] ?? e['addr'] ?? '').toString();
            if (v.isNotEmpty) addrs.add(v);
          }
        }
      }
      addrs = addrs.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();

      setState(() {
        _addresses = addrs;
        if (_addresses.isNotEmpty) _customerAddress = _addresses.first;
      });

      if (_addresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('العميل لا يملك عناوين محفوظة')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل جلب عناوين العميل: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  // ====== نافذة اختيار/إنشاء عميل ======
  Future<void> _openCustomerPicker() async {
    final picked = await CustomerPickerDialog.pick(context);
    if (picked == null) return;

    final idx = _customers.indexWhere((c) => _int(c['id']) == picked.customerId);
    if (idx < 0) {
      _customers.insert(0, {"id": picked.customerId, "name": picked.customerName});
    } else {
      _customers[idx]["name"] = picked.customerName;
    }

    setState(() {
      _customerId = picked.customerId;
      _addresses = picked.addresses;
      _customerAddress =
          picked.selectedAddress ?? (picked.addresses.isNotEmpty ? picked.addresses.first : null);
    });
  }

  // ====== إنشاء مستودع ======
  Future<void> _createWarehouseInline() async {
    final nameCtrl = TextEditingController();
    final locCtrl  = TextEditingController();
    final formKey  = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            title: const Text('إضافة مستودع جديد'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم المستودع'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: locCtrl,
                    decoration: const InputDecoration(labelText: 'الموقع / العنوان'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل الموقع' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                  if (!formKey.currentState!.validate()) return;
                  setD(() => saving = true);
                  try {
                    final res = await api.postJson(
                      'api/warehouses',
                      {
                        "name": nameCtrl.text.trim(),
                        "location": locCtrl.text.trim(),
                      },
                      auth: true,
                    );

                    // لا نضيف عنصر مكرر إذا نفس (الاسم + الموقع) موجودين
                    final nameKey = (res['name'] ?? '').toString().trim().toLowerCase();
                    final locKey  = (res['location'] ?? '').toString().trim().toLowerCase();
                    final exists = _warehouses.any((w) {
                      final wn = (w['name'] ?? '').toString().trim().toLowerCase();
                      final wl = (w['location'] ?? '').toString().trim().toLowerCase();
                      return wn == nameKey && wl == locKey;
                    });
                    if (!exists) {
                      _warehouses.insert(0, {
                        "id": res['id'],
                        "name": res['name'],
                        "location": res['location'],
                      });
                    }
                    _warehouseId = _int(res['id']);
                    setState(() {});

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إنشاء المستودع وإضافته للقائمة')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل إنشاء المستودع: $e')),
                    );
                  } finally {
                    setD(() => saving = false);
                  }
                },
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== تعديل مستودع ======
  Future<void> _editWarehouseInline() async {
    if (_warehouseId == null) return;
    final wh = _warehouses.firstWhere((w) => _int(w['id']) == _warehouseId!, orElse: () => {});
    final nameCtrl = TextEditingController(text: _str(wh['name']));
    final locCtrl  = TextEditingController(text: _str(wh['location']));
    final formKey  = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            title: const Text('تعديل المستودع'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم المستودع'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: locCtrl,
                    decoration: const InputDecoration(labelText: 'الموقع / العنوان'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل الموقع' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                  if (!formKey.currentState!.validate()) return;
                  setD(() => saving = true);
                  try {
                    final res = await api.patchJson(
                      'api/warehouses/${_warehouseId!}',
                      {
                        "name": nameCtrl.text.trim(),
                        "location": locCtrl.text.trim(),
                      },
                      auth: true,
                    );

                    final i = _warehouses.indexWhere((w) => _int(w['id']) == _warehouseId!);
                    if (i >= 0) {
                      _warehouses[i] = {
                        "id": res['id'],
                        "name": res['name'],
                        "location": res['location'],
                      };
                    }
                    setState(() {});

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تعديل بيانات المستودع')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل تعديل المستودع: $e')),
                    );
                  } finally {
                    setD(() => saving = false);
                  }
                },
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== حذف مستودع ======
  Future<void> _deleteWarehouseInline() async {
    if (_warehouseId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المستودع'),
        content: const Text('سيتم حذف المستودع المختار. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await api.delete('api/warehouses/${_warehouseId!}', auth: true);

      _warehouses.removeWhere((w) => _int(w['id']) == _warehouseId!);
      setState(() => _warehouseId = null);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المستودع')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف المستودع: $e')),
      );
    }
  }

  // ====== زر بحث شحنة وفتح التفاصيل ======
  Future<void> _openShipmentSearch() async {
    final pickedId = await ShipmentSearchDialog.open(context);
    if (pickedId != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShipmentDetailsPage(shipmentId: pickedId)),
      );
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_customerId != null && (_customerAddress == null || _customerAddress!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر عنوان العميل')));
      return;
    }
    _form.currentState!.save();

    final payload = <String, dynamic>{
      'warehouse': _warehouseId,
      'product': _productId,
      'driver': _driverId,
      'customer': _customerId,
      'customer_address': _customerAddress,
      'notes': _notes,
    };

    setState(() => _submitting = true);
    try {
      await api.postJson('api/shipments', payload, auth: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الشحنة')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إنشاء الشحنة: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة شحنة')),
        body: _loadingAll
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // === 1) زر بحث الشحنة في أعلى الصفحة ===
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openShipmentSearch,
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('بحث شحنة / فتح التفاصيل'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // المنتج (إلزامي)
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

                  // المستودع (إلزامي)
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
                  // أزرار المستودع: إضافة / تعديل / حذف
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _createWarehouseInline,
                        icon: const Icon(Icons.add_business),
                        label: const Text('إضافة مستودع جديد'),
                      ),
                      const SizedBox(width: 8),
                      if (_warehouseId != null) ...[
                        OutlinedButton.icon(
                          onPressed: _editWarehouseInline,
                          icon: const Icon(Icons.edit),
                          label: const Text('تعديل'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _deleteWarehouseInline,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('حذف'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // السائق (اختياري)
                  DropdownButtonFormField<int?>(
                    decoration: const InputDecoration(labelText: 'السائق (اختياري)'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('بدون سائق الآن')),
                      ..._drivers.map((d) => DropdownMenuItem<int?>(
                        value: _int(d['id']),
                        child: Text(_str(d['name'], 'سائق')),
                      )),
                    ],
                    value: _driverId,
                    onChanged: (v) => setState(() => _driverId = v),
                  ),
                  const SizedBox(height: 12),

                  // العميل (اختياري)
                  DropdownButtonFormField<int?>(
                    key: ValueKey('customer-${_customers.length}-${_customerId ?? 'none'}'),
                    decoration: const InputDecoration(labelText: 'العميل (اختياري)'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('بدون عميل الآن')),
                      ..._customers.map((c) => DropdownMenuItem<int?>(
                        value: _int(c['id']),
                        child: Text(_str(c['name'], 'عميل')),
                      )),
                    ],
                    value: _customerId,
                    onChanged: _onCustomerChanged,
                  ),

                  // === 2) عناوين العميل (فوق زر اختيار/إنشاء عميل) ===
                  if (_customerId != null) ...[
                    const SizedBox(height: 12),
                    _loadingAddresses
                        ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                        : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'عنوان العميل'),
                      items: _addresses
                          .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      value: _customerAddress,
                      onChanged: (v) => setState(() => _customerAddress = v),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? 'اختر عنوان العميل' : null,
                    ),
                  ],

                  // زر اختيار/إنشاء عميل (بالسيرش)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openCustomerPicker,
                      icon: const Icon(Icons.manage_search),
                      label: const Text('اختيار / إنشاء عميل (بحث)'),
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 3,
                    onSaved: (v) {
                      final t = (v ?? '').trim();
                      _notes = t.isEmpty ? null : t;
                    },
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('إنشاء الشحنة'),
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
