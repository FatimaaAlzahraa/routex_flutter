// lib/features/manager/widgets/customer_picker_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api_client.dart';


class CustomerPickResult {
  final int customerId;
  final String customerName;
  final List<String> addresses; // العناوين الموجودة بعد أي إضافة
  final String? selectedAddress; // العنوان المختار (إن اختاره المستخدم الآن)

  CustomerPickResult({
    required this.customerId,
    required this.customerName,
    required this.addresses,
    this.selectedAddress,
  });
}

/// دايالوج: بحث عن عميل + إنشاء عميل جديد + إضافة عنوان للعميل
class CustomerPickerDialog extends StatefulWidget {
  const CustomerPickerDialog({super.key});

  @override
  State<CustomerPickerDialog> createState() => _CustomerPickerDialogState();

  /// استدعاء مختصر لفتح الدايالوج
  static Future<CustomerPickResult?> pick(BuildContext context) {
    return showDialog<CustomerPickResult>(
      context: context,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(width: 520, child: CustomerPickerDialog()),
      ),
    );
  }
}

class _CustomerPickerDialogState extends State<CustomerPickerDialog> {
  final _api = ApiClient();

  // بحث
  final _q = TextEditingController();
  Timer? _debounce; // ← للـ auto-search
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  // العميل المحدد حالياً
  Map<String, dynamic>? _selected;
  String? _addressToReturn;

  // إدخال عميل جديد
  final _newName = TextEditingController();
  final _newPhone = TextEditingController();
  final _newAddress = TextEditingController();
  bool _creating = false;

  // إضافة عنوان لعميل موجود
  final _extraAddress = TextEditingController();
  bool _addingAddress = false;

