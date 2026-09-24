import { eq, and } from "drizzle-orm";
import { db } from "../db/client";
import { salesEntries } from "../db/schema";

// a resend of a closing the server already stored: same client id.
export async function findByClientId(d1: D1Database, clientId: string) {
  return db(d1).query.salesEntries.findFirst({
    where: eq(salesEntries.clientId, clientId),
  });
}

// a closing that looks typed in twice: same presenter, same day, same numbers.
// harian is left out on purpose, it is usually the branch default anyway.
export async function findIdenticalEntry(
  d1: D1Database,
  input: {
    presenterId: number;
    entryDate: string;
    closingCount: number;
    bopInput: number;
    audienceCount: number;
  },
) {
  return db(d1).query.salesEntries.findFirst({
    where: and(
      eq(salesEntries.presenterId, input.presenterId),
      eq(salesEntries.entryDate, input.entryDate),
      eq(salesEntries.closingCount, input.closingCount),
      eq(salesEntries.bopInput, input.bopInput),
      eq(salesEntries.audienceCount, input.audienceCount),
    ),
  });
}
