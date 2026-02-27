import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequestForm extends StatefulWidget {
  final bool isAdminMode;
  const LeaveRequestForm({super.key, this.isAdminMode = false});
  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  String? selectedEmployeeId, selectedEmployeeName, selectedEmployeePosition, selectedType;
  final TextEditingController _reason = TextEditingController();
  DateTimeRange? selectedRange;

  @override
  void initState() {
    super.initState();
    if (!widget.isAdminMode) _loadUser();
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

  Future<void> _sendEmailJS() async {
    const serviceId = 'service_zxk182e'; 
    const templateId = 'template_cn7r5nd'; 
    const publicKey = 'aFgdAGwPICmxIVno3';

    try {
      await http.post(Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'service_id': serviceId,
            'template_id': templateId,
            'user_id': publicKey,
            'template_params': {
              'leave_name': selectedEmployeeName, // ตรงกับ {{leave_name}} ในรูป
              'leave_type': selectedType,         // ตรงกับ {{leave_type}} ในรูป
              'start_date': selectedRange != null ? DateFormat('dd/MM/yy').format(selectedRange!.start) : '-', // ตรงกับ {{start_date}}
              'end_date': selectedRange != null ? DateFormat('dd/MM/yy').format(selectedRange!.end) : '-',     // ตรงกับ {{end_date}}
              'reason': _reason.text,             // ตรงกับ {{reason}}
              'name': selectedEmployeeName,       // สำหรับ From Name
              'email': FirebaseAuth.instance.currentUser?.email ?? '', // สำหรับ Reply To
            }
          }));
    } catch (e) {
      print("EmailJS Error: $e");
    }
  }

  Future<void> _submit() async {
    if (selectedEmployeeName == null || selectedType == null || selectedRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบถ้วน"), backgroundColor: Colors.orange)
      );
      return;
    }

    // แสดง Loading
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      // 1. บันทึกลง Firebase (ใช้ชื่อฟิลด์ให้ตรงเพื่อให้ Admin ดึงไปโชว์ได้)
      await FirebaseFirestore.instance.collection('leave_requests').add({
        'name': selectedEmployeeName,
        'position': selectedEmployeePosition,
        'type': selectedType,
        'reason': _reason.text,
        'start_date': DateFormat('dd/MM/yy').format(selectedRange!.start),
        'end_date': DateFormat('dd/MM/yy').format(selectedRange!.end),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. ส่ง Email ผ่าน EmailJS
      await _sendEmailJS();

      if (mounted) {
        Navigator.pop(context); // ปิด Loading Indicator

        // 3. แสดงแถบแจ้งเตือนว่าส่งสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("ส่งใบแจ้งลาสำเร็จเรียบร้อยแล้ว!"),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // 4. รอสักครู่แล้วค่อยกลับหน้า Dashboard
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e"), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isAdminMode ? "แจ้งลาแทน" : "แจ้งลาหยุดงาน"),
          backgroundColor: Colors.red[800],
          foregroundColor: Colors.white,
          centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _profileHeader(),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
                labelText: "ประเภทการลา", border: OutlineInputBorder()),
            items: ['ลาป่วย', 'ลากิจ', 'ลาพักร้อน', 'ลาอื่นๆ']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => selectedType = v),
          ),
          const SizedBox(height: 15),
          OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime(2030));
                if (r != null) setState(() => selectedRange = r);
              },
              child: Text(selectedRange == null
                  ? "เลือกวันที่ลา"
                  : "${DateFormat('dd/MM/yy').format(selectedRange!.start)} - ${DateFormat('dd/MM/yy').format(selectedRange!.end)}")),
          const SizedBox(height: 15),
          TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: "เหตุผลการลา", border: OutlineInputBorder())),
          const SizedBox(height: 30),
          ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.red[800],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              child: const Text("ส่งข้อมูลการลา",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold))),
        ]),
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
        Icon(Icons.person_search_rounded, size: 40, color: Colors.red[800]),
        const SizedBox(width: 15),
        Expanded(
            child: widget.isAdminMode
                ? StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(doc['name'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      Text(doc['position'],
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11)),
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
                        Text(selectedEmployeeName ?? "...",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(selectedEmployeePosition ?? "...",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ]))
      ]),
    );
  }
}