import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../api/models.dart';

// one parsed, validated row ready to send to the bulk import endpoint.
class ImportRow {
  final String entryDate;
  final int closingCount;
  final int bopInput;
  final int audienceCount;
  final int? harian;

  ImportRow({
    required this.entryDate,
    required this.closingCount,
    required this.bopInput,
    required this.audienceCount,
    required this.harian,
  });

  Map<String, dynamic> toJson() => {
        'entryDate': entryDate,
        'closingCount': closingCount,
        'bopInput': bopInput,
        'audienceCount': audienceCount,
        if (harian != null) 'harian': harian,
      };
}

class ImportResult {
  final List<ImportRow> rows;
  final List<String> errors;
  ImportResult(this.rows, this.errors);
}

const _headers = [
  'Tanggal (YYYY-MM-DD)',
  'Jumlah Closing',
  'BOP',
  'Jumlah Audiens',
  'Potongan Harian (opsional)',
];

final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

// builds an xlsx the admin fills in. the top block echoes the current settings
// so they know which numbers drive the calculation, then the header row.
Uint8List buildImportTemplate(Settings s) {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];

  void row(List<CellValue?> cells) => sheet.appendRow(cells);
  CellValue t(String v) => TextCellValue(v);

  row([t('Template Import Closing')]);
  row([t('Nilai perhitungan saat ini:')]);
  row([t('Harga closing'), IntCellValue(s.closingPrice)]);
  row([t('BOP %'), IntCellValue(s.bopPercent)]);
  row([t('Harga souvenir / audiens'), IntCellValue(s.souvenirUnitPrice)]);
  row([t('Souvenir %'), IntCellValue(s.souvenirPercent)]);
  row([t('Potongan harian default'), IntCellValue(s.harianDefault)]);
  row([t('Kosongkan kolom Potongan Harian untuk memakai nilai default.')]);
  row([t('Contoh tanggal: 2026-07-26')]);
  row([]);
  row(_headers.map(t).toList());

  return Uint8List.fromList(excel.encode()!);
}

// reads the filled xlsx. any row whose first cell is a yyyy-mm-dd date is
// treated as data; header and note rows are ignored. rows that look like data
// but hold bad numbers are collected as human-readable errors.
ImportResult parseImport(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final rows = <ImportRow>[];
  final errors = <String>[];
  if (excel.tables.isEmpty) return ImportResult(rows, ['File kosong.']);

  final sheet = excel.tables[excel.tables.keys.first]!;
  for (final line in sheet.rows) {
    if (line.isEmpty) continue;
    final date = _text(line[0]).trim();
    if (!_dateRe.hasMatch(date)) continue;

    final closing = _int(_cell(line, 1));
    final bop = _int(_cell(line, 2));
    final audience = _int(_cell(line, 3));
    final harianText = _text(_cell(line, 4)).trim();
    final harian = harianText.isEmpty ? null : _int(_cell(line, 4));

    if (closing == null ||
        bop == null ||
        audience == null ||
        (harianText.isNotEmpty && harian == null)) {
      errors.add('Baris $date: angka tidak valid, dilewati.');
      continue;
    }
    rows.add(ImportRow(
      entryDate: date,
      closingCount: closing,
      bopInput: bop,
      audienceCount: audience,
      harian: harian,
    ));
  }
  if (rows.isEmpty && errors.isEmpty) {
    errors.add('Tidak ada baris tanggal yang ditemukan.');
  }
  return ImportResult(rows, errors);
}

Data? _cell(List<Data?> line, int i) => i < line.length ? line[i] : null;

String _text(Data? cell) {
  final v = cell?.value;
  return v == null ? '' : v.toString();
}

int? _int(Data? cell) {
  final v = cell?.value;
  if (v == null) return null;
  if (v is IntCellValue) return v.value;
  if (v is DoubleCellValue) return v.value.round();
  final digits = v.toString().trim().replaceAll(RegExp(r'[.,\s]'), '');
  return int.tryParse(digits);
}
