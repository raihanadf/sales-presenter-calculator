import type { User, Settings, SalesEntry } from "../db/schema";

// serializers keep internal columns (password_hash) and db shape out of
// responses. handlers return these, never raw rows.

export function presentUser(u: User) {
  return {
    id: u.id,
    name: u.name,
    username: u.username,
    role: u.role,
    createdAt: u.createdAt,
  };
}

export function presentSettings(s: Settings) {
  return {
    closingPrice: s.closingPrice,
    bopPercent: s.bopPercent,
    souvenirUnitPrice: s.souvenirUnitPrice,
    souvenirPercent: s.souvenirPercent,
    harianDefault: s.harianDefault,
    updatedAt: s.updatedAt,
  };
}

export function presentEntry(e: SalesEntry, presenterName?: string) {
  return {
    id: e.id,
    presenterId: e.presenterId,
    presenterName: presenterName ?? null,
    entryDate: e.entryDate,
    inputs: {
      closingCount: e.closingCount,
      bopInput: e.bopInput,
      audienceCount: e.audienceCount,
      harian: e.harian,
    },
    computed: {
      closingTotal: e.closingTotal,
      bopValue: e.bopValue,
      souvenirValue: e.souvenirValue,
      takeHome: e.takeHome,
    },
    createdAt: e.createdAt,
  };
}
