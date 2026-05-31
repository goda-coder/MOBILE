// Auth -----------------------------------------------------------------

enum Role { customer, merchant, admin }

Role parseRole(String s) => switch (s) {
      'Admin'    => Role.admin,
      'Merchant' => Role.merchant,
      _          => Role.customer,
    };

class LoginResponse {
  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.email,
    required this.userId,
  });
  final String accessToken;
  final String refreshToken;
  final Role role;
  final String email;
  final String userId;

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        role: parseRole((j['role'] ?? 'Customer').toString()),
        email: (j['email'] ?? '').toString(),
        userId: (j['userId'] ?? '').toString(),
      );
}

// Wallet ---------------------------------------------------------------

class WalletSummary {
  WalletSummary({
    required this.walletId,
    required this.balanceMinor,
    required this.currency,
    required this.isKycVerified,
    required this.kycStatus,
  });
  final String walletId;
  final int balanceMinor;
  final String currency;
  final bool isKycVerified;
  final String kycStatus;

  factory WalletSummary.fromJson(Map<String, dynamic> j) => WalletSummary(
        walletId: (j['walletId'] ?? '').toString(),
        balanceMinor: (j['balanceMinor'] ?? 0) as int,
        currency: (j['currency'] ?? 'EGP').toString(),
        isKycVerified: (j['isKycVerified'] ?? false) as bool,
        kycStatus: (j['kycStatus'] ?? 'None').toString(),
      );
}

enum TxKind { transferIn, transferOut, topup, refund, fee, unknown }

TxKind parseTxKind(String s) => switch (s) {
      'transfer_in'  => TxKind.transferIn,
      'transfer_out' => TxKind.transferOut,
      'topup'        => TxKind.topup,
      'refund'       => TxKind.refund,
      'fee'          => TxKind.fee,
      _              => TxKind.unknown,
    };

class WalletTransaction {
  WalletTransaction({
    required this.id,
    required this.kind,
    required this.amountMinor,
    required this.currency,
    required this.createdAt,
    required this.status,
    this.description,
    this.reference,
    this.counterparty,
  });
  final String id;
  final TxKind kind;
  final int amountMinor;
  final String currency;
  final DateTime createdAt;
  final String status;
  final String? description;
  final String? reference;
  final String? counterparty;

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
        id: (j['id'] ?? '').toString(),
        kind: parseTxKind((j['kind'] ?? '').toString()),
        amountMinor: (j['amountMinor'] ?? 0) as int,
        currency: (j['currency'] ?? 'EGP').toString(),
        createdAt: DateTime.parse((j['createdAt'] ?? DateTime.now().toIso8601String()) as String),
        status: (j['status'] ?? 'Completed').toString(),
        description: j['description'] as String?,
        reference: j['reference'] as String?,
        counterparty: j['counterparty'] as String?,
      );
}

class TransferResponse {
  TransferResponse(this.transactionId, this.newBalanceMinor);
  final String transactionId;
  final int newBalanceMinor;

  factory TransferResponse.fromJson(Map<String, dynamic> j) => TransferResponse(
        (j['transactionId'] ?? '').toString(),
        (j['newBalanceMinor'] ?? 0) as int,
      );
}

class AccountOperation {
  AccountOperation({
    required this.id,
    required this.kind,
    required this.amountMinor,
    required this.currency,
    required this.createdAt,
    required this.description,
    required this.reference,
    required this.status,
  });

  final String id;
  final TxKind kind;
  final int amountMinor;
  final String currency;
  final DateTime createdAt;
  final String description;
  final String reference;
  final String status;

  factory AccountOperation.fromJson(Map<String, dynamic> j) => AccountOperation(
        id: (j['id'] ?? '').toString(),
        kind: parseTxKind((j['kind'] ?? '').toString()),
        amountMinor: (j['amountMinor'] ?? 0) as int,
        currency: (j['currency'] ?? 'EGP').toString(),
        createdAt: DateTime.parse((j['createdAt'] ?? DateTime.now().toIso8601String()) as String),
        description: (j['description'] ?? '').toString(),
        reference: (j['reference'] ?? '').toString(),
        status: (j['status'] ?? 'Completed').toString(),
      );
}

class AccountReport {
  AccountReport({required this.wallet, required this.operations});

  final WalletSummary wallet;
  final List<AccountOperation> operations;

  factory AccountReport.fromJson(Map<String, dynamic> j) => AccountReport(
        wallet: WalletSummary.fromJson(j['wallet'] as Map<String, dynamic>),
        operations: (j['operations'] as List).cast<Map<String, dynamic>>()
            .map(AccountOperation.fromJson)
            .toList(growable: false),
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.userId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String senderId;
  final String senderRole;
  final String content;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] ?? '').toString(),
        userId: (j['userId'] ?? '').toString(),
        senderId: (j['senderId'] ?? '').toString(),
        senderRole: (j['senderRole'] ?? '').toString(),
        content: (j['content'] ?? '').toString(),
        createdAt: DateTime.parse((j['createdAt'] ?? DateTime.now().toIso8601String()) as String),
      );
}

class ChatConversationSummary {
  ChatConversationSummary({
    required this.userId,
    required this.lastMessage,
    required this.messageCount,
  });

  final String userId;
  final ChatMessage lastMessage;
  final int messageCount;

  factory ChatConversationSummary.fromJson(Map<String, dynamic> j) => ChatConversationSummary(
        userId: (j['userId'] ?? '').toString(),
        lastMessage: ChatMessage.fromJson(j['lastMessage'] as Map<String, dynamic>),
        messageCount: (j['messageCount'] ?? 0) as int,
      );
}

// KYC ------------------------------------------------------------------

