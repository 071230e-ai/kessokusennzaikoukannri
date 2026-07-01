// 日本時間（Asia/Tokyo, UTC+9）専用の時刻ユーティリティ。
//
// Flutter Web は `flutter test` / `flutter build web` 上で
// `DateTime.now()` の TZ がブラウザのローカル時刻に依存する。
// 月次判定（毎月1日以降に通知を出すなど）の挙動を端末のタイムゾーン設定に
// 影響されないようにするため、すべて UTC+9 固定で扱う。

class JstTime {
  static const Duration jstOffset = Duration(hours: 9);

  /// 「今、日本時間で何時か」を表す DateTime（DateTime.utc(...) で構築するため
  /// year/month/day などのフィールドが日本時間の値となる）。
  static DateTime now() {
    final utc = DateTime.now().toUtc();
    final jst = utc.add(jstOffset);
    // 構造体を「UTC」フラグで返すが、値そのものは日本時間。
    // year/month/day/hour/minute/second は日本時間のフィールド値。
    return DateTime.utc(
      jst.year, jst.month, jst.day,
      jst.hour, jst.minute, jst.second, jst.millisecond, jst.microsecond,
    );
  }

  /// 当月の (year, month)
  static (int year, int month) currentYearMonth() {
    final n = now();
    return (n.year, n.month);
  }

  /// 当月の1日 0:00 (JST フィールド値、UTC フラグ)
  static DateTime currentMonthFirstDay() {
    final n = now();
    return DateTime.utc(n.year, n.month, 1);
  }

  /// 「現在(JST)が当月1日 0:00 を過ぎているか」を判定。
  /// 毎月1日 00:00 以降なら true。
  /// （実際には JST の年月が現在の表示対象なので、年月を取得した時点で常に true となるが、
  /// 仕様上の「毎月1日 0:00 以降」を明示的に保証するためのヘルパー）。
  static bool isOnOrAfterCurrentMonthFirst() {
    final n = now();
    // 1日 0:00 ≦ 現在時刻 は常に真（同月内なので）。月跨ぎの境界で日付が1へ
    // 切り替わった瞬間に新しい月の判定対象に切り替わる、という挙動を保証する。
    return n.day >= 1;
  }

  /// 日本時間の ISO8601 表現（タイムゾーンサフィックス付き）。
  ///
  /// 例: 2026-07-01T09:15:00+09:00
  static String formatIso(DateTime jst) {
    final y = jst.year.toString().padLeft(4, '0');
    final mo = jst.month.toString().padLeft(2, '0');
    final d = jst.day.toString().padLeft(2, '0');
    final h = jst.hour.toString().padLeft(2, '0');
    final mi = jst.minute.toString().padLeft(2, '0');
    final s = jst.second.toString().padLeft(2, '0');
    return '$y-$mo-${d}T$h:$mi:$s+09:00';
  }

  /// 「2026年7月1日 09:15」フォーマット
  static String formatDisplay(DateTime? dt) {
    if (dt == null) return '-';
    // checked_at が ISO の場合はそのまま jst 換算（+09:00 を解釈）
    final jst = dt.isUtc ? dt.add(jstOffset) : dt;
    final y = jst.year;
    final m = jst.month;
    final d = jst.day;
    final h = jst.hour.toString().padLeft(2, '0');
    final mi = jst.minute.toString().padLeft(2, '0');
    return '$y年$m月$d日 $h:$mi';
  }

  /// 「2026年7月」フォーマット
  static String formatYearMonth(int year, int month) {
    return '$year年$month月';
  }
}
