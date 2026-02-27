import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert'; 
import 'package:http/http.dart' as http; 
import 'package:flutter/foundation.dart'; 
import 'employees.dart';

class WorkRequestForm extends StatefulWidget {
  const WorkRequestForm({super.key});
  @override
  State<WorkRequestForm> createState() => _WorkRequestFormState();
}

class _WorkRequestFormState extends State<WorkRequestForm> {
  String? selectedName;
  String displayedPosition = "กรุณาเลือกชื่อ";
  final TextEditingController _locationController = TextEditingController();
  DateTimeRange? selectedDateRange;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String totalHours = '0';
  int workDaysCount = 0;
  XFile? _pickedFile; 
  final ImagePicker _picker = ImagePicker();

  List<String> getAllNames() {
    List<String> names = [];
    employeeData.forEach((position, list) => names.addAll(list));
    names.sort();
    return names;
  }

  String findPosition(String name) {
    String found = "-";
    employeeData.forEach((position, list) {
      if (list.contains(name)) found = position;
    });
    return found;
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 15, maxWidth: 400);
    if (image != null) setState(() => _pickedFile = image);
  }

  void _calculateDuration() {
    if (selectedDateRange != null && startTime != null && endTime != null) {
      int count = 0;
      DateTime current = selectedDateRange!.start;
      while (current.isBefore(selectedDateRange!.end) || current.isAtSameMomentAs(selectedDateRange!.end)) {
        if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) count++;
        current = current.add(const Duration(days: 1));
      }
      workDaysCount = count;
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, startTime!.hour, startTime!.minute);
      final end = DateTime(now.year, now.month, now.day, endTime!.hour, endTime!.minute);
      var diffPerDay = end.difference(start).inMinutes / 60;
      if (diffPerDay < 0) diffPerDay += 24; 
      setState(() => totalHours = (diffPerDay * workDaysCount).toStringAsFixed(1));
    }
  }

  Future<void> sendEmail() async {
    if (selectedName == null || _pickedFile == null || selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลและถ่ายรูปให้ครบถ้วน')));
      return;
    }
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final Uint8List imageBytes = await _pickedFile!.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': 'service_zxk182e',   
          'template_id': 'template_zf7z84p', 
          'user_id': 'aFgdAGwPICmxIVno3',    
          'template_params': {
            'employee_name': selectedName,
            'position': displayedPosition,
            'work_location': _locationController.text,
            'date_range': '${DateFormat('dd/MM/yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(selectedDateRange!.end)}',
            'total_hours': totalHours,
            'work_image': 'data:image/jpeg;base64,$base64Image',
          }
        }),
      );
      Navigator.pop(context); 
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ส่งรายงานสำเร็จแล้ว!')));
        Navigator.pop(context);
      } else {
        throw 'ส่งไม่สำเร็จ: ${response.body}';
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('IDPASSGLOBAL', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            Text('แจ้งงานนอกสถานที่', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
          ],
        ), 
        backgroundColor: Colors.indigo[900], 
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 80,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เลือกชื่อพนักงาน', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: getAllNames().map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
              onChanged: (val) => setState(() {
                selectedName = val;
                displayedPosition = findPosition(val!);
              }),
            ),
            const SizedBox(height: 10),
            Text('ตำแหน่ง: $displayedPosition', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            const Divider(height: 40),
            const Text('สถานที่ปฏิบัติงาน', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _locationController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'ระบุสถานที่/หน้างาน')),
            const SizedBox(height: 20),
            const Text('ช่วงวันที่', style: TextStyle(fontWeight: FontWeight.bold)),
            OutlinedButton.icon(
              onPressed: () async {
                final r = await showDateRangePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime(2030));
                if (r != null) { setState(() => selectedDateRange = r); _calculateDuration(); }
              },
              icon: const Icon(Icons.date_range),
              label: Text(selectedDateRange == null ? 'เลือกวันที่เริ่ม-จบ' : '${DateFormat('dd/MM/yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(selectedDateRange!.end)}'),
            ),
            const SizedBox(height: 15),
            Row(children: [
              _timePicker('เริ่มงาน', startTime, (t) { setState(() => startTime = t); _calculateDuration(); }),
              const SizedBox(width: 10),
              _timePicker('เลิกงาน', endTime, (t) { setState(() => endTime = t); _calculateDuration(); }),
            ]),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('จำนวน: $workDaysCount วัน', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('รวม: $totalHours ชม.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text('รูปถ่ายหน้างาน / เช็คอิน', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 200, width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10), color: Colors.grey[100]),
              child: _pickedFile == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        ElevatedButton(onPressed: () => _pickImage(ImageSource.camera), child: const Text('ถ่ายรูป')),
                        const SizedBox(width: 10),
                        ElevatedButton(onPressed: () => _pickImage(ImageSource.gallery), child: const Text('อัลบั้ม')),
                      ])
                    ])
                  : Stack(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(10), child: kIsWeb ? Image.network(_pickedFile!.path, width: double.infinity, height: 200, fit: BoxFit.cover) : Image.file(File(_pickedFile!.path), width: double.infinity, height: 200, fit: BoxFit.cover)),
                        Positioned(top: 5, right: 5, child: CircleAvatar(backgroundColor: Colors.red, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _pickedFile = null)))),
                    ]),
            ),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: sendEmail, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900]), child: const Text('ส่งข้อมูลการทำงาน', style: TextStyle(color: Colors.white, fontSize: 18)))),
          ],
        ),
      ),
    );
  }

  Widget _timePicker(String label, TimeOfDay? time, Function(TimeOfDay) onSelect) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label),
      OutlinedButton(onPressed: () async {
        final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
        if (t != null) onSelect(t);
      }, child: Text(time == null ? '--:--' : time.format(context))),
    ]));
  }
}