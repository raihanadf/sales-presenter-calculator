import 'package:intl/intl.dart';

// rupiah formatter shared across screens. e.g. 825200 -> "Rp 825.200".
final _rp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

String rupiah(int value) => _rp.format(value);

String today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

String thisMonth() => DateFormat('yyyy-MM').format(DateTime.now());
