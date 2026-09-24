import { z } from "zod";

// boundary dtos. all validation lives here, never inline in handlers.

export const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
});

// branchId is required for superadmin (it has no branch of its own) and
// ignored for a branch admin, who may only create inside its own branch.
export const createPresenterSchema = z.object({
  name: z.string().min(1),
  username: z.string().min(3).max(50),
  password: z.string().min(6),
  branchId: z.number().int().positive().optional(),
});

// superadmin-only: move a presenter to another branch. past entries keep the
// branch they were recorded in.
export const movePresenterSchema = z.object({
  branchId: z.number().int().positive(),
});

// the five money values a branch runs on. shared by branch creation and the
// settings update, so a branch can never exist without them.
const branchSettingsSchema = z.object({
  closingPrice: z.number().int().nonnegative(),
  bopPercent: z.number().int().min(0).max(100),
  souvenirUnitPrice: z.number().int().nonnegative(),
  souvenirPercent: z.number().int().min(0).max(100),
  harianDefault: z.number().int().nonnegative(),
});

// creating a branch also creates its first admin account, in one transaction.
export const createBranchSchema = z.object({
  name: z.string().min(1).max(100),
  settings: branchSettingsSchema,
  admin: z.object({
    name: z.string().min(1),
    username: z.string().min(3).max(50),
  }),
});

export const updateBranchSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  active: z.boolean().optional(),
});

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: z.string().min(6),
});

export const updateSettingsSchema = branchSettingsSchema;

// optional branch filter. superadmin may span every branch by omitting it;
// anyone else may only ever name their own.
export const branchQuerySchema = z.object({
  branchId: z.coerce.number().int().positive().optional(),
});

// harian optional -> falls back to settings default in the handler (explicit,
// not a silent papering-over of missing data).
// clientId is required: it is what makes a resend safe. allowDuplicate is set
// only after the person confirmed that an identical closing is intentional.
export const entryInputSchema = z.object({
  clientId: z.string().min(16).max(64),
  allowDuplicate: z.boolean().optional(),
  presenterId: z.number().int().positive().optional(),
  entryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  closingCount: z.number().int().nonnegative(),
  bopInput: z.number().int().nonnegative(),
  audienceCount: z.number().int().nonnegative(),
  harian: z.number().int().nonnegative().optional(),
});

// preview needs only the numeric inputs, no date/presenter.
export const previewSchema = z.object({
  closingCount: z.number().int().nonnegative(),
  bopInput: z.number().int().nonnegative(),
  audienceCount: z.number().int().nonnegative(),
  harian: z.number().int().nonnegative().optional(),
});

// admin excel import: many rows for one presenter. harian optional per row,
// falls back to the settings default in the handler.
export const bulkImportSchema = z.object({
  presenterId: z.number().int().positive(),
  rows: z
    .array(
      z.object({
        entryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
        closingCount: z.number().int().nonnegative(),
        bopInput: z.number().int().nonnegative(),
        audienceCount: z.number().int().nonnegative(),
        harian: z.number().int().nonnegative().optional(),
      }),
    )
    .min(1)
    .max(200),
});

// month recap export takes a yyyy-mm period.
export const monthQuerySchema = z.object({
  month: z.string().regex(/^\d{4}-\d{2}$/),
  branchId: z.coerce.number().int().positive().optional(),
});

export const entryListQuerySchema = z.object({
  presenterId: z.coerce.number().int().positive().optional(),
  branchId: z.coerce.number().int().positive().optional(),
  from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  page: z.coerce.number().int().positive().default(1),
});

export const entryIdSchema = z.coerce.number().int().positive();

export type LoginDto = z.infer<typeof loginSchema>;
export type CreatePresenterDto = z.infer<typeof createPresenterSchema>;
export type UpdateSettingsDto = z.infer<typeof updateSettingsSchema>;
export type EntryInputDto = z.infer<typeof entryInputSchema>;
export type PreviewDto = z.infer<typeof previewSchema>;
export type BulkImportDto = z.infer<typeof bulkImportSchema>;
export type MonthQueryDto = z.infer<typeof monthQuerySchema>;
export type CreateBranchDto = z.infer<typeof createBranchSchema>;
export type UpdateBranchDto = z.infer<typeof updateBranchSchema>;
export type MovePresenterDto = z.infer<typeof movePresenterSchema>;
export type ChangePasswordDto = z.infer<typeof changePasswordSchema>;
