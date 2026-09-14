import '../api/models.dart';

// mirrors the backend calc so the entry form can preview take-home offline.
// closing x price, bop x bop%, audience x unit x souvenir%, minus flat harian.
Computed calcTakeHome(
    Settings s, int closingCount, int bopInput, int audienceCount, int harian) {
  final closingTotal = closingCount * s.closingPrice;
  final bopValue = (bopInput * s.bopPercent / 100).round();
  final souvenirValue =
      (audienceCount * s.souvenirUnitPrice * s.souvenirPercent / 100).round();
  final takeHome = closingTotal - bopValue - souvenirValue - harian;
  return Computed(
    closingTotal: closingTotal,
    bopValue: bopValue,
    souvenirValue: souvenirValue,
    takeHome: takeHome,
  );
}
