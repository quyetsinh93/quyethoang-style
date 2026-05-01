CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    price REAL NOT NULL,
    description TEXT,
    stock_quantity INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    zalo TEXT,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL,
    FOREIGN KEY(customer_id) REFERENCES customers(id),
    FOREIGN KEY(product_id) REFERENCES products(id)
);

INSERT INTO products (name, price, description, stock_quantity) VALUES ('Style Audit Online', 299000, 'Tư vấn chấm điểm style qua video', 100);
INSERT INTO products (name, price, description, stock_quantity) VALUES ('Capsule Wardrobe Template', 99000, 'Tài liệu danh sách 20 items cốt lõi của phái mạnh', 999);

INSERT INTO customers (name, phone, zalo, created_at) VALUES ('Minh Khang', '0901234567', 'https://zalo.me/0901234567', '2026-04-15 08:30:00');
INSERT INTO customers (name, phone, zalo, created_at) VALUES ('Tuấn Phong', '0987654321', 'https://zalo.me/0987654321', '2026-04-18 15:45:00');
INSERT INTO customers (name, phone, zalo, created_at) VALUES ('Hoàng Nam', '0912341234', 'https://zalo.me/0912341234', '2026-04-19 10:15:00');
