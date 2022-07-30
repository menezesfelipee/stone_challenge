import unittest

from marshmallow import ValidationError

from app.main import divide_account


class TestSchema(unittest.TestCase):
    def test_validate_empty_lists(self):
        expected_result = "Shorter than minimum length 1."

        with self.subTest("shopping_list empty"):
            with self.assertRaises(ValidationError) as err:
                divide_account([], ["test@test.com"])

            self.assertEqual(err.exception.messages["items"][0], expected_result)

        with self.subTest("emails empty"):
            with self.assertRaises(ValidationError) as err:
                shopping_list = [{"name": "some item", "price": 999, "quantity": 5}]
                divide_account(shopping_list, [])

            self.assertEqual(err.exception.messages["items"][0], expected_result)

        with self.subTest("both lists empty"):
            with self.assertRaises(ValidationError) as err:
                divide_account([], [])

            self.assertEqual(err.exception.messages["items"][0], expected_result)

    def test_validate_shopping_list_missing_info(self):
        expected_result = "Missing data for required field."
        shopping_list = [{}]
        emails = ["test@test.com", "test2@test2.com"]

        with self.subTest("missing everything"):
            with self.assertRaises(ValidationError) as err:
                divide_account(shopping_list, emails)

            self.assertEqual(
                err.exception.messages["items"][0]["name"][0],
                expected_result
            )
            self.assertEqual(
                err.exception.messages["items"][0]["price"][0],
                expected_result
            )
            self.assertEqual(
                err.exception.messages["items"][0]["quantity"][0],
                expected_result
            )

        with self.subTest("missing price and quantity"):
            shopping_list[0]["name"] = "test"

            with self.assertRaises(ValidationError) as err:
                divide_account(shopping_list, emails)

            self.assertEqual(
                err.exception.messages["items"][0]["price"][0],
                expected_result
            )
            self.assertEqual(
                err.exception.messages["items"][0]["quantity"][0],
                expected_result
            )

        with self.subTest("missing quantity"):
            shopping_list[0]["price"] = 999

            with self.assertRaises(ValidationError) as err:
                divide_account(shopping_list, emails)

            self.assertEqual(
                err.exception.messages["items"][0]["quantity"][0],
                expected_result
            )

    def test_validate_shopping_list_wrong_data(self):
        shopping_list = [{"name": "test3", "price": -15, "quantity": -1}]
        emails = ["felipe@felipe.com", "nivia@nivia.com", "joao@joao.com"]

        with self.subTest("negative values"):
            with self.assertRaises(ValidationError) as err:
                divide_account(shopping_list, emails)

            self.assertEqual(
                err.exception.messages["items"][0]["price"][0],
                "Must be greater than or equal to 0."
            )
            self.assertEqual(
                err.exception.messages["items"][0]["quantity"][0],
                "Must be greater than or equal to 0."
            )

        with self.subTest("float values"):
            shopping_list[0].update({"price": 1.1, "quantity": 5.7})

            with self.assertRaises(ValidationError) as err:
                divide_account(shopping_list, emails)

            self.assertEqual(
                err.exception.messages["items"][0]["price"][0],
                "Not a valid integer."
            )
            self.assertEqual(
                err.exception.messages["items"][0]["quantity"][0],
                "Not a valid integer."
            )

    def test_validate_emails(self):
        shopping_list = [{"name": "test", "price": 1459, "quantity": 3}]

        with self.subTest("duplicate emails"):
            with self.assertRaises(ValidationError) as err:
                divide_account(shopping_list, ["test@test.com", "test@test.com"])

            self.assertEqual(
                err.exception.messages["items"][0],
                "E-mails must be unique."
            )

        with self.subTest("invalid emails"):
            with self.assertRaises(ValidationError) as err:
                divide_account(shopping_list, ["test@test", "test@test.com", 4, "felipe"])

            self.assertEqual(
                err.exception.messages["items"][0][0],
                "Not a valid email address."
            )
            self.assertEqual(
                err.exception.messages["items"][2][0],
                "Not a valid string."
            )
            self.assertEqual(
                err.exception.messages["items"][3][0],
                "Not a valid email address."
            )
