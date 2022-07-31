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
            AND EXTRACT(year FROM execution_date) = EXTRACT(year FROM CURRENT_DATE)
        GROUP BY execution_month
    )
    SELECT
        "A"._month::DATE _month,
        COALESCE("B".monthly_amount, 0) amount
    FROM actual_year "A"
    LEFT OUTER JOIN actual_year_records "B" ON "A"._month = "B".execution_month
);

-- Index criado para otimizar a query acima
CREATE INDEX idx_type_date ON movement (type, EXTRACT(year FROM execution_date));

---------------------------------------------------------------------------------------------------------------

-- Inserindo alguns dados para exemplificação. Caso não queira, pode comentar tudo daqui até o final --

-- Função para gerar um dia aleatório nos últimos 10 anos
CREATE FUNCTION random_day_in_last_10_years() RETURNS TIMESTAMP AS $$
DECLARE
    current_epoch INTEGER;
    ten_years_ago_epoch INTEGER;
    random_timestamp TIMESTAMP;
BEGIN
    current_epoch := EXTRACT(epoch FROM CURRENT_TIMESTAMP);
    ten_years_ago_epoch := EXTRACT(epoch FROM CURRENT_TIMESTAMP - Interval '10 years');
    random_timestamp := (
        to_timestamp(
            floor(
                random() * (current_epoch - ten_years_ago_epoch + 1) + ten_years_ago_epoch
            )
        )
    );
    RETURN random_timestamp;
END;
$$ language 'plpgsql';

-- Inserindo 3 cliente manualmente
INSERT INTO customer (name, email)
VALUES
    ('Alfredo', 'alfredo@alfredo.com'),
    ('Bernardo', 'bernardo@bernardo.com'),
    ('Caio', 'caio@caio.com');

-- Inserindo aleatoriamente 6 contas para os clientes criados anteriormente
-- Essas contas iniciam com saldo alto para não ter problema na validação do saldo na inserção de movimentações
INSERT INTO account (agency_id, customer_id, is_active, balance, activation_date)
SELECT 1, "B".id, true, 100000000, CURRENT_TIMESTAMP
FROM (
    SELECT floor(random()*3+1) relate_column
    FROM generate_series(1, 6, 1)
) "A"
JOIN (
    SELECT ROW_NUMBER() OVER() relate_column, id
    FROM customer
) "B" ON "A".relate_column = "B".relate_column;

-- Gerando 10000 movimentações aleatórias para as contas criadas nos últimos 10 anos
WITH aleatory_movements_types AS (
    SELECT
        floor(random()*5+1) _type,
        floor(random()*6+1) temp_account_id
    FROM generate_series(1, 10000, 1)
), types AS (
    SELECT
        type,
        CASE
            WHEN type = 4 THEN '{"agency_id": 1, "account_id": 1, "document": 19865727509}'::JSONB
            WHEN type = 5 THEN '{"invoice_code": 12345}'::JSONB
            ELSE NULL
        END out_data
    FROM
        generate_series(1, 5, 1) type
), accounts AS (
    SELECT
        ROW_NUMBER() OVER() temp_account_id,
        internal_id
    FROM account
)
INSERT INTO movement (type, internal_account_id, amount, out_data, execution_date)
SELECT "A"._type, "B".internal_id, floor(random()*10000+1) amount, out_data, random_day_in_last_10_years()
FROM aleatory_movements_types "A"
JOIN accounts "B" ON "B".temp_account_id = "A".temp_account_id
JOIN types "C" ON "C".type = "A"._type;

COMMIT;