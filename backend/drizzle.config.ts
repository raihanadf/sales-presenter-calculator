import type { Config } from "drizzle-kit";

// generates sqlite migrations into ./migrations for d1
export default {
  schema: "./src/db/schema.ts",
  out: "./migrations",
  dialect: "sqlite",
} satisfies Config;
