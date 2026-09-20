import { eq } from "drizzle-orm";
import { db } from "../db/client";
import { settings, type Settings } from "../db/schema";

// loads one branch's calculation values. fails loudly when the branch was
// created without them, rather than papering over it with defaults.
export async function loadSettings(d1: D1Database, branchId: number): Promise<Settings> {
  const row = await db(d1).query.settings.findFirst({
    where: eq(settings.branchId, branchId),
  });
  if (!row) throw new Error(`settings for branch ${branchId} not found`);
  return row;
}
