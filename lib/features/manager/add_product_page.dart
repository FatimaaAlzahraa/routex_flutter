import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final api = ApiClient();
  final _form = GlobalKey<FormState>();

  String _name = '';
  String _unit = '';
  num _price = 0;
  int _stock = 0;
  bool _active = true;

  XFile? _pickedImage;
  bool _submitting = false;
  final _picker = ImagePicker();

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

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();

    setState(() => _submitting = true);
    try {
      final fields = <String, String>{
        'name': _name.trim(),
        'unit': _unit.trim(),
        'price': _price.toString(),
        'stock_qty': _stock.toString(),
        'is_active': _active.toString(),
      };

      // هنا بنبعت Map<String, File> مش List<MultipartFile>
      Map<String, File>? files;
      if (_pickedImage != null) {
        files = {'image': File(_pickedImage!.path)};
      }

      await api.postMultipart(
        'api/products',
        fields: fields,
        files: files,
        auth: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم إضافة المنتج')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الإضافة: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة منتج')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // صورة
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
                      child: _pickedImage == null
                          ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined),
                          SizedBox(height: 8),
                          Text('اختر صورة المنتج (اختياري)'),
                        ],
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_pickedImage!.path),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    decoration: const InputDecoration(labelText: 'اسم المنتج'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                    onSaved: (v) => _name = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration:
                    const InputDecoration(labelText: 'الوحدة (مثلاً: 1 كيلو)'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل الوحدة' : null,
                    onSaved: (v) => _unit = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'السعر'),
                    validator: (v) =>
                    (num.tryParse(v ?? '') == null) ? 'أدخل رقماً' : null,
                    onSaved: (v) => _price = num.parse(v!.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
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
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('إضافة المنتج'),
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
