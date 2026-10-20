import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('device loader resolves the first supported locale in the dispatcher preference list', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[Locale('fr'), Locale('pt', 'BR')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    final AppLocalizations messages = await loadDeviceAppLocalizations();

    expect(messages.localeName, 'pt_BR');
    expect(messages.actionRetry, 'Tentar novamente');
  });

  testWidgets('device loader resolves to English when every preferred locale is unsupported', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[Locale('fr', 'CA'), Locale('ja', 'JP')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    final AppLocalizations messages = await loadDeviceAppLocalizations();

    expect(messages.localeName, 'en');
    expect(messages.actionRetry, 'Try again');
  });

  testWidgets('device loader returns Portuguese for pt-BR purchase status messages', (WidgetTester tester) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[Locale('pt', 'BR')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    final AppLocalizations messages = await loadDeviceAppLocalizations();

    expect(messages.localeName, 'pt_BR');
    expect(messages.premiumPurchasePending, 'Sua compra foi salva. O Pro pode levar um minuto para ser ativado.');
    expect(
      messages.premiumPurchaseUnconfirmed,
      'Não foi possível confirmar sua compra. Tente usar Restaurar compras nas Configurações.',
    );
  });
}
