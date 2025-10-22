import 'package:flutter/material.dart';
import '../auth/login_page.dart';
import '../../core/session.dart';
import '../../core/api_client.dart';
import 'shipment_details_page.dart';
import 'add_shipment_page.dart';
import 'product_details_page.dart';
import 'add_product_page.dart';
import 'dart:convert';
import 'customers_list_page.dart';
import 'warehouses_list_page.dart';
import '../auth/auth_service.dart';
import 'profile_page.dart';

class ManagerHome extends StatefulWidget {
  final String userName;
  const ManagerHome({super.key, required this.userName});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

// ===== Helpers =====
num _numFrom(dynamic v, [num fallback = 0]) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? fallback;
  return fallback;
}
int _intFrom(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? fallback;
  if (v is num) return v.toInt();
  return fallback;
}
String _str(dynamic v, [String fallback = '']) =>
    (v is String && v.isNotEmpty) ? v : fallback;

String _roleToArabic(String role) {
  final r = role.toLowerCase().trim();
  if (r.contains('manager') || r == 'admin' || r.contains('مدير')) return 'مدير';
  if (r.contains('driver') || r.contains('سائق')) return 'سائق';
  return role;
}

// ===== Models =====
class Product {
  final int id;
  final String name;
  final String unit;
  final num price;
  final int stockQty;
  final bool isActive;
  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.stockQty,
    required this.isActive,
  });
  factory Product.fromJson(Map<String, dynamic> m) => Product(
    id: _intFrom(m['id']),
    name: _str(m['name']),
    unit: _str(m['unit']),
    price: _numFrom(m['price']),
    stockQty: _intFrom(m['stock_qty']),
    isActive: (m['is_active'] ?? true) as bool,
  );
}

class OrderModel {
  final int id;
  final String productName;
  final String warehouse;
  final String driver;
  final String customerName;
  final String customerAddress;
  final String status;
  OrderModel({
    required this.id,
    required this.productName,
    required this.warehouse,
    required this.driver,
    required this.customerName,
    required this.customerAddress,
    required this.status,
  });
  factory OrderModel.fromJson(Map<String, dynamic> m) => OrderModel(
    id: _intFrom(m['id']),
    productName: _str(m['product_name'] ?? m['product']),
    warehouse: _str(m['warehouse']),
    driver: _str(m['driver_username'] ?? m['driver']),
    customerName: _str(m['customer_name'] ?? m['customer']),
    customerAddress: _str(m['customer_address'] ?? m['address']),
    status: _str(m['current_status'], 'NEW'),
  );
}

class DriverModel {
  final int id;
  final String name;
  final String phone;
  final String status;
  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
  });
  factory DriverModel.fromJson(Map<String, dynamic> m) => DriverModel(
    id: _intFrom(m['id']),
    name: _str(m['name']),
    phone: _str(m['phone']),
    status: _str(m['status'], 'غير متاح'),
  );
}

// ===== API paths =====
class _API {
  static const products = 'api/products';
  static const orders = 'api/shipments/manager';
  static const drivers = 'api/drivers';
}

class _ManagerHomeState extends State<ManagerHome> {
  final api = ApiClient();

  late Future<List<Product>> _products;
  late Future<List<OrderModel>> _orders;
  late Future<List<DriverModel>> _drivers;
  int _tabIndex = 0;

  // بيانات البروفايل للـ Drawer + الدور
  String _displayName = '';
  String _phone = '';
  String _roleAr = '';

  @override
  void initState() {
    super.initState();
    _reload();
    _loadProfile();
  }

  void _reload() {
    _products = _fetchProducts();
    _orders = _fetchOrders();
    _drivers = _fetchDrivers();
  }

  Future<void> _loadProfile() async {
    try {
      final who = await AuthService().whois();
      setState(() {
        _displayName = who.name.isNotEmpty ? who.name : widget.userName;
        _phone = who.phone;
        _roleAr = _roleToArabic(who.role);
      });
    } catch (_) {
      setState(() {
        _displayName = widget.userName;
      });
    }
  }

  Future<List<Product>> _fetchProducts() async {
    try {
      final data = await api.getJson(_API.products, auth: true);
      final List<dynamic> list = data is List
          ? data
          : ((data as Map)['results'] as List?) ??
          ((data as Map)['data'] as List?) ??
          <dynamic>[];
      return list
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <Product>[];
    }
  }

  Future<List<OrderModel>> _fetchOrders() async {
    try {
      final data = await api.getJson(_API.orders, auth: true);
      final List<dynamic> list = data is List
          ? data
          : ((data as Map)['results'] as List?) ??
          ((data as Map)['data'] as List?) ??
          <dynamic>[];
      return list
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <OrderModel>[];
    }
  }

