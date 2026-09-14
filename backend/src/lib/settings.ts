import { eq } from "drizzle-orm";
import { db } from "../db/client";
import { settings, type Settings } from "../db/schema";

// loads the singleton settings row (id=1). fails loudly if seed never ran,
// rather than papering over missing config with defaults.
export async function loadSettings(d1: D1Database): Promise<Settings> {
  const row = await db(d1).query.settings.findFirst({ where: eq(settings.id, 1) });
  if (!row) throw new Error("settings not seeded");
  return row;
}
