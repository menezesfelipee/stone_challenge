from typing import Dict, List, TypedDict

from app.schema import ArgsSchema


class ShoppingItem(TypedDict):
    name: str
    price: int
    quantity: int


def divide_account(
    shopping_list: List[ShoppingItem],
    emails: List[str]
) -> Dict[str, int]:
    """Given a shopping list and an email list, that function divides
    the total price between each email.

    Args:
        shopping_list (List[Dict[ShoppingItem]]): List of products as
                                        [
                                            {
                                                "name": str,
                                                "price": int,
                                                "quantity": int
                                            },
                                            ...
                                        ]
        emails (List[str]): List of unique and valide emails

    Returns:
        Dict[str, int]: Price per email as
                        {
                            email: price,
                            ...
                        }
    """

    schema_result = ArgsSchema().load({
        "shopping_list": shopping_list,
        "emails": emails
    })

    shopping_list = schema_result["shopping_list"]
    emails = schema_result["emails"]

    total_price = sum(item["price"] * item["quantity"] for item in shopping_list)

    price_per_person = total_price // len(emails)
    remaining = total_price % len(emails)

    return (
        dict.fromkeys(emails[:remaining], price_per_person + 1)
        | dict.fromkeys(emails[remaining:], price_per_person)
    )
