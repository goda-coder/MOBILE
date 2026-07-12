class FraudCheckResult {
  final bool isFraud;
  final String riskLevel;
  final double probability;
  final List<FraudReason> reasons;

  FraudCheckResult({
    required this.isFraud,
    required this.riskLevel,
    required this.probability,
    required this.reasons,
  });

  factory FraudCheckResult.fromJson(Map<String, dynamic> j) => FraudCheckResult(
        isFraud: (j['isFraud'] ?? false) as bool,
        riskLevel: (j['riskLevel'] ?? 'LOW').toString(),
        probability: ((j['probability'] ?? 0) as num).toDouble(),
        reasons: ((j['reasons'] ?? []) as List)
            .cast<Map<String, dynamic>>()
            .map(FraudReason.fromJson)
            .toList(growable: false),
      );
}

class FraudReason {
  final String code;
  final String text;

  FraudReason({required this.code, required this.text});

  factory FraudReason.fromJson(Map<String, dynamic> j) => FraudReason(
        code: (j['code'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
      );
}
