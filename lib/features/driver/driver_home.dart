// lib/features/driver/driver_home.dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../auth/login_page.dart';
import 'update_status_page.dart';


class DriverHome extends StatefulWidget {
  final String userName;
  final String userPhone; // ⇐ جديد

  const DriverHome({
    super.key,
    required this.userName,
    required this.userPhone,
  });

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final _api = ApiClient();

  bool loading = true;
  String? error;
  List<ShipmentVM> shipments = [];

  @override
  void initState() {
    super.initState();
    _loadShipments();
  }

  Future<void> _loadShipments() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await _api.getJson('api/shipments/driver', auth: true);
      final list = (data as List).map((e) => ShipmentVM.fromJson(e)).toList();
      setState(() {
        shipments = list;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  bool get _hasActive =>
      shipments.any((s) => s.currentStatus == 'ASSIGNED' || s.currentStatus == 'IN_TRANSIT');

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('السائق'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : (error != null)
              ? Center(child: Text(error!))
              : RefreshIndicator(
            onRefresh: _loadShipments,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _headerCard(),
                const SizedBox(height: 12),
                // عنوان طلباتي (نص بولد في اليمين)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'طلباتي (${shipments.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                if (shipments.isEmpty)
                  const _EmptyBox()
                else
                  ...shipments.map(_shipmentTile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ====== UI pieces ======

  Widget _headerCard() {
    final isBusy = _hasActive;
    final chipColor = isBusy ? Colors.red.shade100 : Colors.green.shade100;
    final chipText = isBusy ? 'مشغول' : 'متاح';
    final chipTextColor = isBusy ? Colors.red.shade700 : Colors.green.shade700;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF76D20), width: 2), // برتقاني سميك
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // شارة الحالة يمين
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(chipText,
                style: TextStyle(
                    color: chipTextColor, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('سائق: ${widget.userName}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('رقم الجوال: ${widget.userPhone}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // بطاقة الشحنة (تفتح صفحة تحديث الحالة)
  Widget _shipmentTile(ShipmentVM s) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => UpdateStatusPage(
              shipmentId: s.id,
              currentStatus: s.currentStatus, // UPPERCASE from API
              customerName: s.customerName,
              customerAddress: s.customerAddress,
            ),
          ),
        );
        if (ok == true) _loadShipments();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شارة الحالة بالألوان المطلوبة
            Align(
              alignment: Alignment.centerRight,
              child: _statusChip(s.currentStatus),
            ),
            const SizedBox(height: 6),
            _kv('اسم صاحب الطلب:', s.customerName),
            _kv('العنوان:', s.customerAddress),
            _kv('الطلب:', s.productName),
            if (s.notes.isNotEmpty) _kv('ملاحظات:', s.notes),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg = Colors.white;
    switch (status) {
      case 'NEW':
        bg = Colors.red; // أحمر
        break;
      case 'ASSIGNED':
        bg = Colors.grey; // رمادي
        break;
      case 'IN_TRANSIT':
        bg = Colors.orange; // أصفر/برتقالي
        break;
      case 'DELIVERED':
        bg = Colors.green; // أخضر
        break;
      default:
        bg = Colors.blueGrey; // CANCELLED أو غيره
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusArabic(status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _statusArabic(String status) {
    switch (status) {
      case 'NEW':
        return 'جديد';
      case 'ASSIGNED':
        return 'مُخصص';
      case 'IN_TRANSIT':
        return 'جاري التوصيل';
      case 'DELIVERED':
        return 'تم التسليم';
      case 'CANCELLED':
        return 'أُلغي';
      default:
        return status;
    }
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: const Text('لا توجد طلبات حالياً'),
    );
  }
}

// ======= VM =======
class ShipmentVM {
  final String id;
  final String productName;
  final String customerName;
  final String customerAddress;
  final String notes;
  final String currentStatus;
  final String createdAt;

  ShipmentVM({
    required this.id,
    required this.productName,
    required this.customerName,
    required this.customerAddress,
    required this.notes,
    required this.currentStatus,
    required this.createdAt,
  });

  factory ShipmentVM.fromJson(Map<String, dynamic> j) => ShipmentVM(
    id: j['id'].toString(),
    productName: j['product_name'] ?? (j['product']?['name'] ?? ''),
    customerName: j['customer_name'] ?? (j['customer']?['name'] ?? ''),
    customerAddress: j['customer_address'] ?? (j['customer']?['address'] ?? ''),
    notes: (j['notes'] ?? '').toString(),
    currentStatus: (j['current_status'] ?? 'NEW').toString(),
    createdAt: (j['created_at'] ?? '').toString(),
  );
}
