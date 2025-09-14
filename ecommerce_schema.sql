-- ecommerce_schema.sql

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_unicode_ci';
USE ecommerce_db;

--  productlines (lookup)
DROP TABLE IF EXISTS productlines;
CREATE TABLE productlines (
    productLine VARCHAR(50) NOT NULL PRIMARY KEY,
    textDescription VARCHAR(255),
    htmlDescription TEXT,
    image BLOB
) ENGINE=InnoDB;

--  products
DROP TABLE IF EXISTS products;
CREATE TABLE products (
    productID INT AUTO_INCREMENT PRIMARY KEY,
    productName VARCHAR(150) NOT NULL,
    productVendor VARCHAR(100) NOT NULL,
    productLine VARCHAR(50) NOT NULL,
    quantityInStock INT NOT NULL DEFAULT 0,
    buyPrice DECIMAL(10,2) NOT NULL,
    msrp DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_products_productline FOREIGN KEY (productLine) REFERENCES productlines(productLine)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    UNIQUE (productName, productVendor)
) ENGINE=InnoDB;

-- Index to speed lookups by vendor
CREATE INDEX idx_products_vendor ON products(productVendor);

-- customers 
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    customerID INT AUTO_INCREMENT PRIMARY KEY,
    customerName VARCHAR(120) NOT NULL,
    contactLastName VARCHAR(50),
    contactFirstName VARCHAR(50),
    phone VARCHAR(30),
    email VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (email)
) ENGINE=InnoDB;

-- addresses (one-to-many: customer -> addresses)
DROP TABLE IF EXISTS addresses;
CREATE TABLE addresses (
    addressID INT AUTO_INCREMENT PRIMARY KEY,
    customerID INT NOT NULL,
    addressLine1 VARCHAR(255) NOT NULL,
    addressLine2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postalCode VARCHAR(20),
    country VARCHAR(100),
    isBilling BOOL DEFAULT FALSE,
    isShipping BOOL DEFAULT TRUE,
    CONSTRAINT fk_addresses_customer FOREIGN KEY (customerID) REFERENCES customers(customerID)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- orders 
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    orderID INT AUTO_INCREMENT PRIMARY KEY,
    customerID INT NOT NULL,
    orderDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    shippedDate DATETIME,
    status ENUM('Pending','Processing','Shipped','Cancelled','Returned') NOT NULL DEFAULT 'Pending',
    comments TEXT,
    shippingAddressID INT,
    billingAddressID INT,
    CONSTRAINT fk_orders_customer FOREIGN KEY (customerID) REFERENCES customers(customerID)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_orders_shipaddr FOREIGN KEY (shippingAddressID) REFERENCES addresses(addressID)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_orders_billaddr FOREIGN KEY (billingAddressID) REFERENCES addresses(addressID)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- order_items (many-to-many: orders <-> products)
DROP TABLE IF EXISTS order_items;
CREATE TABLE order_items (
    orderID INT NOT NULL,
    productID INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unitPrice DECIMAL(10,2) NOT NULL, -- price at time of order
    PRIMARY KEY (orderID, productID),
    CONSTRAINT fk_items_order FOREIGN KEY (orderID) REFERENCES orders(orderID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_items_product FOREIGN KEY (productID) REFERENCES products(productID)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- employees (optional, for order handling)
DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
    employeeID INT AUTO_INCREMENT PRIMARY KEY,
    firstName VARCHAR(50) NOT NULL,
    lastName VARCHAR(50) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(30),
    managerID INT,
    CONSTRAINT fk_employees_manager FOREIGN KEY (managerID) REFERENCES employees(employeeID)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Example: assign orders to employees (one-to-many)
ALTER TABLE orders
    ADD COLUMN handledByEmployeeID INT NULL,
    ADD CONSTRAINT fk_orders_employee FOREIGN KEY (handledByEmployeeID) REFERENCES employees(employeeID)
        ON DELETE SET NULL ON UPDATE CASCADE;

-- audit table (optional)
DROP TABLE IF EXISTS order_audit;
CREATE TABLE order_audit (
    auditID INT AUTO_INCREMENT PRIMARY KEY,
    orderID INT NOT NULL,
    changedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changedBy VARCHAR(100),
    changeText TEXT,
    CONSTRAINT fk_audit_order FOREIGN KEY (orderID) REFERENCES orders(orderID)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--  Sample seed data (small) 
INSERT INTO productlines (productLine, textDescription) VALUES
('Laptops', 'Portable computers'),
('Accessories', 'Computer accessories and peripherals'),
('Phones', 'Smartphones and accessories');

INSERT INTO products (productName, productVendor, productLine, quantityInStock, buyPrice, msrp)
VALUES
('Ultrabook Pro 14', 'AcmeCorp', 'Laptops', 100, 700.00, 999.00),
('Wireless Mouse X1', 'MouseMakers', 'Accessories', 500, 10.00, 25.00),
('USB-C Charger', 'ChargeFast', 'Accessories', 300, 8.50, 19.99),
('PocketPhone Z', 'PhoneCo', 'Phones', 200, 250.00, 399.00);

INSERT INTO customers (customerName, contactLastName, contactFirstName, phone, email)
VALUES
('John Doe', 'Doe', 'John', '0712345678', 'john.doe@example.com'),
('Jane Smith', 'Smith', 'Jane', '0723456789', 'jane.smith@example.com');

INSERT INTO addresses (customerID, addressLine1, city, state, postalCode, country, isBilling, isShipping)
VALUES
(1, '12 Baker St', 'Nairobi', 'Nairobi County', '00100', 'Kenya', TRUE, TRUE),
(2, '45 High Rd', 'Nakuru', 'Nakuru County', '20100', 'Kenya', TRUE, TRUE);

INSERT INTO orders (customerID, orderDate, status, shippingAddressID, billingAddressID)
VALUES
(1, NOW(), 'Processing', 1, 1),
(2, NOW(), 'Pending', 2, 2);

-- Link items to orders
INSERT INTO order_items (orderID, productID, quantity, unitPrice)
VALUES
(1, 1, 1, 700.00),
(1, 2, 2, 10.00),
(2, 4, 1, 250.00);

-- Useful views / helper queries (optional)

DROP VIEW IF EXISTS vw_order_summary;
CREATE VIEW vw_order_summary AS
SELECT
  o.orderID,
  o.customerID,
  c.customerName,
  o.orderDate,
  o.status,
  SUM(oi.quantity * oi.unitPrice) AS order_total
FROM orders o
JOIN order_items oi USING(orderID)
JOIN customers c ON o.customerID = c.customerID
GROUP BY o.orderID;

