import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { db } from "../db/client";
import { settings } from "../db/schema";
import { loadSettings } from "../lib/settings";
import { updateSettingsSchema } from "../validation/schemas";
import { presentSettings } from "../serializers";
import { requireAdmin } from "../middleware/auth";
import type { Env } from "../types";

export const settingsRoutes = new Hono<Env>();

// any authed user can read the fixed values (needed for the entry preview).
settingsRoutes.get("/", async (c) => {
  const s = await loadSettings(c.env.DB);
  return c.json({ settings: presentSettings(s) });
});

// only admin edits them.
settingsRoutes.put("/", requireAdmin, async (c) => {
  const parsed = updateSettingsSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const updated = await db(c.env.DB)
    .update(settings)
    .set({ ...parsed.data, updatedAt: Date.now() })
    .where(eq(settings.id, 1))
    .returning();
  return c.json({ settings: presentSettings(updated[0]) });
});
