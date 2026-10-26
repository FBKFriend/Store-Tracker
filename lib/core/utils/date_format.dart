class Fmt {
  Fmt._();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// e.g. "Oct 18, 2026"
  static String date(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  /// e.g. "4:17 PM"
  static String time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  /// e.g. "Oct 18, 2026 · 4:17 PM"
  static String dateTime(DateTime d) => '${date(d)} · ${time(d)}';

  /// "Today", "Yesterday", or the date
  static String dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return date(d);
  }

  /// e.g. "just now", "3 hours ago", "yesterday", "6 days ago"
  static String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    final days = diff.inDays;
    return days == 1 ? 'yesterday' : '$days days ago';
  }
}
