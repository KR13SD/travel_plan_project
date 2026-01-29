import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/invite_service.dart';

class JoinPlanPage extends StatefulWidget {
  const JoinPlanPage({super.key});

  @override
  State<JoinPlanPage> createState() => _JoinPlanPageState();
}

class _JoinPlanPageState extends State<JoinPlanPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  final _service = InviteService();

  Future<void> _join() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      Get.snackbar(
        'Error',
        'กรุณากรอกโค้ดเชิญ',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.joinByCode(code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      Get.snackbar(
        'สำเร็จ',
        'เข้าร่วมแผนแล้ว',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[600],
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> onJoinPressed(String inputCode) async {
    try {
      // ถ้าจะเปิดเช็คชนเวลาด้วย เปลี่ยนเป็น true
      await InviteService().joinByCode(
        inputCode,
        checkOverlapWithOwnedPlans: false,
      );

      Get.snackbar(
        'สำเร็จ',
        'เข้าร่วมแผนเรียบร้อย',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
        colorText: Colors.white,
      );

      // ปิดหน้า + ให้ stream อัปเดตเอง
      Get.back();
    } catch (e) {
      final msg = e.toString();
      String human;
      if (msg.contains('เจ้าของแผน')) {
        human = 'คุณเป็นเจ้าของแผนนี้อยู่แล้ว';
      } else if (msg.contains('อยู่ในแผนนี้อยู่แล้ว')) {
        human = 'คุณอยู่ในแผนนี้อยู่แล้ว';
      } else if (msg.contains('หมดอายุ')) {
        human = 'โค้ดเชิญหมดอายุแล้ว';
      } else if (msg.contains('ครบตามจำนวน')) {
        human = 'โค้ดนี้ถูกใช้ครบตามจำนวนแล้ว';
      } else if (msg.contains('ไม่พบแผน')) {
        human = 'ไม่พบแผนปลายทาง';
      } else if (msg.contains('โค้ดเชิญไม่ถูกต้อง')) {
        human = 'โค้ดเชิญไม่ถูกต้อง';
      } else if (msg.contains('ชนกับแผน')) {
        human = 'ช่วงเวลาแผนนี้ชนกับแผนที่คุณเป็นเจ้าของอยู่';
      } else {
        human = 'เข้าร่วมไม่สำเร็จ: $msg';
      }

      Get.snackbar(
        'เกิดข้อผิดพลาด',
        human,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เข้าร่วมแผนด้วยโค้ด')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _join,
                icon: const Icon(Icons.login),
                label: Text(_loading ? 'กำลังเข้าร่วม...' : 'เข้าร่วม'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
