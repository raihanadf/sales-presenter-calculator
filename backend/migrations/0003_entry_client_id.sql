ALTER TABLE `sales_entries` ADD `client_id` text;--> statement-breakpoint
CREATE UNIQUE INDEX `sales_entries_client_id_unique` ON `sales_entries` (`client_id`);
