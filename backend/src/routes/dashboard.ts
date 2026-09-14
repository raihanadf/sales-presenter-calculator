import { Hono } from "hono";
import { eq, and, gte, lte, sql, desc } from "drizzle-orm";
import { db } from "../db/client";
import { salesEntries, users } from "../db/schema";
import type { Env } from "../types";

export const dashboardRoutes = new Hono<Env>();

// homepage figures: today's income, this-month recap per presenter, top 3.
// ?date=yyyy-mm-dd and ?month=yyyy-mm let the client pass its local period so
// figures match the user's timezone instead of the worker's utc clock.
dashboardRoutes.get("/", async (c) => {
  const now = new Date();
  const date = c.req.query("date") ?? now.toISOString().slice(0, 10);
  const month = c.req.query("month") ?? date.slice(0, 7);
  const monthFrom = `${month}-01`;
  const monthTo = `${month}-31`;
  const d = db(c.env.DB);

  const todayRows = await d
    .select({ total: sql<number>`coalesce(sum(${salesEntries.takeHome}), 0)` })
    .from(salesEntries)
    .where(eq(salesEntries.entryDate, date));

  const perPresenter = await d
    .select({
      presenterId: users.id,
      presenterName: users.name,
      total: sql<number>`coalesce(sum(${salesEntries.takeHome}), 0)`,
      entries: sql<number>`count(${salesEntries.id})`,
    })
    .from(salesEntries)
    .innerJoin(users, eq(users.id, salesEntries.presenterId))
    .where(and(gte(salesEntries.entryDate, monthFrom), lte(salesEntries.entryDate, monthTo)))
    .groupBy(users.id, users.name)
    .orderBy(desc(sql`sum(${salesEntries.takeHome})`));

  const monthTotal = perPresenter.reduce((sum, r) => sum + r.total, 0);

  return c.json({
    date,
    month,
    todayIncome: todayRows[0].total,
    monthIncome: monthTotal,
    top3: perPresenter.slice(0, 3),
    monthRecap: perPresenter,
  });
});

// personal figures for the logged-in presenter: own income, closing count,
// average, best closing, last-7-day trend, recent history, and month rank.
dashboardRoutes.get("/me", async (c) => {
  const me = c.get("user");
  const now = new Date();
  const date = c.req.query("date") ?? now.toISOString().slice(0, 10);
  const month = c.req.query("month") ?? date.slice(0, 7);
  const monthFrom = `${month}-01`;
  const monthTo = `${month}-31`;
  const d = db(c.env.DB);

  // all my entries this month, newest first.
  const mine = await d
    .select()
    .from(salesEntries)
    .where(
      and(
        eq(salesEntries.presenterId, me.id),
        gte(salesEntries.entryDate, monthFrom),
        lte(salesEntries.entryDate, monthTo),
      ),
    )
    .orderBy(desc(salesEntries.entryDate), desc(salesEntries.id));

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

  // my rank this month among all presenters, by take-home.
  const ranked = await d
    .select({
      presenterId: salesEntries.presenterId,
      total: sql<number>`sum(${salesEntries.takeHome})`,
    })
    .from(salesEntries)
    .where(and(gte(salesEntries.entryDate, monthFrom), lte(salesEntries.entryDate, monthTo)))
    .groupBy(salesEntries.presenterId)
    .orderBy(desc(sql`sum(${salesEntries.takeHome})`));
  const rank = ranked.findIndex((r) => r.presenterId === me.id);

  return c.json({
    date,
    month,
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
    recent: mine.slice(0, 5).map((e) => ({
      id: e.id,
      entryDate: e.entryDate,
      closingCount: e.closingCount,
      takeHome: e.takeHome,
    })),
  });
});
