// lib/core/models/subscription_plan.dart

class SubscriptionPlan {
  final String id;          // weekly | monthly | yearly
  final String title;
  final int amountKes;
  final String priceLabel;
  final String period;
  final String? originalPriceLabel;
  final String description;
  final bool isPopular;

  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.amountKes,
    required this.priceLabel,
    required this.period,
    required this.description,
    this.originalPriceLabel,
    this.isPopular = false,
  });

  static const all = <SubscriptionPlan>[
    SubscriptionPlan(
      id: 'weekly',
      title: 'Weekly',
      amountKes: 50,
      priceLabel: 'KSh 50',
      period: '/ week',
      description: 'Perfect for testing the waters.',
    ),
    SubscriptionPlan(
      id: 'monthly',
      title: 'Monthly',
      amountKes: 180,
      priceLabel: 'KSh 180',
      period: '/ month',
      description: 'The standard choice for growing shops.',
      isPopular: true,
    ),
    SubscriptionPlan(
      id: 'yearly',
      title: 'Yearly',
      amountKes: 1944,
      priceLabel: 'KSh 1,944',
      period: '/ year',
      originalPriceLabel: 'KSh 2,160',
      description: 'Save 10% and get 2 months free.',
    ),
  ];

  static SubscriptionPlan byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all[1]);
}