CREATE TABLE `branches` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`name` text NOT NULL,
	`active` integer DEFAULT true NOT NULL,
	`created_at` integer NOT NULL
);--> statement-breakpoint
CREATE UNIQUE INDEX `branches_name_unique` ON `branches` (`name`);--> statement-breakpoint
INSERT INTO `branches` (`id`, `name`, `active`, `created_at`) VALUES (1, 'Cabang Utama', 1, unixepoch() * 1000);--> statement-breakpoint
CREATE TABLE `settings_new` (
	`branch_id` integer PRIMARY KEY NOT NULL,
	`closing_price` integer NOT NULL,
	`bop_percent` integer NOT NULL,
	`souvenir_unit_price` integer NOT NULL,
	`souvenir_percent` integer NOT NULL,
	`harian_default` integer NOT NULL,
	`updated_at` integer NOT NULL,
	FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON UPDATE no action ON DELETE no action
);--> statement-breakpoint
INSERT INTO `settings_new` SELECT 1, `closing_price`, `bop_percent`, `souvenir_unit_price`, `souvenir_percent`, `harian_default`, `updated_at` FROM `settings` WHERE `id` = 1;--> statement-breakpoint
DROP TABLE `settings`;--> statement-breakpoint
ALTER TABLE `settings_new` RENAME TO `settings`;--> statement-breakpoint
ALTER TABLE `users` ADD `branch_id` integer REFERENCES branches(id);--> statement-breakpoint
UPDATE `users` SET `role` = 'superadmin', `branch_id` = NULL WHERE `id` = 1 AND `role` = 'admin';--> statement-breakpoint
UPDATE `users` SET `branch_id` = 1 WHERE `role` <> 'superadmin';--> statement-breakpoint
CREATE TRIGGER `users_branch_required_insert` BEFORE INSERT ON `users`
WHEN NEW.`role` <> 'superadmin' AND NEW.`branch_id` IS NULL
BEGIN SELECT RAISE(ABORT, 'branch_id is required unless role is superadmin'); END;--> statement-breakpoint
CREATE TRIGGER `users_branch_required_update` BEFORE UPDATE ON `users`
WHEN NEW.`role` <> 'superadmin' AND NEW.`branch_id` IS NULL
BEGIN SELECT RAISE(ABORT, 'branch_id is required unless role is superadmin'); END;--> statement-breakpoint
CREATE TABLE `sales_entries_new` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`presenter_id` integer NOT NULL,
	`branch_id` integer NOT NULL,
	`entry_date` text NOT NULL,
	`status` text DEFAULT 'approved' NOT NULL,
	`closing_count` integer NOT NULL,
	`bop_input` integer NOT NULL,
	`audience_count` integer NOT NULL,
	`harian` integer NOT NULL,
	`closing_price_used` integer,
	`bop_percent_used` integer,
	`souvenir_unit_price_used` integer,
	`souvenir_percent_used` integer,
	`closing_total` integer NOT NULL,
	`bop_value` integer NOT NULL,
	`souvenir_value` integer NOT NULL,
	`take_home` integer NOT NULL,
	`approved_at` integer,
	`approved_by` integer,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`presenter_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`approved_by`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action
);--> statement-breakpoint
INSERT INTO `sales_entries_new` (`id`, `presenter_id`, `branch_id`, `entry_date`, `status`, `closing_count`, `bop_input`, `audience_count`, `harian`, `closing_price_used`, `bop_percent_used`, `souvenir_unit_price_used`, `souvenir_percent_used`, `closing_total`, `bop_value`, `souvenir_value`, `take_home`, `approved_at`, `approved_by`, `created_at`)
SELECT `id`, `presenter_id`, 1, `entry_date`, `status`, `closing_count`, `bop_input`, `audience_count`, `harian`, `closing_price_used`, `bop_percent_used`, `souvenir_unit_price_used`, `souvenir_percent_used`, `closing_total`, `bop_value`, `souvenir_value`, `take_home`, `approved_at`, `approved_by`, `created_at`
FROM `sales_entries`;--> statement-breakpoint
DROP TABLE `sales_entries`;--> statement-breakpoint
ALTER TABLE `sales_entries_new` RENAME TO `sales_entries`;--> statement-breakpoint
CREATE INDEX `sales_entries_branch_date_idx` ON `sales_entries` (`branch_id`, `entry_date`);--> statement-breakpoint
CREATE INDEX `sales_entries_presenter_idx` ON `sales_entries` (`presenter_id`);
