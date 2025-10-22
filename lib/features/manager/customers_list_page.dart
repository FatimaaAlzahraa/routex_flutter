import 'package:flutter/material.dart';
import '../../core/api_client.dart';

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

class CustomersListPage extends StatefulWidget {
  const CustomersListPage({super.key});

  @override
  State<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends State<CustomersListPage> {
  final api = ApiClient();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _normalize(dynamic d) {
    if (d is List) return d.cast<Map<String, dynamic>>();
    if (d is Map) {
      final r = (d['results'] as List?) ?? (d['data'] as List?) ?? const [];
      return r.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await api.getJson('api/customers', auth: true);
      setState(() => _items = _normalize(data));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل العملاء: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit({Map<String, dynamic>? current}) async {
    final name = TextEditingController(text: _str(current?['name']));
    final phone = TextEditingController(text: _str(current?['phone']));
    final addr1 = TextEditingController(text: _str(current?['address']));
    final addr2 = TextEditingController(text: _str(current?['address2']));
    final addr3 = TextEditingController(text: _str(current?['address3']));
    final form = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            title: Text(current == null ? 'إضافة عميل' : 'تعديل عميل'),
            content: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'الاسم'),
                      validator: (v) =>
                      v == null || v.trim().isEmpty ? 'أدخل الاسم' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'الهاتف'),
                      validator: (v) =>
                      v == null || v.trim().isEmpty ? 'أدخل الهاتف' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: addr1,
                      decoration:
                      const InputDecoration(labelText: 'العنوان 1 (إلزامي عند الإنشاء)'),
                      validator: (v) {
                        if (current == null &&
                            (v == null || v.trim().isEmpty)) {
                          return 'أدخل العنوان 1';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: addr2,
                      decoration: const InputDecoration(labelText: 'العنوان 2 (اختياري)'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: addr3,
                      decoration: const InputDecoration(labelText: 'العنوان 3 (اختياري)'),
                    ),
                  ],
                ),
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
                  if (!form.currentState!.validate()) return;
                  setD(() => saving = true);
                  try {
                    if (current == null) {
                      final body = {
                        "name": name.text.trim(),
                        "phone": phone.text.trim(),
                        "address": addr1.text.trim(),
                        if (addr2.text.trim().isNotEmpty)
                          "address2": addr2.text.trim(),
                        if (addr3.text.trim().isNotEmpty)
                          "address3": addr3.text.trim(),
                      };
                      final res = await api.postJson(
                          'api/customers', body,
                          auth: true);
                      _items.insert(0,
                          Map<String, dynamic>.from(res as Map));
                    } else {
                      final body = {
                        "name": name.text.trim(),
                        "phone": phone.text.trim(),
                        "address": addr1.text.trim(),
                        "address2": addr2.text.trim(),
                        "address3": addr3.text.trim(),
                      };
                      final id = _int(current['id']);
                      final res = await api.patchJson(
                          'api/customers/$id', body,
                          auth: true);
                      final idx =
                      _items.indexWhere((e) => _int(e['id']) == id);
                      if (idx >= 0) {
                        _items[idx] =
                        Map<String, dynamic>.from(res as Map);
                      }
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    setState(() {});
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('فشل الحفظ: $e')),
                    );
                  } finally {
                    setD(() => saving = false);
                  }
                },
                child: saving
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف عميل'),
        content: const Text('هل تريد حذف هذا العميل؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await api.delete('api/customers/$id', auth: true);
      setState(() => _items.removeWhere((e) => _int(e['id']) == id));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف العميل')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('العملاء')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _createOrEdit(),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('إضافة عميل'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? const Center(child: Text('لا يوجد عملاء بعد'))
            : ListView.separated(
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = _items[i];
            final addrs = [
              _str(c['address']),
              _str(c['address2']),
              _str(c['address3']),
            ].where((s) => s.isNotEmpty).join(' • ');
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(_str(c['name'], 'عميل')),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_str(c['phone']),
                      textDirection: TextDirection.ltr),
                  if (addrs.isNotEmpty) Text(addrs),
                ],
              ),
              onTap: () => _createOrEdit(current: c),
              trailing: IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed: () => _delete(_int(c['id'])),
              ),
            );
          },
        ),
      ),
    );
  }
}
