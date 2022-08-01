# STONE CHALLENGE

> Os passos a seguir são pensados para o Ubuntu, caso esteja usando outro sistema operacional talvez tenha que adaptá-los.

# SQL CHALLENGE

## Requisitos
- PostgreSQL 13+
> Vamos considerar que você já tenha o PostgresSQL devidamente instalado e com, pelo menos, um usuário criado.

## Passo a passo

1. Crie um database:
```
psql -h seu_host -U seu_usuario -p sua_porta -c "CREATE DATABASE stone_challenge"
```
> Será solicitada uma senha. Digite a senha configurada para seu usuário no Postgres.

2. Rode o script no seu novo banco:
```
cat database.sql | psql -h seu_host -U seu_usuario -p sua_porta -d stone_challenge
```

## Executando a query solicitada
Basta executar o seguinte script:
```SQL
SELECT * FROM invoice_amount_per_month_in_current_year;
```

# PYTHON CHALLENGE

## Requisitos
- Python 3.9+
- python-venv (ou o que você preferir)

## Como instalar
1. Crie um ambiente virtual:
```bash
python3.9 -m venv venv
```

2. Ative-o:
```bash
source venv/bin/activate
```

3. Instale as dependências:
```bash
pip install -r requirements.txt
```

## Como usar
Para facilitar o uso, foi desenvolvida uma simples interface via linha de comando. Para utilizá-la basta rodar o seguinte comando:
```bash
./run.py
```

> Caso os dados informados não estejam como o esperado, será retornado um dicionário com os respectivos erros.

## Rodando os testes unitários
Para rodar todos os testes unitários basta rodar o seguinte comando:

```bash
python -m unittest -v
```
