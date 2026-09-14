import type { Settings } from "../db/schema";

export type CalcInput = {
  closingCount: number;
  bopInput: number;
  audienceCount: number;
  harian: number;
};

export type CalcResult = {
  closingTotal: number;
  bopValue: number;
  souvenirValue: number;
  takeHome: number;
};

// core sales math. bop and souvenir are both scaled by their percent;
// harian is a flat deduction. take-home = closing minus all three.
// see readme: closing_count x price, bop x bop%, audience x unit x souvenir%.
export function calculate(input: CalcInput, s: Settings): CalcResult {
  const closingTotal = input.closingCount * s.closingPrice;
  const bopValue = Math.round((input.bopInput * s.bopPercent) / 100);
  const souvenirValue = Math.round(
    (input.audienceCount * s.souvenirUnitPrice * s.souvenirPercent) / 100,
  );
  const takeHome = closingTotal - bopValue - souvenirValue - input.harian;
  return { closingTotal, bopValue, souvenirValue, takeHome };
}
