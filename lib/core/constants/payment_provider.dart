/// Egypt-first payment rails. The parent pays; the student never does.
///
/// Until a provider is wired, records stay provider-neutral and an admin
/// confirms the payment (see docs/REQUIREMENTS.md D-2).
enum PaymentProvider {
  instapay,
  vodafoneCash,
  orangeCash,
  etisalatCash,
  manual;

  static PaymentProvider? tryParse(String? value) {
    for (final provider in PaymentProvider.values) {
      if (provider.name == value) return provider;
    }
    return null;
  }
}
