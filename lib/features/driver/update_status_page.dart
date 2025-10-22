// lib/features/driver/update_status_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للـ inputFormatters
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/api_client.dart';

class UpdateStatusPage extends StatefulWidget {
  final String shipmentId;
  final String currentStatus; // NEW / ASSIGNED / IN_TRANSIT / DELIVERED / CANCELLED
  final String customerName;
  final String customerAddress;

  const UpdateStatusPage({
    super.key,
    required this.shipmentId,
    required this.currentStatus,
    required this.customerName,
    required this.customerAddress,
  });

  @override
  State<UpdateStatusPage> createState() => _UpdateStatusPageState();
}

class _UpdateStatusPageState extends State<UpdateStatusPage> {
  final _api = ApiClient();

  // form
  final _note = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _accCtrl = TextEditingController();

  String? _status;
  File? _photoFile;
  bool _busy = false;

  // تسميات إنجليزية كما في الباك
  static const Map<String, String> _labels = {
    'ASSIGNED': 'Assigned',
    'IN_TRANSIT': 'In transit',
    'DELIVERED': 'Delivered',
    'CANCELLED': 'Cancelled',
  };

  List<String> _allowedByCurrent() {
    switch (widget.currentStatus) {
      case 'NEW':
        return ['ASSIGNED', 'IN_TRANSIT', 'DELIVERED'];
      case 'ASSIGNED':
        return ['IN_TRANSIT', 'DELIVERED'];
      case 'IN_TRANSIT':
        return ['DELIVERED'];
      default:
        return <String>[];
    }
  }

  // ======== helpers ========
  Future<void> _pickImage() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (x != null) setState(() => _photoFile = File(x.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الكاميرا: $e')),
      );
    }
  }

  Future<void> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فعّل خدمة الموقع ثم أعد المحاولة')),
        );
        return;
      }

      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('صلاحية الموقع مطلوبة')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _latCtrl.text = pos.latitude.toStringAsFixed(6);
      _lngCtrl.text = pos.longitude.toStringAsFixed(6);
      _accCtrl.text = pos.accuracy.isFinite ? pos.accuracy.toStringAsFixed(0) : '';
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر جلب الموقع: $e')),
      );
    }
  }

  num? _numOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return num.tryParse(t);
  }

  Future<void> _submit() async {
    if (_status == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الحالة')),
      );
      return;
    }

    // فاليديشن بحسب الباك
    final acc = _numOrNull(_accCtrl.text);
    if (acc != null && acc > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('دقة GPS يجب أن تكون ≤ 30 متر')),
      );
      return;
    }
    final lat = _numOrNull(_latCtrl.text);
    final lng = _numOrNull(_lngCtrl.text);
    if ((lat != null) ^ (lng != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إرسال خط العرض والطول معًا')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await _api.postMultipart(
        'api/status-updates',
        auth: true,
        fields: {
          'shipment': widget.shipmentId,
          'status': _status!,
          if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
          if (lat != null && lng != null) ...{
            'latitude': lat.toString(),
            'longitude': lng.toString(),
            if (acc != null) 'location_accuracy_m': acc.toString(),
          },
        },
        files: _photoFile != null ? {'photo': _photoFile!} : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ التحديث')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _accCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowedByCurrent();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تحديث حالة الشحنة')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // كارت معلومات مختصرة
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shipment #${widget.shipmentId}', textDirection: TextDirection.ltr),
                    Text('العميل: ${widget.customerName}'),
                    Text('العنوان: ${widget.customerAddress}'),
                    Text('الحالة الحالية: ${widget.currentStatus}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ليستة الحالات المسموحة
            DropdownButtonFormField<String>(
              value: _status,
              items: allowed
                  .map((s) => DropdownMenuItem(
                value: s,
                child: Text(_labels[s] ?? s),
              ))
                  .toList(),
              onChanged: (v) => setState(() => _status = v),
              decoration: const InputDecoration(labelText: 'اختر الحالة'),
            ),
            const SizedBox(height: 12),

            // ملاحظات — يسمح بالعربي + اتجاه ومحاذاة
            TextFormField(
              controller: _note,
              maxLines: 3,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.multiline,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r"[0-9A-Za-z\u0600-\u06FF\s.,:;!?\-_'()]+"),
                ),
              ],
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: 12),

            // الصورة
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44), // << حل مشكلة العرض اللانهائي
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('التقاط صورة'),
                ),
                const SizedBox(width: 8),
                if (_photoFile != null)
                  Expanded(
                    child: Text(
                      _photoFile!.path.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // الموقع: زر + عرض مختصر
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44), // << نفس التعديل هنا
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _getLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('استخدم موقعي'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (_latCtrl.text.isNotEmpty && _lngCtrl.text.isNotEmpty)
                        ? 'Lat: ${_latCtrl.text}, Lng: ${_lngCtrl.text} • دقة: ${_accCtrl.text.isEmpty ? "-" : _accCtrl.text}م'
                        : 'لم يتم تحديد موقع',
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // إدخال يدوي للإحداثيات (اختياري)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Latitude (اختياري)'),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Longitude (اختياري)'),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'GPS دقة بالمتر (≤ 30) (اختياري)'),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 20),

            // حفظ
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ التحديث'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
