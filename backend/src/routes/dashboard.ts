import { Hono } from "hono";
import { eq, and, gte, lte, sql, desc } from "drizzle-orm";
import { db } from "../db/client";
import { salesEntries, users, branches } from "../db/schema";
import { resolveBranchScope } from "../lib/scope";
import { branchQuerySchema } from "../validation/schemas";
import type { Env } from "../types";
import { presentEntry } from "../serializers";

export const dashboardRoutes = new Hono<Env>();

// homepage figures: today's income, this-month recap per presenter, top 3.
// ?date=yyyy-mm-dd and ?month=yyyy-mm let the client pass its local period so
// figures match the user's timezone instead of the worker's utc clock.
// ?branchId lets the superadmin drill into one branch; without it the figures
// span every branch and perBranch ranks the branches against each other.
dashboardRoutes.get("/", async (c) => {
  const query = branchQuerySchema.safeParse(c.req.query());
  if (!query.success) return c.json({ error: query.error.flatten() }, 422);
  const scope = resolveBranchScope(c.get("user"), query.data.branchId);

  const now = new Date();
  const date = c.req.query("date") ?? now.toISOString().slice(0, 10);
  const month = c.req.query("month") ?? date.slice(0, 7);
  const monthFrom = `${month}-01`;
  const monthTo = `${month}-31`;
  const d = db(c.env.DB);
  const inScope = (extra: ReturnType<typeof eq>[]) =>
    and(...extra, ...(scope === null ? [] : [eq(salesEntries.branchId, scope)]));

  const todayRows = await d
    .select({ total: sql<number>`coalesce(sum(${salesEntries.takeHome}), 0)` })
    .from(salesEntries)
    .where(inScope([eq(salesEntries.entryDate, date), eq(salesEntries.status, "approved")]));

  const monthFilters = [
    gte(salesEntries.entryDate, monthFrom),
    lte(salesEntries.entryDate, monthTo),
    eq(salesEntries.status, "approved"),
  ];

  const perPresenter = await d
    .select({
      presenterId: users.id,
      presenterName: users.name,
      branchName: branches.name,
      total: sql<number>`coalesce(sum(${salesEntries.takeHome}), 0)`,
      entries: sql<number>`count(${salesEntries.id})`,
    })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .innerJoin(branches, eq(branches.id, salesEntries.branchId))
    .where(inScope(monthFilters))
    .groupBy(users.id, users.name, branches.name)
    .orderBy(desc(sql`sum(${salesEntries.takeHome})`));

  // branch-against-branch ranking. only meaningful while spanning every branch.
  const perBranch =
    scope === null
      ? await d
          .select({
            branchId: branches.id,
            branchName: branches.name,
            total: sql<number>`coalesce(sum(${salesEntries.takeHome}), 0)`,
            entries: sql<number>`count(${salesEntries.id})`,
          })
          .from(salesEntries)
          .innerJoin(branches, eq(branches.id, salesEntries.branchId))
          .where(and(...monthFilters))
          .groupBy(branches.id, branches.name)
          .orderBy(desc(sql`sum(${salesEntries.takeHome})`))
      : [];

  const monthTotal = perPresenter.reduce((sum, r) => sum + r.total, 0);
  const pending = await d
    .select({ entry: salesEntries, presenterName: users.name, branchName: branches.name })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .innerJoin(branches, eq(branches.id, salesEntries.branchId))
    .where(inScope([eq(salesEntries.status, "pending")]))
    .orderBy(desc(salesEntries.createdAt));

  return c.json({
    date,
    month,
    branchId: scope,
    todayIncome: todayRows[0].total,
    monthIncome: monthTotal,
    top3: perPresenter.slice(0, 3),
    monthRecap: perPresenter,
    perBranch,
    pending: pending.map((row) => presentEntry(row.entry, row.presenterName, row.branchName)),
  });
});

