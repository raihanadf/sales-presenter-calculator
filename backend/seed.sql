-- default admin (username: admin / password: admin123 -- change after first login)
INSERT OR IGNORE INTO users (id, name, username, password_hash, role, created_at)
VALUES (1, 'Administrator', 'admin', 'pbkdf2$100000$8BreIVpCbjaZnEEso2UbiA==$PclJvcJ4QGQed0EHisKwrM/a9fCiZN/N+8Y6t+hFhLE=', 'admin', 1789375355581);

-- fixed calculation values from the original spec.
INSERT OR IGNORE INTO settings (id, closing_price, bop_percent, souvenir_unit_price, souvenir_percent, harian_default, updated_at)
VALUES (1, 81000, 60, 6000, 60, 100000, 1789375355581);
