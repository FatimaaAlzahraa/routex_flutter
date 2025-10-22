import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';

int _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
num _n(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}
String _s(dynamic v, [String f = '']) {
  final t = (v ?? '').toString();
  return t.isEmpty ? f : t;
}

class ProductDetailsPage extends StatefulWidget {
  final int productId;
  const ProductDetailsPage({super.key, required this.productId});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  final api = ApiClient();
  final _form = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;

  // fields
  String _name = '';
  String _unit = '';
  String _imageUrl = ''; // رابط الصورة الحالية (إن وجد)
  num _price = 0;
  int _stock = 0;
  bool _active = true;

  // صورة جديدة للاستبدال (اختياري)
  XFile? _pickedImage;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final m = await api.getJson('api/products/${widget.productId}', auth: true)
      as Map<String, dynamic>;
      setState(() {
        _name = _s(m['name']);
        _unit = _s(m['unit']);
        _imageUrl = _s(m['image']);
        _price = _n(m['price']);
        _stock = _i(m['stock_qty']);
        _active = (m['is_active'] ?? true) as bool;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل تحميل المنتج: $e')));
      Navigator.pop(context, false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('المعرض'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('الكاميرا'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (src == null) return;

    final x = await _picker.pickImage(source: src, imageQuality: 85);
    if (x != null) setState(() => _pickedImage = x);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();

    final fields = <String, String>{
      'name': _name.trim(),
      'unit': _unit.trim(),
      'price': _price.toString(),
      'stock_qty': _stock.toString(),
      'is_active': _active.toString(),
    };

    // صورة جديدة؟ ابعتها كـ Map<String, File>
    Map<String, File>? files;
    if (_pickedImage != null) {
      files = {'image': File(_pickedImage!.path)};
    }

    setState(() => _saving = true);
    try {
      await api.patchMultipart(
        'api/products/${widget.productId}',
        fields: fields,
        files: files,
        auth: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: const Text('هل تريد حذف المنتج؟ لو مرتبط بشحنات لن يُحذف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await api.delete('api/products/${widget.productId}', auth: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف المنتج')));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      // 409 من الباك لما المنتج مرتبط بشحنات
      String msg = 'فشل الحذف';
      try {
        final j = ApiClient.tryDecode(e.body) ?? {};
        final detail = j['detail']?.toString();
        final cnt = j['shipments_count']?.toString();
        if (detail != null) {
          msg = '$detail${cnt != null ? ' | الشحنات المرتبطة: $cnt' : ''}';
        }
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentMaterialBanner()
        ..showMaterialBanner(
          MaterialBanner(
            backgroundColor: Colors.red.shade700,
            content: Text(msg, style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = _pickedImage != null
        ? Image.file(File(_pickedImage!.path),
        height: 160, width: double.infinity, fit: BoxFit.cover)
        : (_imageUrl.isNotEmpty
        ? Image.network(_imageUrl,
        height: 160, width: double.infinity, fit: BoxFit.cover)
        : const Center(
      child: Text('لا توجد صورة — اضغط لاختيار صورة'),
    ));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل المنتج #${widget.productId}'),
          actions: [
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_forever),
              color: Colors.red,
            ),
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
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      alignment: Alignment.center,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageWidget,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: _name,
                    decoration: const InputDecoration(labelText: 'اسم المنتج'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'أدخل الاسم'
                        : null,
                    onSaved: (v) => _name = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _unit,
                    decoration:
                    const InputDecoration(labelText: 'الوحدة (مثلاً: 1 كيلو)'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'أدخل الوحدة'
                        : null,
                    onSaved: (v) => _unit = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _price.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'السعر'),
                    validator: (v) =>
                    (num.tryParse(v ?? '') == null) ? 'أدخل رقماً' : null,
                    onSaved: (v) => _price = num.parse(v!.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _stock.toString(),
                    keyboardType: TextInputType.number,
                    decoration:
                    const InputDecoration(labelText: 'الكمية في المخزون'),
                    validator: (v) => (int.tryParse(v ?? '') == null)
                        ? 'أدخل عدداً صحيحاً'
                        : null,
                    onSaved: (v) => _stock = int.parse(v!.trim()),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('مُفعل'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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
