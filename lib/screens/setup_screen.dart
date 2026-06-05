import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/vel_icon.dart';
import 'main_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const Color _green = Color(0xFF10B981);
  static const Color _greenDark = Color(0xFF065F46);

  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int _visibleFields = 1; // start with 1 field, can add up to 3
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    List<String> existing = await StorageService.getEmergencyContacts();
    for (int i = 0; i < existing.length && i < 3; i++) {
      _controllers[i].text = existing[i];
    }
    if (existing.length > 1) {
      setState(() => _visibleFields = existing.length.clamp(1, 3));
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a phone number';
    String cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.length < 10) return 'Enter a valid phone number';
    return null;
  }

  String? _validateOptional(String? value) {
    if (value == null || value.isEmpty) return null; // optional field
    String cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.length < 10) return 'Enter a valid phone number';
    return null;
  }

  Future<void> _saveContacts() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      List<String> numbers = [];
      for (int i = 0; i < _visibleFields; i++) {
        String num = _controllers[i].text.replaceAll(RegExp(r'[^\d+]'), '');
        if (num.length >= 10) numbers.add(num);
      }

      if (numbers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one number')),
        );
        setState(() => _isLoading = false);
        return;
      }

      await StorageService.saveEmergencyContacts(numbers);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_green, _greenDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Vel Icon ──
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const VelIcon(size: 72, color: _green),
                  ),
                  const SizedBox(height: 28),

                  // ── Title ──
                  const Text(
                    'Seyyon',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The Saviour',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.75),
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your emergency contacts',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Form Card ──
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Emergency Contacts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add up to 3 numbers. All will receive SOS alerts.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 20),

                            // ── Phone fields ──
                            for (int i = 0; i < _visibleFields; i++) ...[
                              _phoneField(i),
                              if (i < _visibleFields - 1) const SizedBox(height: 14),
                            ],

                            // ── Add more button ──
                            if (_visibleFields < 3) ...[
                              const SizedBox(height: 14),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() => _visibleFields++);
                                },
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                label: Text('Add contact ${_visibleFields + 1}'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _green,
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // ── Info ──
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: _greenDark, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'All contacts will receive an emergency SMS and call when SOS is triggered.',
                                      style: TextStyle(fontSize: 12, color: _greenDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Save Button ──
                            ElevatedButton(
                              onPressed: _isLoading ? null : _saveContacts,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save & Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _phoneField(int index) {
    return TextFormField(
      controller: _controllers[index],
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        hintText: index == 0 ? 'Primary number *' : 'Contact ${index + 1} (optional)',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(Icons.phone, color: _green.withOpacity(0.7)),
        suffixIcon: index > 0 && index == _visibleFields - 1
            ? IconButton(
                icon: Icon(Icons.remove_circle_outline, color: Colors.grey.shade400),
                onPressed: () {
                  _controllers[index].clear();
                  setState(() => _visibleFields--);
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: index == 0 ? _validatePhoneNumber : _validateOptional,
    );
  }
}
