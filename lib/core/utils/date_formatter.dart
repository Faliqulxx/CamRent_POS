import 'package:intl/intl.dart';

class DateFormatter {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  static const List<String> _days = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];

  static String format(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      final month = (date.month >= 1 && date.month <= 12) ? _months[date.month - 1] : '${date.month}';
      return '${date.day.toString().padLeft(2, '0')} $month ${date.year}';
    }
  }

  static String formatWithDay(DateTime date) {
    try {
      return DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      final dayName = (date.weekday >= 1 && date.weekday <= 7) ? _days[date.weekday - 1] : '';
      return '$dayName, ${format(date)}';
    }
  }

  static String formatDateTime(DateTime date) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
    } catch (_) {
      return '${format(date)}, ${formatTime(date)}';
    }
  }

  static String formatTime(DateTime date) {
    try {
      return DateFormat('HH:mm', 'id_ID').format(date);
    } catch (_) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
