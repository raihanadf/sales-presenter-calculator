// plain data models mirroring the backend serializers.

class AppUser {
  final int id;
  final String name;
  final String username;
  final String role;

  AppUser({required this.id, required this.name, required this.username, required this.role});

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        username: j['username'],
        role: j['role'],
      );
}

class Settings {
  final int closingPrice;
  final int bopPercent;
  final int souvenirUnitPrice;
  final int souvenirPercent;
  final int harianDefault;

  Settings({
    required this.closingPrice,
    required this.bopPercent,
    required this.souvenirUnitPrice,
    required this.souvenirPercent,
    required this.harianDefault,
  });

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        closingPrice: j['closingPrice'],
        bopPercent: j['bopPercent'],
        souvenirUnitPrice: j['souvenirUnitPrice'],
        souvenirPercent: j['souvenirPercent'],
        harianDefault: j['harianDefault'],
      );
}

class Computed {
  final int closingTotal;
  final int bopValue;
  final int souvenirValue;
  final int takeHome;

  Computed({
    required this.closingTotal,
    required this.bopValue,
    required this.souvenirValue,
    required this.takeHome,
  });

  factory Computed.fromJson(Map<String, dynamic> j) => Computed(
        closingTotal: j['closingTotal'],
        bopValue: j['bopValue'],
        souvenirValue: j['souvenirValue'],
        takeHome: j['takeHome'],
      );
}

class EntryInputs {
  final int closingCount;
  final int bopInput;
  final int audienceCount;
  final int harian;

  EntryInputs({
    required this.closingCount,
    required this.bopInput,
    required this.audienceCount,
    required this.harian,
  });

  factory EntryInputs.fromJson(Map<String, dynamic> j) => EntryInputs(
        closingCount: j['closingCount'],
        bopInput: j['bopInput'],
        audienceCount: j['audienceCount'],
        harian: j['harian'],
      );
}

class SettingsSnapshot {
  final int closingPrice;
  final int bopPercent;
  final int souvenirUnitPrice;
  final int souvenirPercent;

  SettingsSnapshot({
    required this.closingPrice,
    required this.bopPercent,
    required this.souvenirUnitPrice,
    required this.souvenirPercent,
  });

  factory SettingsSnapshot.fromJson(Map<String, dynamic> j) => SettingsSnapshot(
        closingPrice: j['closingPrice'],
        bopPercent: j['bopPercent'],
        souvenirUnitPrice: j['souvenirUnitPrice'],
        souvenirPercent: j['souvenirPercent'],
      );
}

class SalesEntry {
  final int id;
  final int presenterId;
  final String? presenterName;
  final String entryDate;
  final String status;
  final EntryInputs inputs;
  final SettingsSnapshot? settingsSnapshot;
  final Computed computed;
  final int? approvedAt;

  SalesEntry({
    required this.id,
    required this.presenterId,
    required this.presenterName,
    required this.entryDate,
    required this.status,
    required this.inputs,
    required this.settingsSnapshot,
    required this.computed,
    required this.approvedAt,
  });

  bool get isPending => status == 'pending';

  factory SalesEntry.fromJson(Map<String, dynamic> j) => SalesEntry(
        id: j['id'],
        presenterId: j['presenterId'],
        presenterName: j['presenterName'],
        entryDate: j['entryDate'],
        status: j['status'],
        inputs: EntryInputs.fromJson(j['inputs']),
        settingsSnapshot: j['settingsSnapshot'] == null
            ? null
            : SettingsSnapshot.fromJson(j['settingsSnapshot']),
        computed: Computed.fromJson(j['computed']),
        approvedAt: j['approvedAt'],
      );
}

class EntryPage {
  final List<SalesEntry> entries;
  final int page;
  final int totalPages;
  final int total;

  EntryPage({
    required this.entries,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory EntryPage.fromJson(Map<String, dynamic> j) => EntryPage(
        entries: (j['entries'] as List).map((e) => SalesEntry.fromJson(e)).toList(),
        page: j['page'],
        totalPages: j['totalPages'],
        total: j['total'],
      );
}

class RecapRow {
  final int presenterId;
  final String presenterName;
  final int total;
  final int entries;

  RecapRow({
    required this.presenterId,
    required this.presenterName,
    required this.total,
    required this.entries,
  });

  factory RecapRow.fromJson(Map<String, dynamic> j) => RecapRow(
        presenterId: j['presenterId'],
        presenterName: j['presenterName'],
        total: j['total'],
        entries: j['entries'],
      );
}

class Dashboard {
  final String date;
  final String month;
  final int todayIncome;
  final int monthIncome;
  final List<RecapRow> top3;
  final List<RecapRow> monthRecap;
  final List<SalesEntry> pending;

  Dashboard({
    required this.date,
    required this.month,
    required this.todayIncome,
    required this.monthIncome,
    required this.top3,
    required this.monthRecap,
    required this.pending,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        date: j['date'],
        month: j['month'],
        todayIncome: j['todayIncome'],
        monthIncome: j['monthIncome'],
        top3: (j['top3'] as List).map((e) => RecapRow.fromJson(e)).toList(),
        monthRecap: (j['monthRecap'] as List).map((e) => RecapRow.fromJson(e)).toList(),
        pending: (j['pending'] as List).map((e) => SalesEntry.fromJson(e)).toList(),
      );
}

class TrendPoint {
  final String date;
  final int income;
  TrendPoint({required this.date, required this.income});
  factory TrendPoint.fromJson(Map<String, dynamic> j) =>
      TrendPoint(date: j['date'], income: j['income']);
}

class RecentEntry {
  final int id;
  final String entryDate;
  final int closingCount;
  final int takeHome;
  final String status;
  RecentEntry({
    required this.id,
    required this.entryDate,
    required this.closingCount,
    required this.takeHome,
    required this.status,
  });
  bool get isPending => status == 'pending';
  factory RecentEntry.fromJson(Map<String, dynamic> j) => RecentEntry(
        id: j['id'],
        entryDate: j['entryDate'],
        closingCount: j['closingCount'],
        takeHome: j['takeHome'],
        status: j['status'],
      );
}

class MyDashboard {
  final int todayIncome;
  final int monthIncome;
  final int monthClosings;
  final int entryCount;
  final int avgPerClosing;
  final int bestTakeHome;
  final String? bestDate;
  final int? rank;
  final int totalPresenters;
  final List<TrendPoint> trend;
  final List<RecentEntry> recent;

  MyDashboard({
    required this.todayIncome,
    required this.monthIncome,
    required this.monthClosings,
    required this.entryCount,
    required this.avgPerClosing,
    required this.bestTakeHome,
    required this.bestDate,
    required this.rank,
    required this.totalPresenters,
    required this.trend,
    required this.recent,
  });

  factory MyDashboard.fromJson(Map<String, dynamic> j) => MyDashboard(
        todayIncome: j['todayIncome'],
        monthIncome: j['monthIncome'],
        monthClosings: j['monthClosings'],
        entryCount: j['entryCount'],
        avgPerClosing: j['avgPerClosing'],
        bestTakeHome: j['bestTakeHome'],
        bestDate: j['bestDate'],
        rank: j['rank'],
        totalPresenters: j['totalPresenters'],
        trend: (j['trend'] as List).map((e) => TrendPoint.fromJson(e)).toList(),
        recent: (j['recent'] as List).map((e) => RecentEntry.fromJson(e)).toList(),
      );
}
