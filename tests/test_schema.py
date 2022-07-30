import unittest

from marshmallow import ValidationError

from app.schema import ArgsSchema


class TestSchema(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.load_schema = ArgsSchema().load

    def test_validate_empty_lists(self):
        expected_result = "Shorter than minimum length 1."

        with self.subTest("shopping_list empty"):
            with self.assertRaises(ValidationError) as err:
                self.load_schema({"shopping_list": [], "emails": ["test@test.com"]})

            self.assertEqual(err.exception.messages["shopping_list"][0], expected_result)

        with self.subTest("emails empty"):
            with self.assertRaises(ValidationError) as err:
                shopping_list = [{"name": "some item", "price": 999, "quantity": 5}]
                self.load_schema({"shopping_list": shopping_list, "emails": []})

            self.assertEqual(err.exception.messages["emails"][0], expected_result)

        with self.subTest("both lists empty"):
            with self.assertRaises(ValidationError) as err:
                self.load_schema({"shopping_list": [], "emails": []})

            self.assertEqual(err.exception.messages["shopping_list"][0], expected_result)
            self.assertEqual(err.exception.messages["emails"][0], expected_result)

    def test_validate_shopping_list_missing_info(self):
        expected_result = "Missing data for required field."
        schema = {
            "shopping_list": [{}],
            "emails": ["test@test.com", "test2@test2.com"]
        }

        with self.subTest("missing everything"):
            with self.assertRaises(ValidationError) as err:
                self.load_schema(schema)

            self.assertEqual(
                err.exception.messages["shopping_list"][0]["name"][0],
                expected_result
            )
            self.assertEqual(
                err.exception.messages["shopping_list"][0]["price"][0],
                expected_result
            )
            self.assertEqual(
                err.exception.messages["shopping_list"][0]["quantity"][0],
                expected_result
            )

        with self.subTest("missing price and quantity"):
            schema["shopping_list"][0]["name"] = "test"

            with self.assertRaises(ValidationError) as err:
                self.load_schema(schema)

            self.assertEqual(
                err.exception.messages["shopping_list"][0]["price"][0],
                expected_result
            )
            self.assertEqual(
                err.exception.messages["shopping_list"][0]["quantity"][0],
                expected_result
            )

        with self.subTest("missing quantity"):
            schema["shopping_list"][0]["price"] = 999

            with self.assertRaises(ValidationError) as err:
                self.load_schema(schema)

            self.assertEqual(
                err.exception.messages["shopping_list"][0]["quantity"][0],
                expected_result
            )

    def test_validate_shopping_list_wrong_data(self):
        schema = {
            "shopping_list": [{"name": "test3", "price": -15, "quantity": -1}],
            "emails": ["felipe@felipe.com", "nivia@nivia.com", "joao@joao.com"]
        }

        with self.subTest("negative values"):
            with self.assertRaises(ValidationError) as err:
                self.load_schema(schema)

            self.assertEqual(
                err.exception.messages["shopping_list"][0]["price"][0],
                "Must be greater than or equal to 0."
            )
            self.assertEqual(
                err.exception.messages["shopping_list"][0]["quantity"][0],
                "Must be greater than or equal to 0."
            )

        with self.subTest("float values"):
            schema["shopping_list"][0].update({"price": 1.1, "quantity": 5.7})

            with self.assertRaises(ValidationError) as err:
                self.load_schema(schema)

            self.assertEqual(
                err.exception.messages["shopping_list"][0]["price"][0],
                "Not a valid integer."
            )
            self.assertEqual(
                err.exception.messages["shopping_list"][0]["quantity"][0],
                "Not a valid integer."
            )

    def test_validate_emails(self):
        schema = {
            "shopping_list": [{"name": "test", "price": 1459, "quantity": 3}]
        }

        with self.subTest("duplicate emails"):
            with self.assertRaises(ValidationError) as err:
                schema["emails"] = ["test@test.com", "test@test.com"]
                self.load_schema(schema)

            self.assertEqual(
                err.exception.messages["emails"][0],
                "E-mails must be unique."
            )

        with self.subTest("invalid emails"):
            with self.assertRaises(ValidationError) as err:
                schema["emails"] = ["test@test", "test@test.com", 4, "felipe"]
                self.load_schema(schema)

            self.assertEqual(
                err.exception.messages["emails"][0][0],
                "Not a valid email address."
            )
            self.assertEqual(
                err.exception.messages["emails"][2][0],
                "Not a valid string."
            )
            self.assertEqual(
                err.exception.messages["emails"][3][0],
                "Not a valid email address."
            )
