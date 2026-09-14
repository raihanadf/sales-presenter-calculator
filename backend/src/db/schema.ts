import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";

// accounts. admin creates presenters; role gates admin-only routes.
export const users = sqliteTable("users", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  name: text("name").notNull(),
  username: text("username").notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  role: text("role", { enum: ["admin", "presenter"] }).notNull().default("presenter"),
  createdAt: integer("created_at").notNull(),
});

// singleton row (id=1) holding the fixed calculation values, admin-editable.
export const settings = sqliteTable("settings", {
  id: integer("id").primaryKey(),
  closingPrice: integer("closing_price").notNull(),
  bopPercent: integer("bop_percent").notNull(),
  souvenirUnitPrice: integer("souvenir_unit_price").notNull(),
  souvenirPercent: integer("souvenir_percent").notNull(),
  harianDefault: integer("harian_default").notNull(),
  updatedAt: integer("updated_at").notNull(),
});

// one row = one presenter's daily closing recap. computed columns are
// snapshotted at write time so later settings changes never rewrite history.
export const salesEntries = sqliteTable("sales_entries", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  presenterId: integer("presenter_id")
    .notNull()
    .references(() => users.id),
  entryDate: text("entry_date").notNull(), // iso yyyy-mm-dd
  closingCount: integer("closing_count").notNull(),
  bopInput: integer("bop_input").notNull(),
  audienceCount: integer("audience_count").notNull(),
  harian: integer("harian").notNull(),
  closingTotal: integer("closing_total").notNull(),
  bopValue: integer("bop_value").notNull(),
  souvenirValue: integer("souvenir_value").notNull(),
  takeHome: integer("take_home").notNull(),
  createdAt: integer("created_at").notNull(),
});

export type User = typeof users.$inferSelect;
export type Settings = typeof settings.$inferSelect;
export type SalesEntry = typeof salesEntries.$inferSelect;
