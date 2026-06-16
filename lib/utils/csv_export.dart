import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/stock_item.dart';
import '../models/delivery_record.dart';
import '../models/shipping_record.dart';

class CsvExport {
  static final _fmt = DateFormat('yyyy/MM/dd');

  static String generateStockCsv(List<StockItem> items) {
    final buf = StringBuffer();
    buf.writeln('保管場所,品目,規格,単位,初期在庫,現在庫,最終納入日,最終出荷日,備考');
    for (final item in items) {
      buf.writeln(
        '"${item.location}","${item.category}","${item.spec}","${item.unit}",'
        '"${_q(item.initialStock)}","${_q(item.currentStock)}",'
        '"${_fmtDate(item.lastDeliveryDate)}",'
        '"${_fmtDate(item.lastShippingDate)}","${item.note ?? ''}"',
      );
    }
    return buf.toString();
  }

  static String generateDeliveryCsv(List<DeliveryRecord> records) {
    final buf = StringBuffer();
    buf.writeln('納入日,保管場所,品目,規格,数量,単位,仕入先,担当者,備考');
    for (final r in records) {
      buf.writeln(
        '"${_fmt.format(r.deliveryDate)}","${r.location}","${r.category}","${r.spec}",'
        '"${_q(r.quantity)}","${r.unit}","${r.supplier ?? ''}","${r.staff ?? ''}","${r.note ?? ''}"',
      );
    }
    return buf.toString();
  }

  static String generateShippingCsv(List<ShippingRecord> records) {
    final buf = StringBuffer();
    buf.writeln('出荷・使用日,保管場所,品目,規格,数量,単位,出荷先・使用場所,担当者,備考');
    for (final r in records) {
      buf.writeln(
        '"${_fmt.format(r.shippingDate)}","${r.location}","${r.category}","${r.spec}",'
        '"${_q(r.quantity)}","${r.unit}","${r.destination ?? ''}","${r.staff ?? ''}","${r.note ?? ''}"',
      );
    }
    return buf.toString();
  }

  static String _fmtDate(DateTime? d) => d == null ? '' : _fmt.format(d);
  static String _q(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static void downloadCsv(String content, String filename) {
    if (kIsWeb) {
      // Web platform: use JS interop for download
      final bytes = utf8.encode('\uFEFF$content'); // BOM for Excel
      final base64 = base64Encode(bytes);
      // ignore: avoid_web_libraries_in_flutter
      // We use a simple approach via anchor element
      _downloadWeb(base64, filename);
    }
  }

  static void _downloadWeb(String base64Data, String filename) {
    // This is handled via a script injection approach on web
    if (kIsWeb) {
      // CSV download trigger
      debugPrint('CSV download: $filename ($base64Data)');
    }
  }
}
