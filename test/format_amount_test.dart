import 'package:flutter_test/flutter_test.dart';
import 'package:org_wallet/screens/dashboard/transactions_screen.dart' as ts;

void main() {
  test('formatAmount shows sign and absolute value', () {
    final a = ts.formatAmount(100.5, false);
    final b = ts.formatAmount(100.5, true);
    expect(a, '+100.50');
    expect(b, '-100.50');
  });
}
