CREATE TABLE `sales_entries` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`presenter_id` integer NOT NULL,
	`entry_date` text NOT NULL,
	`closing_count` integer NOT NULL,
	`bop_input` integer NOT NULL,
	`audience_count` integer NOT NULL,
	`harian` integer NOT NULL,
	`closing_total` integer NOT NULL,
	`bop_value` integer NOT NULL,
	`souvenir_value` integer NOT NULL,
	`take_home` integer NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`presenter_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `settings` (
	`id` integer PRIMARY KEY NOT NULL,
	`closing_price` integer NOT NULL,
	`bop_percent` integer NOT NULL,
	`souvenir_unit_price` integer NOT NULL,
	`souvenir_percent` integer NOT NULL,
	`harian_default` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`name` text NOT NULL,
	`username` text NOT NULL,
	`password_hash` text NOT NULL,
	`role` text DEFAULT 'presenter' NOT NULL,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `users_username_unique` ON `users` (`username`);