import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'employees.dart';

class LeaveRequestForm extends StatefulWidget {
  const LeaveRequestForm({super.key});
  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  String? selectedName;
  String displayedPosition = "กรุณาเลือกชื่อ"; 
  String? leaveType;
  final TextEditingController _reasonController = TextEditingController();
  DateTimeRange? leaveDateRange;
  final List<String> leaveTypes = ['ลาป่วย', 'ลากิจ', 'ลาพักร้อน', 'ลาอื่น ๆ'];

  List<String> getAllNames() {
    List<String> names = [];
    employeeData.forEach((position, list) => names.addAll(list));
    names.sort();
    return names;
  }

  String findPosition(String name) {
    String found = "-";
    employeeData.forEach((position, list) { if (list.contains(name)) found = position; });
    return found;
  }

  Future<void> sendLeaveEmail() async {
    if (selectedName == null || leaveType == null || leaveDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลการลาให้ครบถ้วน')));
      return;
    }
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': 'service_zxk182e',   
          'template_id': 'template_cn7r5nd', 
          'user_id': 'aFgdAGwPICmxIVno3',    
          'template_params': {
            'leave_name': selectedName,
            'position': displayedPosition, 
            'leave_type': leaveType,
            'start_date': DateFormat('dd/MM/yyyy').format(leaveDateRange!.start),
            'end_date': DateFormat('dd/MM/yyyy').format(leaveDateRange!.end),
            'reason': _reasonController.text.isEmpty ? 'ไม่ได้ระบุ' : _reasonController.text,
          }
        }),
      );
      Navigator.pop(context);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ส่งใบลาสำเร็จแล้ว!')));
        Navigator.pop(context);
      } else { throw 'ส่งไม่สำเร็จ: ${response.body}'; }
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
            Text('แบบฟอร์มแจ้งลาหยุด', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
          ],
        ), 
        backgroundColor: Colors.orange[800], 
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 80,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👤 เลือกชื่อพนักงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              items: getAllNames().map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
              onChanged: (val) => setState(() { selectedName = val; displayedPosition = findPosition(val!); }),
            ),
            const SizedBox(height: 10),
            Text('ตำแหน่ง: $displayedPosition', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            const Text('📌 ประเภทการลา', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              items: leaveTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() => leaveType = val),
            ),
            const SizedBox(height: 25),
            const Text('📅 ช่วงวันที่ต้องการลาหยุด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), side: BorderSide(color: Colors.orange[800]!, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  final r = await showDateRangePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 7)), lastDate: DateTime(2030));
                  if (r != null) setState(() => leaveDateRange = r);
                },
                icon: Icon(Icons.calendar_today, color: Colors.orange[800]),
                label: Text(leaveDateRange == null ? 'กดเพื่อเลือกวันที่ เริ่ม - จบ' : '${DateFormat('dd/MM/yyyy').format(leaveDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(leaveDateRange!.end)}', style: TextStyle(fontSize: 16, color: Colors.orange[800], fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 25),
            const Text('📝 เหตุผลการลา / รายละเอียดเพิ่มเติม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(controller: _reasonController, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'ระบุรายละเอียดเพิ่มเติม', filled: true, fillColor: Colors.white)),
            const SizedBox(height: 45),
            SizedBox(width: double.infinity, height: 65, child: ElevatedButton(onPressed: sendLeaveEmail, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 6), child: const Text('ส่งข้อมูลการลาหยุดงาน', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100], 
    );
  }
}