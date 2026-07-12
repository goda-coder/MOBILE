class TransferData {
  final String recipient;
  final int amountMinor;
  final String amountFormatted;
  final String? description;
  final String idempotencyRef;

  TransferData({
    required this.recipient,
    required this.amountMinor,
    required this.amountFormatted,
    this.description,
    required this.idempotencyRef,
  });
}
