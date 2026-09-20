import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { db } from "../db/client";
import { settings } from "../db/schema";
import { loadSettings } from "../lib/settings";
import { updateSettingsSchema, branchQuerySchema } from "../validation/schemas";
import { presentSettings } from "../serializers";
import { requireSuperadmin } from "../middleware/auth";
import { resolveBranchScope } from "../lib/scope";
import type { Env } from "../types";

export const settingsRoutes = new Hono<Env>();

// any authed user reads their own branch's values (the entry preview needs
// them). the superadmin must name a branch, since it has none of its own.
settingsRoutes.get("/", async (c) => {
  const parsed = branchQuerySchema.safeParse(c.req.query());
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const scope = resolveBranchScope(c.get("user"), parsed.data.branchId);
  if (scope === null) return c.json({ error: "branchId wajib diisi" }, 422);

  const s = await loadSettings(c.env.DB, scope);
  return c.json({ settings: presentSettings(s) });
});

// money is owner business: only the superadmin edits it, never the branch
// admin whose own team is paid by these numbers.
settingsRoutes.put("/", requireSuperadmin, async (c) => {
  const query = branchQuerySchema.safeParse(c.req.query());
  if (!query.success) return c.json({ error: query.error.flatten() }, 422);
  if (!query.data.branchId) return c.json({ error: "branchId wajib diisi" }, 422);

  const parsed = updateSettingsSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const updated = await db(c.env.DB)
    .update(settings)
    .set({ ...parsed.data, updatedAt: Date.now() })
    .where(eq(settings.branchId, query.data.branchId))
    .returning();
  if (!updated[0]) return c.json({ error: "settings for branch not found" }, 404);
  return c.json({ settings: presentSettings(updated[0]) });
});
