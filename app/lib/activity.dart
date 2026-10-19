/// Gentle weekly rhythm and the parent's daily time limit.
///
/// Research note: daily streaks that can be "lost" push children to open an
/// app out of worry rather than interest. So there is no streak to break
/// here: a week of 7 dots fills as the child learns and starts fresh each
/// Saturday, with no loss message and no reminders.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The 7 days of the week containing [now], starting on Saturday.
List<DateTime> weekOf(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final back = (today.weekday - DateTime.saturday) % 7; // Dart: Monday=1 ... Sunday=7
  final start = today.subtract(Duration(days: back));
  return [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
}

class Activity {
  final Set<String> activeDays;
  final Map<String, int> minutesByDay;
  final Map<String, int> extraByDay;
  int dailyLimit; // minutes, 0 = no limit

  Activity({
    Set<String>? activeDays,
    Map<String, int>? minutesByDay,
    Map<String, int>? extraByDay,
    this.dailyLimit = 0,
  })  : activeDays = activeDays ?? {},
        minutesByDay = minutesByDay ?? {},
        extraByDay = extraByDay ?? {};

  /// Returns true when today was not already counted.
  bool markActive(DateTime now) => activeDays.add(dayKey(now));

  int daysThisWeek(DateTime now) => weekOf(now).where((d) => activeDays.contains(dayKey(d))).length;

  List<bool> weekDots(DateTime now) => [for (final d in weekOf(now)) activeDays.contains(dayKey(d))];

  void addMinute(DateTime now) => minutesByDay.update(dayKey(now), (m) => m + 1, ifAbsent: () => 1);

  int minutesToday(DateTime now) => minutesByDay[dayKey(now)] ?? 0;

  void allowMore(DateTime now, int minutes) => extraByDay.update(dayKey(now), (m) => m + minutes, ifAbsent: () => minutes);

  bool timeUp(DateTime now) =>
      dailyLimit > 0 && minutesToday(now) >= dailyLimit + (extraByDay[dayKey(now)] ?? 0);

  /// Keeps stored history small: the last 60 days.
  void prune(DateTime now) {
    final cutoff = dayKey(now.subtract(const Duration(days: 60)));
    activeDays.removeWhere((d) => d.compareTo(cutoff) < 0);
    minutesByDay.removeWhere((d, _) => d.compareTo(cutoff) < 0);
    extraByDay.removeWhere((d, _) => d.compareTo(cutoff) < 0);
  }

  static Map<String, int> decodeCounts(List<String> raw) => {
        for (final s in raw)
          if (s.split(':').length == 2 && int.tryParse(s.split(':')[1]) != null) s.split(':')[0]: int.parse(s.split(':')[1]),
      };

  static List<String> encodeCounts(Map<String, int> m) => [for (final e in m.entries) '${e.key}:${e.value}'];
}

/// A small adult-level question that keeps children out of the parent area.
class ParentGateQuestion {
  final int a;
  final int b;
  const ParentGateQuestion(this.a, this.b);

  factory ParentGateQuestion.random(int seed) => ParentGateQuestion(12 + seed % 8, 3 + (seed ~/ 8) % 7);

  int get answer => a * b;
}
