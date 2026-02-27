import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'work_form.dart';
import 'leave_form.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: LoginPage()));
}

// --- LoginPage ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _signIn() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) { Navigator.pop(context); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage())); }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("อีเมลหรือรหัสผ่านไม่ถูกต้อง"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(children: [
            Icon(Icons.lock_person_rounded, size: 80, color: Colors.indigo[900]),
            const SizedBox(height: 10),
            Text("IDPASSGLOBAL", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.indigo[900])),
            const SizedBox(height: 40),
            TextField(controller: _emailController, decoration: InputDecoration(labelText: "อีเมล", prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 15),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: "รหัสผ่าน", prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))), obscureText: true),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _signIn,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.indigo[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text("เข้าสู่ระบบ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterProfilePage())), child: const Text("สมัครสมาชิกใหม่ที่นี่")),
          ]),
        ),
      ),
    );
  }
}

// --- RegisterProfilePage ---
class RegisterProfilePage extends StatefulWidget {
  const RegisterProfilePage({super.key});
  @override
  State<RegisterProfilePage> createState() => _RegisterProfilePageState();
}

class _RegisterProfilePageState extends State<RegisterProfilePage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedPosition;
  final List<String> _positions = ['Project Manager', 'Dev Lead', 'Tester Lead', 'Programmer', 'Software Analyst', 'Software Tester', 'Junior Programmer'];

  Future<void> _registerNow() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty || _selectedPosition == null) return;
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(), 'email': _emailController.text.trim(), 'position': _selectedPosition, 'role': 'employee', 'createdAt': DateTime.now(),
      });
      if (mounted) { Navigator.pop(context); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomePage()), (route) => false); }
    } catch (e) { Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("สมัครสมาชิก"), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white, centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "ชื่อ-นามสกุลจริง", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "ตำแหน่งงาน", border: OutlineInputBorder()),
            value: _selectedPosition,
            items: _positions.map((pos) => DropdownMenuItem(value: pos, child: Text(pos))).toList(),
            onChanged: (val) => setState(() => _selectedPosition = val),
          ),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: _registerNow, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.green[700]), child: const Text("ยืนยันสมัครสมาชิก", style: TextStyle(color: Colors.white, fontSize: 18))),
        ]),
      ),
    );
  }
}

// --- HomePage ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userRole = 'employee', userName = '...', userPosition = '...';
  bool isChecking = true;

  @override
  void initState() { super.initState(); _checkRole(); }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) setState(() {
        userRole = doc.data()?['role'] ?? 'employee';
        userName = doc.data()?['name'] ?? 'ไม่ระบุชื่อ';
        userPosition = doc.data()?['position'] ?? 'ไม่ระบุตำแหน่ง';
        isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isChecking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('IDPASSGLOBAL'), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white, centerTitle: true, actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut().then((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()))))
      ]),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(color: Colors.indigo[900], borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
            child: Row(children: [
              const CircleAvatar(radius: 35, backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Colors.indigo)),
              const SizedBox(width: 20),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(userPosition, style: TextStyle(color: Colors.indigo[100], fontSize: 14)),
              ])
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(children: [
                if (userRole == 'employee') ...[
                  _menuBtn(context, 'แจ้งงานนอกสถานที่', Icons.add_location_alt_rounded, Colors.blue[800]!, const WorkRequestForm(isAdminMode: false)),
                  const SizedBox(height: 20),
                  _menuBtn(context, 'แจ้งลาหยุดงาน', Icons.event_available_rounded, Colors.orange[800]!, const LeaveRequestForm(isAdminMode: false)),
                ] else ...[
                  _menuBtn(context, 'ดูรายงานทั้งหมด', Icons.analytics_rounded, Colors.purple[800]!, const AdminViewWorkPage()),
                  const SizedBox(height: 20),
                  _menuBtn(context, 'ลงงานแทนพนักงาน', Icons.hail_rounded, Colors.indigo[800]!, const WorkRequestForm(isAdminMode: true)),
                  const SizedBox(height: 20),
                  _menuBtn(context, 'แจ้งลาแทนพนักงาน', Icons.person_off_rounded, Colors.red[800]!, const LeaveRequestForm(isAdminMode: true)),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuBtn(BuildContext context, String txt, IconData ic, Color col, Widget pg) {
    return SizedBox(width: double.infinity, height: 75, child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: col, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 5),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => pg)),
      icon: Icon(ic, color: Colors.white, size: 28), label: Text(txt, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    ));
  }
}

// --- แก้ไขเฉพาะหน้า AdminViewWorkPage ---
class AdminViewWorkPage extends StatelessWidget {
  const AdminViewWorkPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("รายการแจ้งงานทั้งหมด"), backgroundColor: Colors.purple[800], foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('work_requests').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("เกิดข้อผิดพลาด: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("ยังไม่มีข้อมูลการแจ้งงาน"));

          return ListView.builder(
            itemCount: docs.length, 
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)), 
                  title: Text("${data['name'] ?? 'ไม่ระบุชื่อ'}", style: const TextStyle(fontWeight: FontWeight.bold)), 
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ตำแหน่ง: ${data['position'] ?? '-'}"),
                      Text("สถานที่: ${data['location'] ?? '-'}"),
                      Text("เวลาทำงาน: ${data['total_hours'] ?? '0'} ชม."),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            }
          );
        },
      ),
    );
  }
}