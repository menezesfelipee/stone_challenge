BEGIN;

-- Criação da tabela de clientes
CREATE TABLE customer (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Função usada para preencher automaticamente a coluna updated_at na ação de update
CREATE FUNCTION fill_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language plpgsql;

-- Usando função criada acima como trigger na tabela customer
CREATE TRIGGER fill_updated_at_in_customer
BEFORE UPDATE ON customer
FOR EACH ROW EXECUTE PROCEDURE fill_updated_at();

-- Criação da tabela para armazenar as agências
CREATE TABLE agency (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

-- Inserindo uma agência para usar nesse desafio
INSERT INTO agency (name) VALUES ('Virtual Agency');

-- Criação da tabela de contas (seria possível um cliente possuir diversas contas)
CREATE TABLE account (
    internal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id SERIAL NOT NULL,
    agency_id INTEGER NOT NULL REFERENCES agency(id) ON DELETE SET NULL,
    customer_id UUID NOT NULL REFERENCES customer(id) ON DELETE CASCADE,
    balance BIGINT DEFAULT 0,
    opening_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    close_date TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT false,
    activation_date TIMESTAMP
);

-- Criação da tabela dos tipos de movimentação
CREATE TABLE movement_type (
    id INTEGER PRIMARY KEY,
    name VARCHAR(40) NOT NULL,
    direction VARCHAR(3) NOT NULL CHECK (direction IN ('in', 'out')),
    UNIQUE (name, direction)
);

-- Inserindo os tipos de movimentação
INSERT INTO movement_type
VALUES
    (1, 'deposit', 'in'),
    (2, 'withdraw', 'out'),
    (3, 'transfer', 'in'),
    (4, 'transfer', 'out'),
    (5, 'invoice', 'out');

-- Criação da tabela que registra as movimentações financeiras
CREATE TABLE movement (
    operation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type INTEGER NOT NULL REFERENCES movement_type(id) ON DELETE SET NULL,
    amount BIGINT NOT NULL CHECK (amount >= 0),
    internal_account_id UUID NOT NULL REFERENCES account(internal_id),
    out_data JSONB,
    execution_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Trigger usado para validar a operação, caso não tenha saldo não será concretizada
CREATE FUNCTION validate_movement() RETURNS TRIGGER AS $$
DECLARE
    is_in BOOLEAN;
    final_balance INTEGER;
BEGIN
    IF NEW.type = 4
        AND (
            NEW.out_data IS NULL
            OR NOT NEW.out_data ? 'agency_id'
            OR NOT NEW.out_data ? 'account_id'
            OR NOT NEW.out_data ? 'document'
        )
    THEN
        RAISE EXCEPTION 'Missing recipient data';
    END IF;

    IF NEW.type = 5
        AND (
            NEW.out_data IS NULL
            OR NOT NEW.out_data ? 'invoice_code'
        )
    THEN
        RAISE EXCEPTION 'Missing invoice code';
    END IF;

    is_in := (SELECT direction = 'in' FROM movement_type WHERE id = NEW.type);

    final_balance :=  (
        SELECT
            CASE WHEN is_in THEN
                    balance + NEW.amount
                ELSE
                    balance - NEW.amount
            END
        FROM account
        WHERE internal_id = NEW.internal_account_id
    );

    IF final_balance < 0 THEN
        RAISE EXCEPTION 'Insuficient funds';
    END IF;

    RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER validate_movement
BEFORE INSERT ON movement
FOR EACH ROW EXECUTE PROCEDURE validate_movement();

-- Trigger usado para atualizar automaticamente o saldo na conta do cliente após a operação ser realizada
CREATE FUNCTION update_balance_on_movement() RETURNS TRIGGER AS $$
DECLARE
    is_in BOOLEAN;
BEGIN
    is_in := (SELECT direction = 'in' FROM movement_type WHERE id = NEW.type);
    UPDATE account
    SET balance = (
        CASE WHEN is_in THEN
                balance + NEW.amount
            ELSE
                balance - NEW.amount
        END
    )
    WHERE internal_id = NEW.internal_account_id;

    RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER update_balance_on_movement
AFTER INSERT ON movement
FOR EACH ROW EXECUTE PROCEDURE update_balance_on_movement();

-- Query para calcular o valor total em boletos em cada mês do ano atual
CREATE VIEW invoice_amount_per_month_in_current_year AS (
    WITH actual_year AS (
        SELECT
            serie _month
        FROM
            generate_series(
                date_trunc('year', CURRENT_TIMESTAMP),
                date_trunc('year', CURRENT_TIMESTAMP) + Interval '11 months',
                '1 month'
            ) serie
    ), actual_year_records AS (
        SELECT
            date_trunc('month', execution_date) execution_month,
            SUM(amount) monthly_amount
        FROM movement
        WHERE
            type = 5
            AND extract('year' FROM execution_date) = extract('year' FROM CURRENT_DATE)
        GROUP BY execution_month
    )
    SELECT
        "A"._month::DATE _month,
        COALESCE("B".monthly_amount, 0) amount
    FROM actual_year "A"
    LEFT OUTER JOIN actual_year_records "B" ON "A"._month = "B".execution_month
);

-- Index criado para otimizar a query acima
CREATE INDEX idx_type_date ON movement (type, extract('year' FROM execution_date));

-- Função para gerar um dia aleatório no ano atual
CREATE FUNCTION random_day_in_current_year() RETURNS TIMESTAMP AS $$
DECLARE random_timestamp TIMESTAMP;
BEGIN
    random_timestamp := (
        SELECT *
        FROM
            generate_series(
                date_trunc('year', CURRENT_TIMESTAMP),
                date_trunc('year', CURRENT_TIMESTAMP + Interval '1 year') - Interval '1 day',
                '1 day'
            ) q
        ORDER BY random()
        LIMIT 1
    );
    RETURN random_timestamp;
END;
$$ language 'plpgsql';

-- Inserindo alguns dados para exemplificação
INSERT INTO customer (id, name, email)
VALUES
    ('7ed35149-ba7e-4a7c-ae9f-95f94c0504d4', 'Alfredo', 'alfredo@alfredo.com'),
    ('fcc13a5c-0185-4740-b4dd-99b81ecf9a81', 'Bernardo', 'bernardo@bernardo.com'),
    ('2c292f73-a2af-4848-9933-ac55f2f493d5', 'Caio', 'caio@caio.com');

INSERT INTO account (internal_id, agency_id, customer_id, is_active, activation_date)
VALUES
    ('8782bbeb-7119-4b48-bd1a-39051c57b695', 1, 'fcc13a5c-0185-4740-b4dd-99b81ecf9a81', true, CURRENT_TIMESTAMP),
    ('8f5790be-1809-4e16-98cd-37ffc6a7f890', 1, '7ed35149-ba7e-4a7c-ae9f-95f94c0504d4', true, CURRENT_TIMESTAMP),
    ('8dd89be2-e372-451c-8b0e-9a6a50c7f06c', 1, '2c292f73-a2af-4848-9933-ac55f2f493d5', true, CURRENT_TIMESTAMP),
    ('94e088a4-fd1e-41c9-a4dc-96e57204aff5', 1, 'fcc13a5c-0185-4740-b4dd-99b81ecf9a81', true, CURRENT_TIMESTAMP),
    ('147ff387-8972-43c3-b8f0-d3f64b2fa51f', 1, 'fcc13a5c-0185-4740-b4dd-99b81ecf9a81', true, CURRENT_TIMESTAMP),
    ('922e50d9-7063-4bfa-9895-b0b3a82590e5', 1, '7ed35149-ba7e-4a7c-ae9f-95f94c0504d4', true, CURRENT_TIMESTAMP);

INSERT INTO movement (type, amount, internal_account_id, execution_date)
VALUES (1, 500000, '8782bbeb-7119-4b48-bd1a-39051c57b695', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, execution_date)
VALUES (1, 786547, '8f5790be-1809-4e16-98cd-37ffc6a7f890', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, execution_date)
VALUES (1, 100005, '8dd89be2-e372-451c-8b0e-9a6a50c7f06c', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, execution_date)
VALUES (1, 789051, '94e088a4-fd1e-41c9-a4dc-96e57204aff5', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, execution_date)
VALUES (1, 200000, '147ff387-8972-43c3-b8f0-d3f64b2fa51f', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, execution_date)
VALUES (1, 2675411, '922e50d9-7063-4bfa-9895-b0b3a82590e5', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 5000, '8782bbeb-7119-4b48-bd1a-39051c57b695', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, execution_date)
VALUES (2, 200, '8f5790be-1809-4e16-98cd-37ffc6a7f890', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (4, 3000, '147ff387-8972-43c3-b8f0-d3f64b2fa51f', '{"agency_id": 1234, "account_id": 97654378, "document": 11972570987}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 9876, '8dd89be2-e372-451c-8b0e-9a6a50c7f06c', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 6754, '147ff387-8972-43c3-b8f0-d3f64b2fa51f', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 1000, '8782bbeb-7119-4b48-bd1a-39051c57b695', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 1000, '8f5790be-1809-4e16-98cd-37ffc6a7f890', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 1000, '922e50d9-7063-4bfa-9895-b0b3a82590e5', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 365, '8782bbeb-7119-4b48-bd1a-39051c57b695', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 2856, '8f5790be-1809-4e16-98cd-37ffc6a7f890', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 33258, '94e088a4-fd1e-41c9-a4dc-96e57204aff5', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 36205, '8782bbeb-7119-4b48-bd1a-39051c57b695', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 1111, '8f5790be-1809-4e16-98cd-37ffc6a7f890', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 98754, '8782bbeb-7119-4b48-bd1a-39051c57b695', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 10000, '922e50d9-7063-4bfa-9895-b0b3a82590e5', '{"invoice_code": 12345}', random_day_in_current_year());

INSERT INTO movement (type, amount, internal_account_id, out_data, execution_date)
VALUES (5, 9000, '8782bbeb-7119-4b48-bd1a-39051c57b695', '{"invoice_code": 12345}', random_day_in_current_year());

COMMIT;