  Future<List<DriverModel>> _fetchDrivers() async {
    try {
      final data = await api.getJson(_API.drivers, auth: true);
      final List<dynamic> list = data is List
          ? data
          : ((data as Map)['results'] as List?) ??
          ((data as Map)['data'] as List?) ??
          <dynamic>[];
      return list
          .map((e) => DriverModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <DriverModel>[];
    }
  }

  Future<({int products, int pendingOrders, int availableDrivers})>
  _counts() async {
    final results = await Future.wait([_products, _orders, _drivers]);
    final products = results[0] as List<Product>;
    final orders = results[1] as List<OrderModel>;
    final drivers = results[2] as List<DriverModel>;

    final pending = orders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'new' || s == 'pending' || s == 'معلق';
    }).length;

    final available = drivers.where((d) {
      final t = d.status.toLowerCase();
      return t == 'available' || t == 'متاح';
    }).length;

    return (
    products: products.length,
    pendingOrders: pending,
    availableDrivers: available
    );
  }

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  // ===== Drawer Widget =====
  Widget _buildDrawer() {
    final headerName =
        '${_displayName.isEmpty ? widget.userName : _displayName}'
        '${_roleAr.isNotEmpty ? ' - $_roleAr' : ''}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                currentAccountPicture: const CircleAvatar(
                  child: Icon(Icons.person, size: 28),
                ),
                accountName: Text(headerName),
                accountEmail: Text(
                  _phone.isEmpty ? '—' : _phone,
                  textDirection: TextDirection.ltr,
                ),
              ),
              // القسم 1: البروفايل (يفتح صفحة ProfilePage)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('بياناتي'),
                subtitle: const Text('الاسم، الدور، ورقم الهاتف'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(
                        name: _displayName.isEmpty ? widget.userName : _displayName,
                        role: _roleAr,
                        phone: _phone,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),

              // القسم 2: المستودعات
              ListTile(
                leading: const Icon(Icons.store_mall_directory_outlined),
                title: const Text('المستودعات'),
                subtitle: const Text('عرض/إضافة/تعديل/حذف المستودعات'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WarehousesListPage(),
                    ),
                  );
                },
              ),

              // القسم 3: العملاء
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('العملاء'),
                subtitle: const Text('عرض/إضافة/تعديل/حذف العملاء'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustomersListPage(),
                    ),
                  );
                },
              ),

              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج',
                    style: TextStyle(color: Colors.red)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle =
        '${_displayName.isEmpty ? widget.userName : _displayName}'
        '${_roleAr.isNotEmpty ? ' - $_roleAr' : ''}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: _buildDrawer(),
        appBar: AppBar(
          title: Text(appBarTitle),
          actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await Future.wait([_products, _orders, _drivers]);
            await _loadProfile();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FutureBuilder<
                  ({int products, int pendingOrders, int availableDrivers})>(
                future: _counts(),
                builder: (context, snap) {
                  if (!snap.hasData) return const _CountsSkeleton();
                  final c = snap.data!;
                  return Column(
                    children: [
                      _StatCard(
                          title: 'عدد المنتجات الكلي',
                          value: '${c.products}',
                          icon: Icons.inventory_2_outlined),
                      const SizedBox(height: 10),
                      _StatCard(
                          title: 'عدد الطلبات المعلّقة',
                          value: '${c.pendingOrders}',
                          icon: Icons.receipt_long_outlined),
                      const SizedBox(height: 10),
                      _StatCard(
                          title: 'عدد السائقين المتاحين',
                          value: '${c.availableDrivers}',
                          icon: Icons.local_shipping_outlined),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              _Tabs(index: _tabIndex, onChanged: (i) => setState(() => _tabIndex = i)),
              const SizedBox(height: 12),

              switch (_tabIndex) {
                0 => _ProductsSection(fut: _products, onChanged: () => setState(_reload)),
                1 => FutureBuilder<List<OrderModel>>(
                  future: _orders,
                  builder: (context, snap) {
                    final orders = snap.data ?? const <OrderModel>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('طلبات(${orders.length})',
                                style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة شحنة'),
                              onPressed: () async {
                                final created = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => const AddShipmentPage(),
                                  ),
                                );
                                if (created == true) setState(_reload);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _OrdersList(
                          orders: orders,
                          onChanged: () {
                            setState(_reload);
                          },
                        ),
                      ],
                    );
                  },
                ),
                _ => _DriversSection(fut: _drivers),
              },
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Widgets =====
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 28, color: const Color(0xFFF76D20)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value,
              style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}

class _CountsSkeleton extends StatelessWidget {
  const _CountsSkeleton();
  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
        height: 64,
        decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12)));
    return Column(
        children: [box(), const SizedBox(height: 10), box(), const SizedBox(height: 10), box()]);
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFF76D20);
    ButtonStyle style(bool active) => OutlinedButton.styleFrom(
      side: const BorderSide(color: primary),
      backgroundColor: active ? primary : Colors.white,
      foregroundColor: active ? Colors.white : primary,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size(0, 40),
    );
    return Row(
      children: [
        Expanded(
            child: OutlinedButton(
                onPressed: () => onChanged(2),
                style: style(index == 2),
                child: const Text('سائقين'))),
        const SizedBox(width: 10),
        Expanded(
            child: OutlinedButton(
                onPressed: () => onChanged(1),
                style: style(index == 1),
                child: const Text('طلبات'))),
        const SizedBox(width: 10),
        Expanded(
            child: OutlinedButton(
                onPressed: () => onChanged(0),
                style: style(index == 0),
                child: const Text('منتجات'))),
      ],
    );
  }
}

