import { Hono } from "hono";
import { cors } from "hono/cors";
import { requireAuth } from "./middleware/auth";
import { authRoutes } from "./routes/auth";
import { presenterRoutes } from "./routes/presenters";
import { settingsRoutes } from "./routes/settings";
import { entryRoutes } from "./routes/entries";
import { dashboardRoutes } from "./routes/dashboard";
import type { Env } from "./types";

const app = new Hono<Env>();

app.use("*", cors());
app.get("/", (c) => c.json({ service: "sales-presenter-backend", ok: true }));

// public
app.route("/auth", authRoutes);

// everything below requires a valid token.
app.use("/api/*", requireAuth);
app.route("/api/presenters", presenterRoutes);
app.route("/api/settings", settingsRoutes);
app.route("/api/entries", entryRoutes);
app.route("/api/dashboard", dashboardRoutes);

app.onError((err, c) => {
  console.error(err);
  return c.json({ error: err.message }, 500);
});

export default app;
