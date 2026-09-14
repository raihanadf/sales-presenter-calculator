import { drizzle } from "drizzle-orm/d1";
import * as schema from "./schema";

// wraps the d1 binding in a typed drizzle client.
export function db(d1: D1Database) {
  return drizzle(d1, { schema });
}
