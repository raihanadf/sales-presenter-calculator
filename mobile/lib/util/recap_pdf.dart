import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../api/models.dart';

const _months = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

// "2026-07" -> "Juli 2026".
String monthLabel(String month) {
  final parts = month.split('-');
  final m = int.tryParse(parts.last) ?? 1;
  return '${_months[(m - 1).clamp(0, 11)]} ${parts.first}';
}

// "825200" -> "825.200".
String _grouped(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

// "2026-07-26" -> "26/07".
String _shortDate(String iso) {
  final p = iso.split('-');
  return '${p[2]}/${p[1]}';
}

// monthly recap laid out like the manual ledger: dates down the side,
// presenters across the top, take-home in each cell, totals on the edges.
Future<Uint8List> buildRecapPdf(String month, List<SalesEntry> entries) async {
  final presenters = <int, String>{};
  for (final e in entries) {
    presenters[e.presenterId] = e.presenterName ?? 'Presenter ${e.presenterId}';
  }
  final ids = presenters.keys.toList()
    ..sort((a, b) =>
        presenters[a]!.toLowerCase().compareTo(presenters[b]!.toLowerCase()));
  final dates = entries.map((e) => e.entryDate).toSet().toList()..sort();

  final matrix = <String, Map<int, int>>{};
  final perPresenter = {for (final id in ids) id: 0};
  for (final e in entries) {
    final row = matrix.putIfAbsent(e.entryDate, () => {});
    row[e.presenterId] = (row[e.presenterId] ?? 0) + e.computed.takeHome;
    perPresenter[e.presenterId] =
        perPresenter[e.presenterId]! + e.computed.takeHome;
  }
  final grand = perPresenter.values.fold<int>(0, (a, b) => a + b);

  final doc = pw.Document();
  final landscape = ids.length > 3;

  pw.Widget headerCell(String text,
          {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      );

  pw.Widget cell(String text,
          {pw.Alignment align = pw.Alignment.centerRight, bool bold = false}) =>
      pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  final tableHeader = pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEDEDED)),
    children: [
      headerCell('Tgl'),
      for (final id in ids)
        headerCell(presenters[id]!, align: pw.Alignment.centerRight),
    ],
  );

  final bodyRows = <pw.TableRow>[];
  for (final date in dates) {
    bodyRows.add(pw.TableRow(children: [
      cell(_shortDate(date), align: pw.Alignment.centerLeft, bold: true),
      for (final id in ids)
        cell(matrix[date]?[id] == null ? '-' : _grouped(matrix[date]![id]!)),
    ]));
  }
  final totalRow = pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
    children: [
      cell('Total', align: pw.Alignment.centerLeft, bold: true),
      for (final id in ids) cell(_grouped(perPresenter[id]!), bold: true),
    ],
  );

  doc.addPage(pw.MultiPage(
    pageFormat:
        (landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4).copyWith(
      marginTop: 28,
      marginBottom: 28,
      marginLeft: 28,
      marginRight: 28,
    ),
    build: (context) => [
      pw.Text('Rekap Bulanan',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(monthLabel(month),
          style: const pw.TextStyle(
              fontSize: 12, color: PdfColor.fromInt(0xFF666666))),
      pw.SizedBox(height: 16),
      pw.Table(
        border: pw.TableBorder.all(
            color: const PdfColor.fromInt(0xFFCCCCCC), width: 0.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(52),
          for (var i = 0; i < ids.length; i++)
            i + 1: const pw.FlexColumnWidth(),
        },
        children: [tableHeader, ...bodyRows, totalRow],
      ),
      pw.SizedBox(height: 20),
      pw.Text('Hasil ${monthLabel(month)}',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(
            color: const PdfColor.fromInt(0xFFCCCCCC), width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(),
          1: const pw.FixedColumnWidth(140)
        },
        children: [
          for (final id in ids)
            pw.TableRow(children: [
              cell(presenters[id]!, align: pw.Alignment.centerLeft),
              cell('Rp ${_grouped(perPresenter[id]!)}'),
            ]),
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEDEDED)),
            children: [
              cell('Total keseluruhan',
                  align: pw.Alignment.centerLeft, bold: true),
              cell('Rp ${_grouped(grand)}', bold: true),
            ],
          ),
        ],
      ),
    ],
  ));

  return doc.save();
}
