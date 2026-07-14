/// Returns true when [identifier] refers to the same account as the
/// currently authenticated user, i.e. a self-transfer.
///
/// The comparison is case-insensitive and matches the recipient against the
/// user's known identifiers. The wallet-ID and email edge cases are not
/// covered here (the app does not store them locally) but are caught
/// authoritatively by the backend's SELF_TRANSFER guard.
bool isSelfTransfer(
  String identifier, {
  required String? userId,
  required String? phoneNumber,
}) {
  final id = identifier.trim().toLowerCase();
  if (id.isEmpty) return false;
  return <String?>[userId, phoneNumber]
      .where((c) => c != null && c.isNotEmpty)
      .any((c) => c!.toLowerCase() == id);
}
