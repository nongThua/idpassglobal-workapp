import 'package:flutter/material.dart';
import 'work_form.dart';
import 'leave_form.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: HomePage()));

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('IDPASSGLOBAL', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('ระบบบริการพนักงาน', style: TextStyle(fontSize: 16)),
          ],
        ), 
        backgroundColor: Colors.indigo[900], 
        foregroundColor: Colors.white, 
        centerTitle: true,
        toolbarHeight: 85, 
      ),
      body: Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _btn(context, 'แจ้งงานนอกสถานที่', Icons.map, Colors.blue[800]!, const WorkRequestForm()),
            const SizedBox(height: 20),
            _btn(context, 'แจ้งลาหยุดงาน', Icons.edit_calendar, Colors.orange[800]!, const LeaveRequestForm()),
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext context, String txt, IconData ic, Color col, Widget pg) {
    return SizedBox(
      width: double.infinity, height: 100,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: col, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => pg)),
        icon: Icon(ic, color: Colors.white, size: 30),
        label: Text(txt, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}