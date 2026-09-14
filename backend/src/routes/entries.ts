import { Hono } from "hono";
import { eq, and, gte, lte, desc, sql } from "drizzle-orm";
import { db } from "../db/client";
import { salesEntries, users } from "../db/schema";
import { loadSettings } from "../lib/settings";
import { calculate } from "../lib/calc";
import {
  entryIdSchema,
  entryInputSchema,
  entryListQuerySchema,
  previewSchema,
  bulkImportSchema,
  monthQuerySchema,
} from "../validation/schemas";
import { presentEntry } from "../serializers";
import { requireAdmin } from "../middleware/auth";
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
  const presenterId =
    me.role === "admin" ? (parsed.data.presenterId ?? me.id) : me.id;
  const status = me.role === "admin" ? "approved" : "pending";
  const now = Date.now();
  const s = await loadSettings(c.env.DB);
  const harian = parsed.data.harian ?? s.harianDefault;
  const computed = calculate({ ...parsed.data, harian }, s);

  const inserted = await db(c.env.DB)
    .insert(salesEntries)
    .values({
      presenterId,
      entryDate: parsed.data.entryDate,
      status,
      closingCount: parsed.data.closingCount,
      bopInput: parsed.data.bopInput,
      audienceCount: parsed.data.audienceCount,
      harian,
      closingPriceUsed: s.closingPrice,
      bopPercentUsed: s.bopPercent,
      souvenirUnitPriceUsed: s.souvenirUnitPrice,
      souvenirPercentUsed: s.souvenirPercent,
      closingTotal: computed.closingTotal,
      bopValue: computed.bopValue,
      souvenirValue: computed.souvenirValue,
      takeHome: computed.takeHome,
      approvedAt: status === "approved" ? now : null,
      approvedBy: status === "approved" ? me.id : null,
      createdAt: now,
    })
    .returning();
  return c.json({ entry: presentEntry(inserted[0]) }, 201);
});

// presenters are scoped to their own rows. every page contains 20 rows.
entryRoutes.get("/", async (c) => {
  const me = c.get("user");
  const parsed = entryListQuerySchema.safeParse(c.req.query());
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const q = parsed.data;
  const filters = [];
  if (me.role === "admin") {
    if (q.presenterId) filters.push(eq(salesEntries.presenterId, q.presenterId));
  } else {
    filters.push(eq(salesEntries.presenterId, me.id));
  }
  if (q.from) filters.push(gte(salesEntries.entryDate, q.from));
  if (q.to) filters.push(lte(salesEntries.entryDate, q.to));

  const condition = filters.length ? and(...filters) : undefined;
  const d = db(c.env.DB);
  const totals = await d
    .select({ total: sql<number>`count(*)` })
    .from(salesEntries)
    .where(condition);
  const rows = await d
    .select({ entry: salesEntries, presenterName: users.name })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .where(condition)
    .orderBy(desc(salesEntries.entryDate), desc(salesEntries.id))
    .limit(20)
    .offset((q.page - 1) * 20);
  const total = totals[0].total;

  return c.json({
    entries: rows.map((r) => presentEntry(r.entry, r.presenterName)),
    page: q.page,
    pageSize: 20,
    total,
    totalPages: Math.ceil(total / 20),
  });
});

// admin bulk import from an excel upload. one presenter, many dated rows.
// registered before "/:id" so "bulk" is not read as an entry id.
entryRoutes.post("/bulk", requireAdmin, async (c) => {
  const parsed = bulkImportSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const d = db(c.env.DB);
  const presenter = await d.query.users.findFirst({
    where: eq(users.id, parsed.data.presenterId),
  });
  if (!presenter) return c.json({ error: "presenter not found" }, 404);

  const s = await loadSettings(c.env.DB);
  const now = Date.now();
  const adminId = c.get("user").id;
  const values = parsed.data.rows.map((row) => {
    const harian = row.harian ?? s.harianDefault;
    const computed = calculate({ ...row, harian }, s);
    return {
      presenterId: parsed.data.presenterId,
      entryDate: row.entryDate,
      status: "approved" as const,
      closingCount: row.closingCount,
      bopInput: row.bopInput,
      audienceCount: row.audienceCount,
      harian,
      closingPriceUsed: s.closingPrice,
      bopPercentUsed: s.bopPercent,
      souvenirUnitPriceUsed: s.souvenirUnitPrice,
      souvenirPercentUsed: s.souvenirPercent,
      closingTotal: computed.closingTotal,
      bopValue: computed.bopValue,
      souvenirValue: computed.souvenirValue,
      takeHome: computed.takeHome,
      approvedAt: now,
      approvedBy: adminId,
      createdAt: now,
    };
  });

  const inserted = await d.insert(salesEntries).values(values).returning({ id: salesEntries.id });
  return c.json({ inserted: inserted.length }, 201);
});

// admin month recap: every approved entry in a yyyy-mm period, unpaginated,
// for the pdf export. registered before "/:id".
entryRoutes.get("/month", requireAdmin, async (c) => {
  const parsed = monthQuerySchema.safeParse(c.req.query());
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const month = parsed.data.month;
  const rows = await db(c.env.DB)
    .select({ entry: salesEntries, presenterName: users.name })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .where(
      and(
        gte(salesEntries.entryDate, `${month}-01`),
        lte(salesEntries.entryDate, `${month}-31`),
        eq(salesEntries.status, "approved"),
      ),
    )
    .orderBy(salesEntries.entryDate, salesEntries.id);

  return c.json({
    month,
    entries: rows.map((r) => presentEntry(r.entry, r.presenterName)),
  });
});

entryRoutes.get("/:id", async (c) => {
  const me = c.get("user");
  const id = entryIdSchema.safeParse(c.req.param("id"));
  if (!id.success) return c.json({ error: id.error.flatten() }, 422);

  const rows = await db(c.env.DB)
    .select({ entry: salesEntries, presenterName: users.name })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .where(eq(salesEntries.id, id.data));

  const row = rows[0];
  if (!row) return c.json({ error: "entry not found" }, 404);
  if (me.role !== "admin" && row.entry.presenterId !== me.id) {
    return c.json({ error: "forbidden" }, 403);
  }
  return c.json({ entry: presentEntry(row.entry, row.presenterName) });
});

entryRoutes.post("/:id/approve", requireAdmin, async (c) => {
  const id = entryIdSchema.safeParse(c.req.param("id"));
  if (!id.success) return c.json({ error: id.error.flatten() }, 422);

  const updated = await db(c.env.DB)
    .update(salesEntries)
    .set({
      status: "approved",
      approvedAt: Date.now(),
      approvedBy: c.get("user").id,
    })
    .where(
      and(
        eq(salesEntries.id, id.data),
        eq(salesEntries.status, "pending"),
      ),
    )
    .returning();
  if (!updated[0]) {
    const existing = await db(c.env.DB)
      .select({ id: salesEntries.id })
      .from(salesEntries)
      .where(eq(salesEntries.id, id.data));
    return existing[0]
      ? c.json({ error: "entry already approved" }, 409)
      : c.json({ error: "entry not found" }, 404);
  }

  return c.json({ entry: presentEntry(updated[0]) });
});