class KycStatusResponse {
  KycStatusResponse({
    required this.isVerified,
    required this.status,
    this.matchPercentage,
    this.warnings,
    this.submittedAt,
    this.decidedAt,
    this.decisionReason,
  });
  final bool isVerified;
  final String status;
  final double? matchPercentage;
  final List<String>? warnings;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String? decisionReason;

  factory KycStatusResponse.fromJson(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    return KycStatusResponse(
      isVerified: (j['isVerified'] ?? false) as bool,
      status: (j['status'] ?? 'None').toString(),
      matchPercentage: (j['matchPercentage'] as num?)?.toDouble(),
      warnings: (j['warnings'] as List?)?.cast<String>(),
      submittedAt: parse(j['submittedAt']),
      decidedAt: parse(j['decidedAt']),
      decisionReason: j['decisionReason'] as String?,
    );
  }
}

class KycSubmitResponse {
  KycSubmitResponse({
    required this.kycRequestId,
    required this.status,
    required this.matchPercentage,
    required this.spoofScore,
    required this.ocrConfidence,
    this.warnings,
  });
  final String kycRequestId;
  final String status;
  final double matchPercentage;
  final double spoofScore;
  final double ocrConfidence;
  final List<String>? warnings;

  factory KycSubmitResponse.fromJson(Map<String, dynamic> j) => KycSubmitResponse(
        kycRequestId: (j['kycRequestId'] ?? '').toString(),
        status: (j['status'] ?? 'Submitted').toString(),
        matchPercentage: ((j['matchPercentage'] ?? 0) as num).toDouble(),
        spoofScore: ((j['spoofScore'] ?? 0) as num).toDouble(),
        ocrConfidence: ((j['ocrConfidence'] ?? 0) as num).toDouble(),
        warnings: (j['warnings'] as List?)?.cast<String>(),
      );
}

class LivenessChallenge {
  LivenessChallenge(this.challengeId, this.action, this.ttlSeconds);
  final String challengeId;
  final String action;
  final int ttlSeconds;

  factory LivenessChallenge.fromJson(Map<String, dynamic> j) => LivenessChallenge(
        (j['challengeId'] ?? '').toString(),
        (j['action'] ?? 'blink').toString(),
        (j['ttlSeconds'] ?? 90) as int,
      );
}

class LivenessVerifyResponse {
  LivenessVerifyResponse(this.passed, this.confidence, this.reason);
  final bool passed;
  final double confidence;
  final String? reason;

  factory LivenessVerifyResponse.fromJson(Map<String, dynamic> j) => LivenessVerifyResponse(
        (j['passed'] ?? false) as bool,
        ((j['confidence'] ?? 0) as num).toDouble(),
        j['reason'] as String?,
      );
}

class PendingKycSummary {
  PendingKycSummary({
    required this.id,
    required this.userId,
    required this.matchPercentage,
    required this.submittedAt,
    required this.warnings,
    this.fullName,
  });
  final String id;
  final String userId;
  final String? fullName;
  final double matchPercentage;
  final DateTime submittedAt;
  final List<String> warnings;

  factory PendingKycSummary.fromJson(Map<String, dynamic> j) => PendingKycSummary(
        id: (j['id'] ?? '').toString(),
        userId: (j['userId'] ?? '').toString(),
        fullName: j['fullName'] as String?,
        matchPercentage: ((j['matchPercentage'] ?? 0) as num).toDouble(),
        submittedAt: DateTime.parse((j['submittedAt'] ?? DateTime.now().toIso8601String()) as String),
        warnings: ((j['warnings'] ?? []) as List).cast<String>(),
      );
}

// Payments -------------------------------------------------------------

class CheckoutResponse {
  CheckoutResponse({
    required this.paymentIntentId,
    required this.orderReference,
    this.iframeUrl,
    this.walletRedirectUrl,
    this.paymentDevice,
    this.paymentNote,
    this.deviceAuthRequired = false,
  });
  final String paymentIntentId;
  final String orderReference;
  final String? iframeUrl;
  final String? walletRedirectUrl;
  final String? paymentDevice;
  final String? paymentNote;
  final bool deviceAuthRequired;

  factory CheckoutResponse.fromJson(Map<String, dynamic> j) => CheckoutResponse(
        paymentIntentId: (j['paymentIntentId'] ?? '').toString(),
        orderReference: (j['orderReference'] ?? '').toString(),
        iframeUrl: j['iframeUrl'] as String?,
        walletRedirectUrl: j['walletRedirectUrl'] as String?,
        paymentDevice: j['paymentDevice'] as String?,
        paymentNote: j['paymentNote'] as String?,
        deviceAuthRequired: (j['deviceAuthRequired'] ?? false) as bool,
      );
}

class PaymentIntentStatusResponse {
  PaymentIntentStatusResponse({
    required this.paymentIntentId,
    required this.orderReference,
    required this.method,
    required this.status,
    required this.deviceAuthRequired,
    this.paymentDevice,
    this.paymentNote,
  });

  final String paymentIntentId;
  final String orderReference;
  final String method;
  final String status;
  final bool deviceAuthRequired;
  final String? paymentDevice;
  final String? paymentNote;

  factory PaymentIntentStatusResponse.fromJson(Map<String, dynamic> j) => PaymentIntentStatusResponse(
        paymentIntentId: (j['paymentIntentId'] ?? '').toString(),
        orderReference: (j['orderReference'] ?? '').toString(),
        method: (j['method'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        deviceAuthRequired: (j['deviceAuthRequired'] ?? false) as bool,
        paymentDevice: j['paymentDevice'] as String?,
        paymentNote: j['paymentNote'] as String?,
      );
}
