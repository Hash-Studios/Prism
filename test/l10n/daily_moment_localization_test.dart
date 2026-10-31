import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <Locale, List<List<String>>>{
    const Locale('en'): [
      ['1 coin earned', 'streak of 1 day', 'Balance: 1 coin', 'Open for 1 coin'],
      ['2 coins earned', 'streak of 2 days', 'Balance: 2 coins', 'Open for 2 coins'],
    ],
    const Locale('de'): [
      ['1 Münze erhalten', '1 Tag in Folge', 'Guthaben: 1 Münze', 'Für 1 Münze öffnen'],
      ['2 Münzen erhalten', '2 Tage in Folge', 'Guthaben: 2 Münzen', 'Für 2 Münzen öffnen'],
    ],
    const Locale('es'): [
      ['1 moneda ganada', 'racha de 1 día', 'Saldo: 1 moneda', 'Abrir por 1 moneda'],
      ['2 monedas ganadas', 'racha de 2 días', 'Saldo: 2 monedas', 'Abrir por 2 monedas'],
    ],
    const Locale('pt'): [
      ['1 moeda recebida', 'sequência de 1 dia', 'Saldo: 1 moeda', 'Abrir por 1 moeda'],
      ['2 moedas recebidas', 'sequência de 2 dias', 'Saldo: 2 moedas', 'Abrir por 2 moedas'],
    ],
    const Locale('pt', 'BR'): [
      ['1 moeda recebida', 'sequência de 1 dia', 'Saldo: 1 moeda', 'Abrir por 1 moeda'],
      ['2 moedas recebidas', 'sequência de 2 dias', 'Saldo: 2 moedas', 'Abrir por 2 moedas'],
    ],
    const Locale('hi'): [
      ['1 सिक्का मिला', '1 दिन की स्ट्रीक', 'शेष: 1 सिक्का', '1 सिक्के में खोलें'],
      ['2 सिक्के मिले', '2 दिनों की स्ट्रीक', 'शेष: 2 सिक्के', '2 सिक्कों में खोलें'],
    ],
    const Locale('id'): [
      ['1 koin diperoleh', 'runtun 1 hari', 'Saldo: 1 koin', 'Buka dengan 1 koin'],
      ['2 koin diperoleh', 'runtun 2 hari', 'Saldo: 2 koin', 'Buka dengan 2 koin'],
    ],
  };

  for (final entry in cases.entries) {
    test('${entry.key} daily moment uses singular and plural rewards', () async {
      final l10n = await loadAppLocalizations(entry.key);
      for (var index = 0; index < entry.value.length; index++) {
        final count = index + 1;
        final expected = entry.value[index];
        expect(l10n.dailyMomentReward(count), expected[0]);
        expect(l10n.dailyMomentBalance(count), expected[2]);
        expect(l10n.dailyMomentOpenChest(count), expected[3]);
        for (var daysIndex = 0; daysIndex < entry.value.length; daysIndex++) {
          expect(l10n.dailyMomentStreakReceipt(count, daysIndex + 1), '${expected[0]} · ${entry.value[daysIndex][1]}');
        }
      }
    });
  }

  test('daily moment keeps established Hindi streak terminology', () async {
    final l10n = await loadAppLocalizations(const Locale('hi'));
    expect(l10n.dailyMomentStreakTitle, 'रोज़ की स्ट्रीक');
    expect(l10n.dailyMomentStreakLeft, 'रोज़ की स्ट्रीक उपलब्ध है');
  });

  test('German cosmetic receipt covers every cosmetic type', () async {
    final l10n = await loadAppLocalizations(const Locale('de'));
    expect(l10n.dailyMomentCosmetic, 'Kosmetischer Gegenstand zu deiner Sammlung hinzugefügt');
  });
}
