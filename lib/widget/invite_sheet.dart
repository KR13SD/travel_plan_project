import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import '../services/invite_service.dart';

class InviteSheet extends StatefulWidget {
  final String taskId;
  const InviteSheet({super.key, required this.taskId});

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  final _service = InviteService();

  final _formKey = GlobalKey<FormState>();
  String _role = 'viewer'; // 'viewer' | 'editor'
  DateTime? _expiresAt;    // local date only; will be normalized to 23:59:59
  final _maxUsesCtrl = TextEditingController();

  String? _generatedCode;
  bool _loading = false;

  @override
  void dispose() {
    _maxUsesCtrl.dispose();
    super.dispose();
  }

  /// ส่งต่อเป็นสิ้นวัน (23:59:59.999)
  DateTime? _effectiveExpiresAt() {
    if (_expiresAt == null) return null;
    final d = _expiresAt!;
    return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _generatedCode = null; // reset
    });

    try {
      final maxUses = _maxUsesCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_maxUsesCtrl.text.trim());

      final code = await _service.createInviteCode(
        taskId: widget.taskId,
        role: _role, // 'viewer' or 'editor'
        expiresAt: _effectiveExpiresAt(),
        maxUses: maxUses,
      );

      setState(() => _generatedCode = code);
      HapticFeedback.mediumImpact();
      Get.snackbar(
        'สำเร็จ',
        'สร้างโค้ดเชิญเรียบร้อย',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green[600],
        colorText: Colors.white,
      );
    } catch (e) {
      HapticFeedback.heavyImpact();
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[600],
        colorText: Colors.white,
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _copyAndClose() async {
    if (_generatedCode == null) return;
    await Clipboard.setData(ClipboardData(text: _generatedCode!));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(_generatedCode);
    Get.snackbar('คัดลอกแล้ว', 'โค้ดเชิญถูกคัดลอกไปยังคลิปบอร์ด',
        snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + bottomInset,
        ),
        child: Form(
          key: _formKey,
          child: Wrap(
            runSpacing: 12,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              Text('สร้างโค้ดเชิญ', style: Theme.of(context).textTheme.titleLarge),

              // Role
              DropdownButtonFormField<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'viewer', child: Text('ดูได้อย่างเดียว')),
                  DropdownMenuItem(value: 'editor', child: Text('แก้ไขได้')),
                ],
                onChanged: _loading
                    ? null
                    : (v) => setState(() => _role = v ?? 'viewer'),
                decoration: const InputDecoration(
                  labelText: 'สิทธิ์ของผู้เข้าร่วม',
                  helperText: 'viewer = อ่านอย่างเดียว • editor = อ่าน+แก้ไข',
                  border: OutlineInputBorder(),
                ),
              ),

              // Max uses
              TextFormField(
                controller: _maxUsesCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: 'จำกัดจำนวนผู้ใช้โค้ด (เว้นว่าง = ไม่จำกัด)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'กรอกเป็นจำนวนเต็มบวก';
                  return null;
                },
                enabled: !_loading,
              ),

              // Expiry
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickExpiry,
                icon: const Icon(Icons.event),
                label: Text(
                  _expiresAt == null
                      ? 'กำหนดวันหมดอายุ (ไม่บังคับ)'
                      : 'หมดอายุ: ${_expiresAt!.toString().substring(0, 10)} (สิ้นวัน)',
                ),
              ),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _create,
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(_loading ? 'กำลังสร้าง...' : 'สร้างโค้ดเชิญ'),
                ),
              ),

              if (_generatedCode != null) ...[
                const Divider(),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'โค้ดของคุณ',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: SelectableText(
                          _generatedCode!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _expiresAt == null
                            ? 'ไม่มีวันหมดอายุ'
                            : 'ใช้ได้ถึง: ${_expiresAt!.toString().substring(0, 10)} (23:59)',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _role == 'editor'
                            ? 'สิทธิ์ที่แนบกับโค้ด: แก้ไขได้'
                            : 'สิทธิ์ที่แนบกับโค้ด: ดูอย่างเดียว',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _copyAndClose,
                        icon: const Icon(Icons.copy),
                        label: const Text('คัดลอกและปิด'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
