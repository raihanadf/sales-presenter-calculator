import { Hono } from "hono";
import { eq, and, gte, lte, desc, sql } from "drizzle-orm";
import { db } from "../db/client";
import { salesEntries, users, branches } from "../db/schema";
import { loadSettings } from "../lib/settings";
import { calculate } from "../lib/calc";
import { resolveBranchScope } from "../lib/scope";
import {
  entryIdSchema,
  entryInputSchema,
  entryListQuerySchema,
  previewSchema,
  bulkImportSchema,
  monthQuerySchema,
  branchQuerySchema,
} from "../validation/schemas";
import { presentEntry } from "../serializers";
import { requireAdmin } from "../middleware/auth";
import type { Env, AuthUser } from "../types";

export const entryRoutes = new Hono<Env>();

// the branch an entry belongs to: a presenter's own, or, when an admin files on
// someone's behalf, that presenter's current branch.
async function presenterBranch(d1: D1Database, presenterId: number) {
  const row = await db(d1).query.users.findFirst({ where: eq(users.id, presenterId) });
  if (!row) return null;
  return row.branchId;
}

// live take-home preview for the form. no persistence.
entryRoutes.post("/preview", async (c) => {
  const parsed = previewSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);
  const query = branchQuerySchema.safeParse(c.req.query());
  if (!query.success) return c.json({ error: query.error.flatten() }, 422);

  const scope = resolveBranchScope(c.get("user"), query.data.branchId);
  if (scope === null) return c.json({ error: "branchId wajib diisi" }, 422);

  const s = await loadSettings(c.env.DB, scope);
  const harian = parsed.data.harian ?? s.harianDefault;
  const computed = calculate({ ...parsed.data, harian }, s);
  return c.json({ harian, computed });
});

entryRoutes.post("/", async (c) => {
  const parsed = entryInputSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const me = c.get("user");
  const isAdmin = me.role === "admin" || me.role === "superadmin";
  const presenterId = isAdmin ? (parsed.data.presenterId ?? me.id) : me.id;
  const branchId = presenterId === me.id ? me.branchId : await presenterBranch(c.env.DB, presenterId);
  if (branchId === null) return c.json({ error: "presenter tidak punya cabang" }, 422);
  resolveBranchScope(me, branchId);

  const status = isAdmin ? "approved" : "pending";
  const now = Date.now();
  const s = await loadSettings(c.env.DB, branchId);
  const harian = parsed.data.harian ?? s.harianDefault;
  const computed = calculate({ ...parsed.data, harian }, s);

  const inserted = await db(c.env.DB)
    .insert(salesEntries)
    .values({
      presenterId,
      branchId,
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

// presenters see their own rows across every branch they ever worked in, since
// that is their own income. admins see their branch, the superadmin sees all.
entryRoutes.get("/", async (c) => {
  const me = c.get("user");
  const parsed = entryListQuerySchema.safeParse(c.req.query());
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const q = parsed.data;
  const filters = [];
  if (me.role === "presenter") {
    filters.push(eq(salesEntries.presenterId, me.id));
  } else {
    const scope = resolveBranchScope(me, q.branchId);
    if (scope !== null) filters.push(eq(salesEntries.branchId, scope));
    if (q.presenterId) filters.push(eq(salesEntries.presenterId, q.presenterId));
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
    .select({ entry: salesEntries, presenterName: users.name, branchName: branches.name })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .innerJoin(branches, eq(branches.id, salesEntries.branchId))
    .where(condition)
    .orderBy(desc(salesEntries.entryDate), desc(salesEntries.id))
    .limit(20)
    .offset((q.page - 1) * 20);
  const total = totals[0].total;

  return c.json({
    entries: rows.map((r) => presentEntry(r.entry, r.presenterName, r.branchName)),
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
  if (presenter.branchId === null) return c.json({ error: "presenter tidak punya cabang" }, 422);
  resolveBranchScope(c.get("user"), presenter.branchId);

  const s = await loadSettings(c.env.DB, presenter.branchId);
  const now = Date.now();
  const adminId = c.get("user").id;
  const values = parsed.data.rows.map((row) => {
    const harian = row.harian ?? s.harianDefault;
    const computed = calculate({ ...row, harian }, s);
    return {
      presenterId: parsed.data.presenterId,
      branchId: presenter.branchId as number,
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

// month recap: every approved entry in a yyyy-mm period, unpaginated, for the
// pdf export. an admin gets its own branch; the superadmin may span all of them
// and the pdf groups per branch, because prices differ between branches.
entryRoutes.get("/month", requireAdmin, async (c) => {
  const parsed = monthQuerySchema.safeParse(c.req.query());
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 422);

  const month = parsed.data.month;
  const scope = resolveBranchScope(c.get("user"), parsed.data.branchId);
  const filters = [
    gte(salesEntries.entryDate, `${month}-01`),
    lte(salesEntries.entryDate, `${month}-31`),
    eq(salesEntries.status, "approved"),
  ];
  if (scope !== null) filters.push(eq(salesEntries.branchId, scope));

  const rows = await db(c.env.DB)
    .select({ entry: salesEntries, presenterName: users.name, branchName: branches.name })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .innerJoin(branches, eq(branches.id, salesEntries.branchId))
    .where(and(...filters))
    .orderBy(branches.name, salesEntries.entryDate, salesEntries.id);

  return c.json({
    month,
    branchId: scope,
    entries: rows.map((r) => presentEntry(r.entry, r.presenterName, r.branchName)),
  });
});

entryRoutes.get("/:id", async (c) => {
  const me = c.get("user");
  const id = entryIdSchema.safeParse(c.req.param("id"));
  if (!id.success) return c.json({ error: id.error.flatten() }, 422);

  const rows = await db(c.env.DB)
    .select({ entry: salesEntries, presenterName: users.name, branchName: branches.name })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .innerJoin(branches, eq(branches.id, salesEntries.branchId))
    .where(eq(salesEntries.id, id.data));

  const row = rows[0];
  if (!row) return c.json({ error: "entry not found" }, 404);
  if (!canReadEntry(me, row.entry.presenterId, row.entry.branchId)) {
    return c.json({ error: "forbidden" }, 403);
  }
  return c.json({ entry: presentEntry(row.entry, row.presenterName, row.branchName) });
});

// a presenter reads its own rows; an admin reads its branch; the superadmin all.
function canReadEntry(me: AuthUser, presenterId: number, branchId: number): boolean {
  if (me.role === "superadmin") return true;
  if (me.role === "admin") return me.branchId === branchId;
  return me.id === presenterId;
}

// approving is the branch admin's job by default; the superadmin can step in
// for any branch when an admin is away.
entryRoutes.post("/:id/approve", requireAdmin, async (c) => {
  const id = entryIdSchema.safeParse(c.req.param("id"));
  if (!id.success) return c.json({ error: id.error.flatten() }, 422);

  const existing = await db(c.env.DB).query.salesEntries.findFirst({
    where: eq(salesEntries.id, id.data),
  });
  if (!existing) return c.json({ error: "entry not found" }, 404);
  resolveBranchScope(c.get("user"), existing.branchId);
  if (existing.status === "approved") return c.json({ error: "entry already approved" }, 409);

  const updated = await db(c.env.DB)
    .update(salesEntries)
    .set({
      status: "approved",
      approvedAt: Date.now(),
      approvedBy: c.get("user").id,
    })
    .where(and(eq(salesEntries.id, id.data), eq(salesEntries.status, "pending")))
    .returning();
  if (!updated[0]) return c.json({ error: "entry already approved" }, 409);

  return c.json({ entry: presentEntry(updated[0]) });
});
