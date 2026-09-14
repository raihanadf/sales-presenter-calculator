import { Hono } from "hono";
import { eq, and, gte, lte, desc } from "drizzle-orm";
import { db } from "../db/client";
import { salesEntries, users } from "../db/schema";
import { loadSettings } from "../lib/settings";
import { calculate } from "../lib/calc";
import { entryInputSchema, previewSchema } from "../validation/schemas";
import { presentEntry } from "../serializers";
import type { Env } from "../types";

export const entryRoutes = new Hono<Env>();

// live take-home preview for the form. no persistence.
entryRoutes.post("/preview", async (c) => {
  const parsed = previewSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const s = await loadSettings(c.env.DB);
  const harian = parsed.data.harian ?? s.harianDefault;
  const computed = calculate({ ...parsed.data, harian }, s);
  return c.json({ harian, computed });
});

entryRoutes.post("/", async (c) => {
  const parsed = entryInputSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const me = c.get("user");
  // presenters can only file for themselves; admin may target any presenter.
  const presenterId =
    me.role === "admin" ? (parsed.data.presenterId ?? me.id) : me.id;

  const s = await loadSettings(c.env.DB);
  const harian = parsed.data.harian ?? s.harianDefault;
  const computed = calculate({ ...parsed.data, harian }, s);

  const inserted = await db(c.env.DB)
    .insert(salesEntries)
    .values({
      presenterId,
      entryDate: parsed.data.entryDate,
      closingCount: parsed.data.closingCount,
      bopInput: parsed.data.bopInput,
      audienceCount: parsed.data.audienceCount,
      harian,
      closingTotal: computed.closingTotal,
      bopValue: computed.bopValue,
      souvenirValue: computed.souvenirValue,
      takeHome: computed.takeHome,
      createdAt: Date.now(),
    })
    .returning();
  return c.json({ entry: presentEntry(inserted[0]) }, 201);
});

// list with optional filters. presenters are scoped to their own rows.
entryRoutes.get("/", async (c) => {
  const me = c.get("user");
  const q = c.req.query();

  const filters = [];
  if (me.role === "admin") {
    if (q.presenterId) filters.push(eq(salesEntries.presenterId, Number(q.presenterId)));
  } else {
    filters.push(eq(salesEntries.presenterId, me.id));
  }
  if (q.from) filters.push(gte(salesEntries.entryDate, q.from));
  if (q.to) filters.push(lte(salesEntries.entryDate, q.to));

  const rows = await db(c.env.DB)
    .select({ entry: salesEntries, presenterName: users.name })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .where(filters.length ? and(...filters) : undefined)
    .orderBy(desc(salesEntries.entryDate), desc(salesEntries.id));

  return c.json({ entries: rows.map((r) => presentEntry(r.entry, r.presenterName)) });
});

entryRoutes.get("/:id", async (c) => {
  const me = c.get("user");
  const rows = await db(c.env.DB)
    .select({ entry: salesEntries, presenterName: users.name })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .where(eq(salesEntries.id, Number(c.req.param("id"))));

  const row = rows[0];
  if (!row) return c.json({ error: "entry not found" }, 404);
  if (me.role !== "admin" && row.entry.presenterId !== me.id) {
    return c.json({ error: "forbidden" }, 403);
  }
  return c.json({ entry: presentEntry(row.entry, row.presenterName) });
});
