import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Track selected plan (default to monthly)
  int _selectedPlanIndex = 1;

  // Controller for the activation code
  final _codeController = TextEditingController();
  bool _isVerifying = false;

  final List<Map<String, dynamic>> _plans = [
    {
      'title': 'Weekly',
      'price': 'KSh 50',
      'period': '/ week',
      'description': 'Perfect for testing the waters.',
      'isPopular': false,
    },
    {
      'title': 'Monthly',
      'price': 'KSh 180',
      'period': '/ month',
      'description': 'The standard choice for growing shops.',
      'isPopular': true,
    },
    {
      'title': 'Yearly',
      'price': 'KSh 1,944',
      'period': '/ year',
      'originalPrice': 'KSh 2,160',
      'description': 'Save 10% and get 2 months free.',
      'isPopular': false,
    },
  ];

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an activation code')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    // Simulate network delay for verification
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isVerifying = false);

    // Mock success logic
    // In production, this would hit your backend / M-Pesa verification endpoint
    if (code.startsWith('CRFT-')) {
      _codeController.clear();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.heroGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.brightGreen),
              SizedBox(width: 8),
              Text('Activated!', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'Your subscription has been successfully activated. Enjoy full access to Craft POS.',
            style: TextStyle(color: AppTheme.onHeroSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: AppTheme.brightGreen)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid code. Please check and try again.'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════════════════════════
            // CURRENT SUBSCRIPTION CARD
            // ═══════════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.heroGreen,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.heroGreen.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CURRENT PLAN',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onHeroMuted,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.brightGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'DEMO MODE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.inkBlack,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Free Trial',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You have limited access to core features. Upgrade to unlock unlimited sales, cloud backup, and advanced reporting.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.onHeroSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select a plan below to upgrade.'),
                            backgroundColor: AppTheme.heroGreen,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        'Upgrade Now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ═══════════════════════════════════════════════════════════
            // PLAN SELECTION
            // ═══════════════════════════════════════════════════════════
            const Text(
              'Choose your plan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkBlack,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upgrade to unlock unlimited stock management, advanced reports, and cloud backups.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.onLightMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            ..._plans.asMap().entries.map((entry) {
              final index = entry.key;
              final plan = entry.value;
              final isSelected = _selectedPlanIndex == index;
              final isPopular = plan['isPopular'] as bool;

              return GestureDetector(
                onTap: () => setState(() => _selectedPlanIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.heroGreen : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.heroGreen
                          : AppTheme.inkBlack.withValues(alpha: 0.08),
                      width: isSelected ? 0 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: AppTheme.heroGreen.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                        : [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPopular) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.brightGreen,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'MOST POPULAR',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.inkBlack,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            plan['title'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.inkBlack,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (plan['originalPrice'] != null)
                                Text(
                                  plan['originalPrice'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? AppTheme.onHeroMuted
                                        : AppTheme.onLightMuted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    plan['price'],
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.inkBlack,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    plan['period'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? AppTheme.onHeroMuted
                                          : AppTheme.onLightMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plan['description'],
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? AppTheme.onHeroSecondary
                              : AppTheme.onLightMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Subscribe Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Proceeding to pay for ${_plans[_selectedPlanIndex]['title']} plan...'),
                      backgroundColor: AppTheme.heroGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brightGreen,
                  foregroundColor: AppTheme.inkBlack,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'Subscribe to ${_plans[_selectedPlanIndex]['title']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ═══════════════════════════════════════════════════════════
            // ⭐ VERIFICATION CODE SECTION
            // ═══════════════════════════════════════════════════════════
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFE8F7EE))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onLightMuted,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFE8F7EE))),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Already have a code?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkBlack,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'If you paid via M-Pesa or bought an activation card, enter the code below.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.onLightMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Code Input and Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'CRFT-XXXX-XXXX',
                      filled: true,
                      fillColor: AppTheme.softMint,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 54, // Match text field height
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.inkBlack,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Verify',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'Safe and secure payment via M-Pesa',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onLightMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}