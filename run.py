#!/usr/bin/env python3

import json

from app.main import divide_account


shopping_list = []
emails = []

print("Cadastro de produtos\n")
i = 1
while True:
    print(f"Produto {i}")

    item = {"name": input("Nome: ")}

    price = input("Preço em centavos: ")
    while True:
        try:
            item["price"] = int(price)
            assert item["price"] == float(price)
        except (ValueError, AssertionError):
            print("O preço deve ser inteiro.")
            price = input("Preço em centavos: ")
        else:
            break

    quantity = input("Quantidade: ")
    while True:
        try:
            item["quantity"] = int(quantity)
            assert item["quantity"] == float(quantity)
        except (ValueError, AssertionError):
            print("A quantidade deve ser inteira.")
            quantity = input("Quantidade: ")
        else:
            break

    shopping_list.append(item)

    register_more = input(
        "Você quer cadastrar mais produtos? [S/N] "
    ).strip().upper()[0]

    if register_more == "N":
        break

    i += 1
    print()

print("\nCadastro de e-mails\n")
i = 1
while True:
    emails.append(input(f"E-mail {i}: "))

    register_more = input(
        "Você quer cadastrar mais emails? [S/N] "
    ).strip().upper()[0]

    if register_more == "N":
        break

    i += 1
    print()

print("\nResultado:")
print(json.dumps(divide_account(shopping_list, emails), indent=4))
