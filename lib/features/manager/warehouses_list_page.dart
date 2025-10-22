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

class WarehousesListPage extends StatefulWidget {
  const WarehousesListPage({super.key});

  @override
  State<WarehousesListPage> createState() => _WarehousesListPageState();
}

class _WarehousesListPageState extends State<WarehousesListPage> {
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
      final data = await api.getJson('api/warehouses', auth: true);
      setState(() => _items = _normalize(data));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل المستودعات: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit({Map<String, dynamic>? current}) async {
    final name = TextEditingController(text: _str(current?['name']));
    final loc = TextEditingController(text: _str(current?['location']));
    final form = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setD) => AlertDialog(
            title: Text(current == null ? 'إضافة مستودع' : 'تعديل مستودع'),
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'اسم المستودع'),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'أدخل الاسم' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: loc,
                    decoration: const InputDecoration(labelText: 'الموقع / العنوان'),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'أدخل الموقع' : null,
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
                  if (!form.currentState!.validate()) return;
                  setD(() => saving = true);
                  try {
                    if (current == null) {
                      final res = await api.postJson(
                        'api/warehouses',
                        {
                          "name": name.text.trim(),
                          "location": loc.text.trim(),
                        },
                        auth: true,
                      );

                      // امنع تكرار (name+location) في القائمة المحلية فقط
                      final keyName =
                      (res['name'] ?? '').toString().trim().toLowerCase();
                      final keyLoc =
                      (res['location'] ?? '').toString().trim().toLowerCase();
                      final exists = _items.any((w) =>
                      (w['name'] ?? '').toString().trim().toLowerCase() ==
                          keyName &&
                          (w['location'] ?? '')
                              .toString()
                              .trim()
                              .toLowerCase() ==
                              keyLoc);
                      if (!exists) {
                        _items.insert(
                          0,
                          {
                            "id": res['id'],
                            "name": res['name'],
                            "location": res['location'],
                          },
                        );
                      }
                    } else {
                      final id = _int(current['id']);
                      final res = await api.patchJson(
                        'api/warehouses/$id',
                        {
                          "name": name.text.trim(),
                          "location": loc.text.trim(),
                        },
                        auth: true,
                      );
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
                      SnackBar(content: Text('فشل الحفظ: $e')),
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
        title: const Text('حذف مستودع'),
        content: const Text('هل تريد حذف هذا المستودع؟'),
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
      await api.delete('api/warehouses/$id', auth: true);
      setState(() => _items.removeWhere((e) => _int(e['id']) == id));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف المستودع')));
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
        appBar: AppBar(title: const Text('المستودعات')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _createOrEdit(),
          icon: const Icon(Icons.add_business),
          label: const Text('إضافة مستودع'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? const Center(child: Text('لا يوجد مستودعات بعد'))
            : ListView.separated(
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final w = _items[i];
            return ListTile(
              leading: const Icon(Icons.store_mall_directory_outlined),
              title: Text(_str(w['name'], 'مستودع')),
              subtitle: Text(_str(w['location'])),
              onTap: () => _createOrEdit(current: w),
              trailing: IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed: () => _delete(_int(w['id'])),
              ),
            );
          },
        ),
      ),
    );
  }
}