class _ProductsSection extends StatelessWidget {
  final Future<List<Product>> fut;
  final VoidCallback? onChanged;
  const _ProductsSection({required this.fut, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: fut,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
              child:
              Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        final list = snap.data ?? const <Product>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('منتجات(${list.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة منتج'),
                  onPressed: () async {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const AddProductPage()),
                    );
                    if (ok == true) onChanged?.call();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('لايوجد منتجات حتى الآن')),
              )
            else
              ...list.map((p) => InkWell(
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) =>
                            ProductDetailsPage(productId: p.id)),
                  );
                  if (changed == true) onChanged?.call();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 40, color: Color(0xFFF76D20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${p.stockQty} قطعة • ${p.unit}',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('السعر: ${p.price} ر.س',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'تعديل',
                            onPressed: () async {
                              final changed =
                              await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailsPage(
                                      productId: p.id),
                                ),
                              );
                              if (changed == true) onChanged?.call();
                            },
                            icon: const Icon(Icons.edit, size: 20),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            color: Colors.red,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('حذف المنتج'),
                                  content:
                                  const Text('هل أنت متأكد من حذف المنتج؟'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('إلغاء')),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('حذف')),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              try {
                                await ApiClient()
                                    .delete('api/products/${p.id}',
                                    auth: true);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('تم حذف المنتج')));
                                onChanged?.call();
                              } on ApiException catch (e) {
                                String msg = 'لا يمكن حذف المنتج.';
                                try {
                                  final j = jsonDecode(e.body);
                                  final detail = j['detail']?.toString();
                                  final cnt =
                                  j['shipments_count']?.toString();
                                  if (detail != null) {
                                    msg =
                                    '$detail${cnt != null ? ' | الشحنات المرتبطة: $cnt' : ''}';
                                  }
                                } catch (_) {}
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentMaterialBanner()
                                  ..showMaterialBanner(
                                    MaterialBanner(
                                      backgroundColor:
                                      Colors.red.shade700,
                                      content: Text(msg,
                                          style: const TextStyle(
                                              color: Colors.white)),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              ScaffoldMessenger.of(context)
                                                  .hideCurrentMaterialBanner(),
                                          child: const Text('إغلاق',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                        Text('فشل الحذف: $e')));
                              }
                            },
                            icon:
                            const Icon(Icons.delete_forever, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          ],
        );
      },
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final VoidCallback? onChanged;
  const _OrdersList({required this.orders, this.onChanged});

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'assigned':
      case 'مخصص':
        return Colors.green;
      case 'new':
      case 'pending':
      case 'معلق':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('لايوجد طلبات حتى الآن')),
      );
    }
    return Column(
      children: [
        for (final o in orders)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ShipmentDetailsPage(shipmentId: o.id),
                ),
              );
              if (changed == true) {
                onChanged?.call();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('السائق: ${o.driver.isEmpty ? '—' : o.driver}'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(o.status).withOpacity(.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(o.status,
                          style:
                          TextStyle(color: _statusColor(o.status))),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'تعديل',
                      onPressed: () async {
                        final changed =
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                ShipmentDetailsPage(shipmentId: o.id),
                          ),
                        );
                        if (changed == true) onChanged?.call();
                      },
                      icon: const Icon(Icons.edit, size: 20),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('حذف الشحنة'),
                            content: const Text('هل أنت متأكد من حذف الشحنة؟'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('إلغاء')),
                              FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('حذف')),
                            ],
                          ),
                        );
                        if (confirm != true) return;

                        try {
                          final api = ApiClient();
                          await api.delete('api/shipments/${o.id}',
                              auth: true);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حذف الشحنة')),
                          );
                          onChanged?.call();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الحذف: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_forever, size: 20),
                      color: Colors.red,
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text('اسم صاحب الطلب: ${o.customerName.isEmpty ? '—' : o.customerName}'),
                  Text(
                    'العنوان: ${o.customerAddress.isEmpty ? '—' : o.customerAddress}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DriversSection extends StatelessWidget {
  final Future<List<DriverModel>> fut;
  const _DriversSection({required this.fut});
  Color _chipColor(String s) {
    final t = s.toLowerCase();
    if (t == 'متاح' || t == 'available') return Colors.green;
    if (t == 'مشغول' || t == 'busy') return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DriverModel>>(
      future: fut,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
              child:
              Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        final list = snap.data ?? const <DriverModel>[];
        if (list.isEmpty) {
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('لايوجد سائقين حتى الآن')));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سائقين(${list.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...list.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                children: [
                  Expanded(
                      child:
                      Text('سائق: ${d.name}\nرقم الجوال: ${d.phone}')),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _chipColor(d.status).withOpacity(.15),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(d.status,
                        style: TextStyle(color: _chipColor(d.status))),
                  ),
                ],
              ),
            )),
          ],
        );
      },
    );
  }
}
