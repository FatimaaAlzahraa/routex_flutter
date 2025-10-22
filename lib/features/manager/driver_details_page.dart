import 'package:flutter/material.dart';
import '../../core/api_client.dart';

String _s(dynamic v, [String f = '']) {
  final t = (v ?? '').toString();
  return t.isEmpty ? f : t;
}
int _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class DriverDetailsPage extends StatefulWidget {
  final Map<String, dynamic> driver; // جاي من الليست مباشرة
  const DriverDetailsPage({super.key, required this.driver});

  @override
  State<DriverDetailsPage> createState() => _DriverDetailsPageState();
}

class _DriverDetailsPageState extends State<DriverDetailsPage> {
  final api = ApiClient();
  Map<String, dynamic>? _fresh; // لو حبيت تجيب آخر حالة من السيرفر (مش ضروري)

  Future<void> _reload() async {
    try {
      // نفس endpoint، لكن مفيش retrieve فردي؛ فا هنسيبه زي ما هو (اختياري).
      // تقدرِ تتجاهليه وتكتفي باللي جاي من الليست.
      // final list = await api.getJson('api/drivers', auth: true);
      // لو محتاجة تحدّثي… ابحثي على نفس id واستخرجي العنصر.
    } catch (_) {}
  }

  void _showNotAllowed(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.red.shade700,
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final d = _fresh ?? widget.driver;
    final name  = _s(d['name']);
    final phone = _s(d['phone']);
    final status= _s(d['status']);
    final last  = _s(d['last_seen_at']);
    final activeShipment = d['current_active_shipment_id'];

    Color chipColor() {
      final t = status.toLowerCase();
      if (t == 'متاح' || t == 'available') return Colors.green;
      if (t == 'مشغول' || t == 'busy') return Colors.red;
      return Colors.grey;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل السائق'),
          actions: [
            IconButton(
              tooltip: 'تعديل السائق',
              onPressed: () => _showNotAllowed('لا يمكن تعديل السائق من التطبيق. هذه العملية غير مدعومة في الـ API.'),
              icon: const Icon(Icons.edit),
            ),
            IconButton(
              tooltip: 'حذف السائق',
              onPressed: () => _showNotAllowed('لا يمكن حذف السائق من التطبيق. هذه العملية غير مدعومة في الـ API.'),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 42, color: Color(0xFFF76D20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor().withOpacity(.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(status, style: TextStyle(color: chipColor())),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone),
                title: const Text('رقم الجوال'),
                subtitle: Text(phone),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('آخر ظهور'),
                subtitle: Text(last.isEmpty ? '—' : last),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('شحنة نشِطة حالياً'),
                subtitle: Text(activeShipment == null ? 'لا يوجد' : '#$activeShipment'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _showNotAllowed('لا يمكن تنفيذ إجراءات للسائق من التطبيق حالياً.'),
                icon: const Icon(Icons.settings),
                label: const Text('إجراءات إدارية (غير متاحة)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
