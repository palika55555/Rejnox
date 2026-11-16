/// Jedálniček od trénera tak, ako ho vidí klient.
library;

const dayNames = [
  'Pondelok',
  'Utorok',
  'Streda',
  'Štvrtok',
  'Piatok',
  'Sobota',
  'Nedeľa',
];
const dayShort = ['Po', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne'];

/// Ako ďaleko dozadu sa dá jedlo odškrtnúť (server dovolí 7 dní).
const checkWindowDays = 7;

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Dátum ako „YYYY-MM-DD“ (bez času).
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Pondelok = 0 … nedeľa = 6.
int weekdayIndex(DateTime d) => d.weekday - 1;

/// Dátum vo vybranom dni tohto týždňa (pondelok až nedeľa okolo [today]).
DateTime dateInWeek(DateTime today, int day) {
  final base = DateTime(today.year, today.month, today.day);
  return base.add(Duration(days: day - weekdayIndex(base)));
}

/// Dá sa jedlo v deň [date] odškrtnúť? Len dnes a posledný týždeň, nie budúcnosť.
bool canCheckOn(DateTime date, DateTime today) {
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  return diff >= 0 && diff <= checkWindowDays;
}

class MacroTotals {
  const MacroTotals({
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  final int kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  MacroTotals operator +(MealItem i) => MacroTotals(
    kcal: kcal + i.kcal,
    proteinG: proteinG + i.proteinG,
    carbsG: carbsG + i.carbsG,
    fatG: fatG + i.fatG,
  );
}

class MealItem {
  const MealItem({
    required this.id,
    required this.day,
    required this.meal,
    required this.name,
    this.amount,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.note,
  });

  factory MealItem.fromJson(Map<String, dynamic> j) => MealItem(
    id: j['id'] as String,
    day: j['day'] as int,
    meal: j['meal'] as String,
    name: j['name'] as String,
    amount: j['amount'] as String?,
    kcal: (j['kcal'] as num).toInt(),
    proteinG: _num(j['proteinG']),
    carbsG: _num(j['carbsG']),
    fatG: _num(j['fatG']),
    note: j['note'] as String?,
  );

  final String id;
  final int day;
  final String meal;
  final String name;
  final String? amount;
  final int kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String? note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'meal': meal,
    'name': name,
    'amount': amount,
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'note': note,
  };
}

class MealTargets {
  const MealTargets({this.kcal, this.proteinG, this.carbsG, this.fatG});

  factory MealTargets.fromJson(Map<String, dynamic>? j) => MealTargets(
    kcal: (j?['kcal'] as num?)?.toInt(),
    proteinG: (j?['proteinG'] as num?)?.toInt(),
    carbsG: (j?['carbsG'] as num?)?.toInt(),
    fatG: (j?['fatG'] as num?)?.toInt(),
  );

  final int? kcal;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;

  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
  };
}

class MealPlan {
  const MealPlan({
    required this.id,
    required this.title,
    this.note,
    required this.trainerName,
    required this.targets,
    required this.sentAt,
    required this.items,
    required this.checks,
  });

  factory MealPlan.fromJson(Map<String, dynamic> j) => MealPlan(
    id: j['id'] as String,
    title: j['title'] as String,
    note: j['note'] as String?,
    trainerName: j['trainerName'] as String,
    targets: MealTargets.fromJson(j['targets'] as Map<String, dynamic>?),
    sentAt: DateTime.parse(j['sentAt'] as String).toLocal(),
    items: [
      for (final i in j['items'] as List)
        MealItem.fromJson(i as Map<String, dynamic>),
    ],
    checks: {
      for (final c in (j['checks'] as List? ?? const []))
        _checkKey(
          (c as Map<String, dynamic>)['itemId'] as String,
          c['eatenOn'] as String,
        ),
    },
  );

  final String id;
  final String title;
  final String? note;
  final String trainerName;
  final MealTargets targets;
  final DateTime sentAt;
  final List<MealItem> items;

  /// Zjedené jedlá ako „itemId|YYYY-MM-DD“.
  final Set<String> checks;

  static String _checkKey(String itemId, String day) => '$itemId|$day';

  bool isEaten(String itemId, DateTime date) =>
      checks.contains(_checkKey(itemId, dayKey(date)));

  List<MealItem> itemsFor(int day) => [
    for (final i in items)
      if (i.day == day) i,
  ];

  MacroTotals planned(int day) =>
      itemsFor(day).fold(const MacroTotals(), (s, i) => s + i);

  MacroTotals eaten(int day, DateTime date) => itemsFor(day)
      .where((i) => isEaten(i.id, date))
      .fold(const MacroTotals(), (s, i) => s + i);

  /// Nová kópia so zmeneným odškrtnutím (pre okamžitú odozvu v appke).
  MealPlan withCheck(String itemId, DateTime date, {required bool eaten}) {
    final key = _checkKey(itemId, dayKey(date));
    return MealPlan(
      id: id,
      title: title,
      note: note,
      trainerName: trainerName,
      targets: targets,
      sentAt: sentAt,
      items: items,
      checks: eaten ? {...checks, key} : ({...checks}..remove(key)),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'trainerName': trainerName,
    'targets': targets.toJson(),
    'sentAt': sentAt.toUtc().toIso8601String(),
    'items': [for (final i in items) i.toJson()],
    'checks': [
      for (final c in checks)
        {'itemId': c.split('|').first, 'eatenOn': c.split('|').last},
    ],
  };
}
