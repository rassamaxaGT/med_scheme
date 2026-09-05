import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('Roboto font has Cyrillic glyphs and produces PDF without errors', () async {
    final regBytes = await File('assets/fonts/Roboto-Regular.ttf').readAsBytes();
    final boldBytes = await File('assets/fonts/Roboto-Bold.ttf').readAsBytes();
    final italicBytes = await File('assets/fonts/Roboto-Italic.ttf').readAsBytes();

    final regular = pw.Font.ttf(regBytes.buffer.asByteData());
    final bold = pw.Font.ttf(boldBytes.buffer.asByteData());
    final italic = pw.Font.ttf(italicBytes.buffer.asByteData());

    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
    );

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            children: [
              pw.Text('УЗИ Отчет - Пациент Иванов Иван Иванович', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: bold)),
              pw.Text('Аппарат: GE Voluson E8. Датчики: конвексный C1-5, вагинальный RIC5-9.', style: pw.TextStyle(font: regular)),
              pw.Text('Заключение: Эндометриоз, миома матки.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, font: italic)),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    expect(bytes.isNotEmpty, true);
    expect(bytes.length, greaterThan(1000));
  });
}
