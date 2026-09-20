import { Hono } from "hono";
import { cors } from "hono/cors";
import { requireAuth } from "./middleware/auth";
import { requireAppVersion } from "./middleware/version";
import { authRoutes } from "./routes/auth";
import { accountRoutes } from "./routes/account";
import { branchRoutes } from "./routes/branches";
import { userRoutes } from "./routes/users";
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

// everything below requires a valid token, and a writable app build.
app.use("/api/*", requireAuth);
app.use("/api/*", requireAppVersion);
app.route("/api/me", accountRoutes);
app.route("/api/branches", branchRoutes);
app.route("/api/users", userRoutes);
app.route("/api/presenters", presenterRoutes);
app.route("/api/settings", settingsRoutes);
app.route("/api/entries", entryRoutes);
app.route("/api/dashboard", dashboardRoutes);

app.onError((err, c) => {
  console.error(err);
  return c.json({ error: err.message }, 500);
});

export default app;
