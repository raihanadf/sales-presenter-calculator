-- first branch. every account except the superadmin belongs to one.
INSERT OR IGNORE INTO branches (id, name, active, created_at)
VALUES (1, 'Cabang Utama', 1, 1789375355581);

-- calculation values for that branch, from the original spec.
INSERT OR IGNORE INTO settings (branch_id, closing_price, bop_percent, souvenir_unit_price, souvenir_percent, harian_default, updated_at)
VALUES (1, 81000, 60, 6000, 60, 100000, 1789375355581);

-- owner account, no branch of its own (username: admin / password: admin123 -- change after first login)
INSERT OR IGNORE INTO users (id, name, username, password_hash, role, branch_id, created_at)
VALUES (1, 'Administrator', 'admin', 'pbkdf2$100000$8BreIVpCbjaZnEEso2UbiA==$PclJvcJ4QGQed0EHisKwrM/a9fCiZN/N+8Y6t+hFhLE=', 'superadmin', NULL, 1789375355581);
