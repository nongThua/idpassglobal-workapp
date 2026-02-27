import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WorkRequestForm extends StatefulWidget {
  final bool isAdminMode;
  const WorkRequestForm({super.key, this.isAdminMode = false});
  @override
  State<WorkRequestForm> createState() => _WorkRequestFormState();
}

class _WorkRequestFormState extends State<WorkRequestForm> {
  String? selectedEmployeeId, selectedEmployeeName, selectedEmployeePosition;
  final TextEditingController _locationController = TextEditingController();
  DateTimeRange? selectedDateRange;
  
  // ปรับ Default เป็น 09:30 - 18:30 เพื่อให้ทำงานจริงครบ 8 ชม. หลังหักพัก
  TimeOfDay? startTime = const TimeOfDay(hour: 9, minute: 30);
  TimeOfDay? endTime = const TimeOfDay(hour: 18, minute: 30);
  
  String totalHours = '0'; 
  XFile? _pickedFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (!widget.isAdminMode) _loadUser();
    _calc(); // คำนวณค่าเริ่มต้นทันที
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        selectedEmployeeName = doc.data()?['name'];
        selectedEmployeePosition = doc.data()?['position'];
      });
    }
  }

  // --- แก้ไข Logic: ตัดช่วง 12:00-13:00 ออกอัตโนมัติพนักงานแก้ไม่ได้ ---
  void _calc() {
    if (startTime != null && endTime != null) {
      double start = startTime!.hour + (startTime!.minute / 60.0);
      double end = endTime!.hour + (endTime!.minute / 60.0);
      
      if (end < start) end += 24; 

      double diff = end - start;

      // หักช่วงพักเที่ยง 12:00 - 13:00 ตามจริง
      double breakStart = 12.0;
      double breakEnd = 13.0;

      double overlapStart = start > breakStart ? start : breakStart;
      double overlapEnd = end < breakEnd ? end : breakEnd;

      if (overlapStart < overlapEnd) {
        double overlapDuration = overlapEnd - overlapStart;
        diff -= overlapDuration;
      }

      int days = (selectedDateRange != null) ? (selectedDateRange!.duration.inDays + 1) : 1;
      setState(() {
        if (diff < 0) diff = 0;
        totalHours = (diff * days).toStringAsFixed(1);
      });
    }
  }

  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูปใหม่ (Camera)'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากคลังรูปภาพ (Gallery)'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source, 
      imageQuality: 10, 
      maxWidth: 600,
    );
    if (image != null) setState(() => _pickedFile = image);
  }

  Future<void> _sendEmailJS() async {
    const serviceId = 'service_zxk182e'; 
    const templateId = 'template_zf7z84p'; 
    const publicKey = 'aFgdAGwPICmxIVno3';

    String base64Image = "";
    if (_pickedFile != null) {
      final bytes = await _pickedFile!.readAsBytes();
      base64Image = base64Encode(bytes);
    }

    try {
      await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'employee_name': selectedEmployeeName,
            'position': selectedEmployeePosition,
            'work_location': _locationController.text,
            'date_range': selectedDateRange != null
                ? '${DateFormat('dd/MM/yy').format(selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(selectedDateRange!.end)}'
                : '-',
            'total_hours': totalHours,
            'name': selectedEmployeeName,
            'email': FirebaseAuth.instance.currentUser?.email ?? '',
            'work_image': base64Image.isNotEmpty ? 'data:image/jpeg;base64,$base64Image' : '',
          }
        }),
      );
    } catch (e) {
      print("EmailJS Exception: $e");
    }
  }

  Future<void> _submit() async {
    if (selectedEmployeeName == null || _locationController.text.isEmpty || selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบและเลือกวันที่")));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    try {
      await FirebaseFirestore.instance.collection('work_requests').add({
        'name': selectedEmployeeName,
        'position': selectedEmployeePosition,
        'location': _locationController.text,
        'date_range': '${DateFormat('dd/MM/yy').format(selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(selectedDateRange!.end)}',
        'total_hours': totalHours,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _sendEmailJS();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("บันทึกและส่งข้อมูลสำเร็จ!"), backgroundColor: Colors.indigo),
        );
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isAdminMode ? "ลงงานแทน" : "แจ้งงานนอกสถานที่"),
          backgroundColor: Colors.indigo[900],
          foregroundColor: Colors.white,
          centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _profileHeader(),
          const SizedBox(height: 20),
          TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                  labelText: "สถานที่ปฏิบัติงาน",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_drop))),
          const SizedBox(height: 15),
          _dateBtn(),
          const SizedBox(height: 15),
          Row(children: [
            _timeBtn("เริ่ม", startTime, (t) {
              startTime = t;
              _calc();
            }, const TimeOfDay(hour: 9, minute: 30)),
            const SizedBox(width: 10),
            _timeBtn("เลิก", endTime, (t) {
              endTime = t;
              _calc();
            }, const TimeOfDay(hour: 18, minute: 30)),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.indigo[100]!)
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("รวมเวลาทำงานจริง:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("$totalHours ชม.", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
          ),
          const Text("* ระบบหักเวลาพักเที่ยง (12:00-13:00) อัตโนมัติ", style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 20),
          const Text("หลักฐานการปฏิบัติงาน (รูปหน้างาน)",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _imageBox(),
          const SizedBox(height: 30),
          ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.indigo[900],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              child: const Text("ยืนยันส่งข้อมูล",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }

  Widget _imageBox() {
    return GestureDetector(
      onTap: _showImageSourceOptions,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[300]!, width: 2)),
        child: _pickedFile == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    Icon(Icons.add_a_photo_rounded, size: 50, color: Colors.grey),
                    SizedBox(height: 10),
                    Text("กดเพื่อถ่ายรูป หรือ เลือกจากคลัง", style: TextStyle(color: Colors.grey)),
                  ])
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: kIsWeb
                          ? Image.network(_pickedFile!.path, fit: BoxFit.cover)
                          : Image.file(File(_pickedFile!.path), fit: BoxFit.cover)),
                  Positioned(
                    right: 8, top: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      radius: 18,
                      child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                          onPressed: () => setState(() => _pickedFile = null)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _profileHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!)),
      child: Row(children: [
        const Icon(Icons.badge_rounded, size: 40, color: Colors.indigo),
        const SizedBox(width: 15),
        Expanded(
            child: widget.isAdminMode
                ? StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Text("โหลดชื่อ...");
                      return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedEmployeeId,
                        hint: const Text("เลือกพนักงาน"),
                        items: snap.data!.docs
                            .map((doc) => DropdownMenuItem(
                                value: doc.id,
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(doc['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(doc['position'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ]),
                                onTap: () {
                                  selectedEmployeeName = doc['name'];
                                  selectedEmployeePosition = doc['position'];
                                }))
                            .toList(),
                        onChanged: (v) => setState(() => selectedEmployeeId = v),
                      ));
                    })
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(selectedEmployeeName ?? "...", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(selectedEmployeePosition ?? "...", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ]))
      ]),
    );
  }

  Widget _dateBtn() {
    return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
        onPressed: () async {
          final r = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime(2030));
          if (r != null) {
            setState(() {
              selectedDateRange = r;
              _calc();
            });
          }
        },
        icon: const Icon(Icons.date_range),
        label: Text(selectedDateRange == null
            ? "เลือกวันที่"
            : "${DateFormat('dd/MM/yy').format(selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(selectedDateRange!.end)}"));
  }

  Widget _timeBtn(String l, TimeOfDay? t, Function(TimeOfDay) s, TimeOfDay defaultT) {
    return Expanded(
        child: OutlinedButton(
            onPressed: () async {
              final res = await showTimePicker(context: context, initialTime: t ?? defaultT);
              if (res != null) {
                setState(() => s(res));
                _calc();
              }
            },
            child: Text(t == null ? l : t.format(context))));
  }
}