  @override
  void initState() {
    super.initState();
    // أي تغيير في مربع البحث → ابحث تلقائياً بعد 350ms
    _q.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.removeListener(_onQueryChanged);
    _q.dispose();
    _newName.dispose();
    _newPhone.dispose();
    _newAddress.dispose();
    _extraAddress.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final text = _q.text.trim();
      if (text.isEmpty) {
        setState(() {
          _results = [];
          _selected = null;
          _addressToReturn = null;
        });
        return;
      }
      await _search();
    });
  }

  /// ---- دالة البحث (محدّثة) ----
  Future<void> _search() async {
    setState(() {
      _loading = true;
      _results = [];
      _selected = null;
      _addressToReturn = null;
    });

    List<Map<String, dynamic>> _parseResults(dynamic data) {
      // نقبل List مباشرة أو {"results":[...]} أو {"data":[...]}
      final List raw = data is List
          ? data
          : (data is Map && data['results'] is List)
          ? data['results'] as List
          : (data is Map && data['data'] is List)
          ? data['data'] as List
          : const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    try {
      final q = Uri.encodeComponent(_q.text.trim());

      // 1) المسار الرسمي لديك
      List<Map<String, dynamic>> items =
      _parseResults(await _api.getJson('api/autocomplete/customers?q=$q', auth: true));

      // 2) لو فاضي، جرّب المسار البديل الشائع
      if (items.isEmpty) {
        try {
          items = _parseResults(
              await _api.getJson('api/customers/autocomplete?q=$q', auth: true));
        } catch (_) {}
      }

      // 3) كحل أخير: هات كل العملاء وفلتر محلي
      if (items.isEmpty) {
        try {
          final all = await _api.getJson('api/customers', auth: true);
          final List list = all is List
              ? all
              : (all is Map && all['results'] is List)
              ? all['results'] as List
              : const [];
          final needle = _q.text.trim().toLowerCase();
          items = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((m) {
            final name = (m['name'] ?? '').toString().toLowerCase();
            final phone = (m['phone'] ?? '').toString().toLowerCase();
            return name.contains(needle) || phone.contains(needle);
          })
              .toList();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() => _results = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل البحث: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _addressesFrom(Map<String, dynamic> c) {
    final a1 = (c['address'] ?? '').toString();
    final a2 = (c['address2'] ?? '').toString();
    final a3 = (c['address3'] ?? '').toString();
    return [a1, a2, a3].where((s) => s.trim().isNotEmpty).toList();
  }

  Future<void> _createCustomer() async {
    final name = _newName.text.trim();
    final phone = _newPhone.text.trim();
    final addr = _newAddress.text.trim();
    if (name.isEmpty || phone.isEmpty || addr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ادخل الاسم، الهاتف، وعنوان واحد على الأقل')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      // POST api/customers
      final body = {"name": name, "phone": phone, "address": addr};
      final res = await _api.postJson('api/customers', body, auth: true);

      final addrs = _addressesFrom(Map<String, dynamic>.from(res as Map));
      if (!mounted) return;
      Navigator.pop(
        context,
        CustomerPickResult(
          customerId: res['id'] as int,
          customerName: res['name']?.toString() ?? name,
          addresses: addrs,
          selectedAddress: addrs.isNotEmpty ? addrs.first : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل إنشاء العميل: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _addAddressToSelected() async {
    final c = _selected;
    if (c == null) return;
    final addr = _extraAddress.text.trim();
    if (addr.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اكتب العنوان الجديد')));
      return;
    }
    setState(() => _addingAddress = true);
    try {
      final cid = c['id'];

      // GET api/customers/<id>
      final detail = await _api.getJson('api/customers/$cid', auth: true) as Map;

      // أول خانة عنوان فاضية
      final Map<String, dynamic> patch = {};
      if ((detail['address'] ?? '').toString().trim().isEmpty) {
        patch['address'] = addr;
      } else if ((detail['address2'] ?? '').toString().trim().isEmpty) {
        patch['address2'] = addr;
      } else if ((detail['address3'] ?? '').toString().trim().isEmpty) {
        patch['address3'] = addr;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد خانات عناوين فارغة لهذا العميل')),
        );
        setState(() => _addingAddress = false);
        return;
      }

      // PATCH api/customers/<id>
      final updated =
      await _api.patchJson('api/customers/$cid', patch, auth: true);
      _selected = Map<String, dynamic>.from(updated as Map);
      _extraAddress.clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل إضافة العنوان: $e')));
    } finally {
      if (mounted) setState(() => _addingAddress = false);
    }
  }

  void _confirmPick() {
    final c = _selected;
    if (c == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اختاري عميل أولاً')));
      return;
    }
    final addrs = _addressesFrom(c);
    Navigator.pop(
      context,
      CustomerPickResult(
        customerId: c['id'] as int,
        customerName: c['name']?.toString() ?? '',
        addresses: addrs,
        selectedAddress: _addressToReturn?.trim().isNotEmpty == true
            ? _addressToReturn
            : (addrs.isNotEmpty ? addrs.first : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAddresses = _addressesFrom(_selected ?? {});
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختيار عميل / إضافة عميل',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),

            // شريط بحث (auto-search)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    decoration: InputDecoration(
                      labelText: 'بحث بالاسم أو الهاتف',
                      prefixIcon: _loading
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child:
                            CircularProgressIndicator(strokeWidth: 2)),
                      )
                          : const Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(), // للي يحب يدوس Enter
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.manage_search),
                  label: const Text('بحث'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // النتائج
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280),
                child: _results.isEmpty
                    ? const Center(
                  child:
                  Text('لا نتائج بعد. اكتب للبحث أو أضف عميل جديد.'),
                )
                    : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = _results[i];
                    final addrs = _addressesFrom(c);
                    final selected =
                        _selected != null && _selected!['id'] == c['id'];
                    return ListTile(
                      selected: selected,
                      title: Text('${c['name'] ?? ''}'),
                      subtitle: Text(
                        (c['phone'] ?? '').toString(),
                        textDirection: TextDirection.ltr,
                      ),
                      trailing: addrs.isEmpty
                          ? const Text('لا عناوين')
                          : Text(addrs.join(' • ')),
                      onTap: () {
                        setState(() {
                          _selected = c;
                          _addressToReturn =
                          addrs.isNotEmpty ? addrs.first : null;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // اختيار عنوان + إضافة عنوان
            if (_selected != null) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text('عناوين العميل المختار:',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedAddresses.contains(_addressToReturn)
                          ? _addressToReturn
                          : (selectedAddresses.isNotEmpty
                          ? selectedAddresses.first
                          : null),
                      items: selectedAddresses
                          .map((a) =>
                          DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (v) => setState(() => _addressToReturn = v),
                      decoration:
                      const InputDecoration(labelText: 'اختر عنوان التوصيل'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _extraAddress,
                      decoration: const InputDecoration(
                          labelText: 'إضافة عنوان جديد لهذا العميل'),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addingAddress ? null : _addAddressToSelected,
                    icon: _addingAddress
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.add),
                    label: const Text('أضف العنوان'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // إنشاء عميل جديد
            ExpansionTile(
              title: const Text('إنشاء عميل جديد'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                TextField(
                  controller: _newName,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r"[0-9A-Za-z\u0600-\u06FF\s._\-']"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _newPhone,
                  decoration: const InputDecoration(labelText: 'الهاتف'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _newAddress,
                  decoration: const InputDecoration(
                      labelText: 'العنوان (إلزامي كأول عنوان)'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _creating ? null : _createCustomer,
                    icon: _creating
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.person_add_alt_1),
                    label: const Text('إنشاء وحفظ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // أزرار تأكيد/إلغاء
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: _confirmPick,
                  icon: const Icon(Icons.check),
                  label: const Text('اختيار'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
