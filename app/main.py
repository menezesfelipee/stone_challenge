from typing import Any, Dict, List

from app.schema import ArgsSchema


def divide_account(
    shopping_list: List[Dict[str, Any]],
    emails: List[str]
) -> Dict[str, int]:
    """Given a shopping list and an email list, that function divides
    the total price between each email.

    Args:
        shopping_list (List[Dict[str, Any]]): List of products as
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
    remaining = total_price - (price_per_person * len(emails))

    dict_result = {email: price_per_person for email in emails}
    dict_result[emails[0]] += remaining

    return dict_result