// personal figures for the logged-in presenter: own income, closing count,
// average, best closing, last-7-day trend, recent history, and month rank.
// income and rank cover the branch the presenter works in now; the history
// list spans every branch, because that is their own past pay.
dashboardRoutes.get("/me", async (c) => {
  const me = c.get("user");
  if (me.branchId === null) return c.json({ error: "account has no branch" }, 422);

  const now = new Date();
  const date = c.req.query("date") ?? now.toISOString().slice(0, 10);
  const month = c.req.query("month") ?? date.slice(0, 7);
  const monthFrom = `${month}-01`;
  const monthTo = `${month}-31`;
  const d = db(c.env.DB);

  // approved entries own every income statistic.
  const mine = await d
    .select()
    .from(salesEntries)
    .where(
      and(
        eq(salesEntries.presenterId, me.id),
        eq(salesEntries.branchId, me.branchId),
        gte(salesEntries.entryDate, monthFrom),
        lte(salesEntries.entryDate, monthTo),
        eq(salesEntries.status, "approved"),
      ),
    )
    .orderBy(desc(salesEntries.entryDate), desc(salesEntries.id));

  // pending rows stay visible while waiting for admin approval.
  const recent = await d
    .select({ entry: salesEntries, branchName: branches.name })
    .from(salesEntries)
    .innerJoin(branches, eq(branches.id, salesEntries.branchId))
    .where(eq(salesEntries.presenterId, me.id))
    .orderBy(desc(salesEntries.entryDate), desc(salesEntries.id))
    .limit(10);

  const monthIncome = mine.reduce((s, e) => s + e.takeHome, 0);
  const monthClosings = mine.reduce((s, e) => s + e.closingCount, 0);
  const todayIncome = mine.filter((e) => e.entryDate === date).reduce((s, e) => s + e.takeHome, 0);
  const avgPerClosing = monthClosings > 0 ? Math.round(monthIncome / monthClosings) : 0;
  const best = mine.reduce<typeof mine[number] | null>((b, e) => (b && b.takeHome >= e.takeHome ? b : e), null);

  // last 7 days ending at `date`, one bucket per day (zero-filled).
  const days: string[] = [];
  for (let i = 6; i >= 0; i--) {
    const dd = new Date(`${date}T00:00:00Z`);
    dd.setUTCDate(dd.getUTCDate() - i);
    days.push(dd.toISOString().slice(0, 10));
  }
  const trend = days.map((day) => ({
    date: day,
    income: mine.filter((e) => e.entryDate === day).reduce((s, e) => s + e.takeHome, 0),
  }));

  // my rank this month inside my own branch: the race i actually run.
  const ranked = await d
    .select({
      presenterId: salesEntries.presenterId,
      total: sql<number>`sum(${salesEntries.takeHome})`,
    })
    .from(salesEntries)
    .where(
      and(
        eq(salesEntries.branchId, me.branchId),
        gte(salesEntries.entryDate, monthFrom),
        lte(salesEntries.entryDate, monthTo),
        eq(salesEntries.status, "approved"),
      ),
    )
    .groupBy(salesEntries.presenterId)
    .orderBy(desc(sql`sum(${salesEntries.takeHome})`));
  const rank = ranked.findIndex((r) => r.presenterId === me.id);

  const branch = await d.query.branches.findFirst({ where: eq(branches.id, me.branchId) });

  return c.json({
    date,
    month,
    branchId: me.branchId,
    branchName: branch?.name ?? null,
    branchActive: me.branchActive,
    todayIncome,
    monthIncome,
    monthClosings,
    entryCount: mine.length,
    avgPerClosing,
    bestTakeHome: best?.takeHome ?? 0,
    bestDate: best?.entryDate ?? null,
    rank: rank >= 0 ? rank + 1 : null,
    totalPresenters: ranked.length,
    trend,
    recent: recent.map((r) => ({
      id: r.entry.id,
      entryDate: r.entry.entryDate,
      closingCount: r.entry.closingCount,
      takeHome: r.entry.takeHome,
      status: r.entry.status,
      branchName: r.branchName,
    })),
  });
});
