import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/vel_icon.dart';
import 'setup_screen.dart';

/// DPDP Act 2023 Compliant Consent Screen
/// Shown on first launch before setup. Clearly explains data collection
/// and obtains explicit consent before proceeding.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  static const Color _green = Color(0xFF10B981);
  static const Color _greenDark = Color(0xFF065F46);

  bool _consentLocation = false;
  bool _consentAlerts = false;
  bool _consentCommunity = false;

  bool get _canProceed => _consentLocation && _consentAlerts;

  Future<void> _acceptConsent() async {
    if (!_canProceed) return;

    await StorageService.saveConsentGiven(true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SetupScreen()),
      );
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
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    padding: const EdgeInsets.all(20),
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
                    child: const VelIcon(size: 56, color: _green),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Seyyon',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your Safety, Our Priority',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Consent Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.privacy_tip, color: _greenDark, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Data & Privacy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2D2D2D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'In compliance with the Digital Personal Data Protection Act, 2023 (DPDP Act)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // What we collect
                          _infoSection(
                            icon: Icons.info_outline,
                            title: 'What we collect',
                            items: [
                              'Your GPS location during SOS alerts',
                              'Emergency contact phone numbers',
                              'Anonymous device identifier',
                              'Check-in timer activity logs',
                            ],
                          ),
                          const SizedBox(height: 16),

                          _infoSection(
                            icon: Icons.shield_outlined,
                            title: 'How we use it',
                            items: [
                              'Send emergency alerts to your contacts',
                              'Build community safety maps (anonymized)',
                              'Auto-delete all data after 90 days',
                              'Never sold to third parties',
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Consent checkboxes
                          _consentCheckbox(
                            value: _consentLocation,
                            required: true,
                            label: 'I consent to location data collection for emergency alerts',
                            onChanged: (v) => setState(() => _consentLocation = v ?? false),
                          ),
                          _consentCheckbox(
                            value: _consentAlerts,
                            required: true,
                            label: 'I consent to SOS alert data being stored for safety mapping',
                            onChanged: (v) => setState(() => _consentAlerts = v ?? false),
                          ),
                          _consentCheckbox(
                            value: _consentCommunity,
                            required: false,
                            label: 'I want to contribute to community safety reports (optional)',
                            onChanged: (v) => setState(() => _consentCommunity = v ?? false),
                          ),

                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.blue.shade700, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You can delete all your data anytime from Settings.',
                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Accept button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _canProceed ? _acceptConsent : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'I Agree — Continue',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
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

  Widget _infoSection({
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _greenDark, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _consentCheckbox({
    required bool value,
    required bool required,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: _green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                children: required
                    ? [
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
