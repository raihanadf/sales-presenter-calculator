ALTER TABLE `sales_entries` ADD `status` text DEFAULT 'approved' NOT NULL;--> statement-breakpoint
ALTER TABLE `sales_entries` ADD `closing_price_used` integer;--> statement-breakpoint
ALTER TABLE `sales_entries` ADD `bop_percent_used` integer;--> statement-breakpoint
ALTER TABLE `sales_entries` ADD `souvenir_unit_price_used` integer;--> statement-breakpoint
ALTER TABLE `sales_entries` ADD `souvenir_percent_used` integer;--> statement-breakpoint
ALTER TABLE `sales_entries` ADD `approved_at` integer;--> statement-breakpoint
ALTER TABLE `sales_entries` ADD `approved_by` integer REFERENCES users(id);