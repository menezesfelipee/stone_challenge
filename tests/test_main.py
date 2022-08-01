import unittest

from app.main import divide_account

class TestDivideAccountScenarios(unittest.TestCase):
    shopping_list = [
        {"name": "test1", "price": 20, "quantity": 3},
        {"name": "test2", "price": 5, "quantity": 5},
        {"name": "test3", "price": 15, "quantity": 1},
    ]
    emails = ["felipe@felipe.com", "nivia@nivia.com", "joao@joao.com"]

    def test_invalid_data_must_return_error(self):
        result = divide_account([], [])
        # Tests with other invalid data are in test_schema

        self.assertIn("error", result)
        self.assertIsInstance(result["error"], dict)

    def test_divide_100_per_3_emails(self):
        result = divide_account(self.shopping_list, self.emails)

        self.assertEqual(result["felipe@felipe.com"], 34)
        self.assertEqual(result["nivia@nivia.com"], 33)
        self.assertEqual(result["joao@joao.com"], 33)

    def test_divide_102_per_4_emails(self):
        self.shopping_list[2]["price"] = 17
        self.emails.append("maria@maria.com")

        result = divide_account(self.shopping_list, self.emails)

        self.assertEqual(result["felipe@felipe.com"], 26)
        self.assertEqual(result["nivia@nivia.com"], 26)
        self.assertEqual(result["joao@joao.com"], 25)
        self.assertEqual(result["maria@maria.com"], 25)

    def test_divide_107_per_6_emails(self):
        self.shopping_list[2]["price"] = 22
        self.emails.extend(["a@a.com", "b@b.com"])

        result = divide_account(self.shopping_list, self.emails)

        self.assertEqual(result["felipe@felipe.com"], 18)
        self.assertEqual(result["nivia@nivia.com"], 18)
        self.assertEqual(result["joao@joao.com"], 18)
        self.assertEqual(result["maria@maria.com"], 18)
        self.assertEqual(result["a@a.com"], 18)
        self.assertEqual(result["b@b.com"], 17)

    def test_divide_1_per_3_emails(self):
        self.shopping_list = self.shopping_list[2:]
        self.shopping_list[0]["price"] = 1
        self.emails = self.emails[:4]

        result = divide_account(self.shopping_list, self.emails)

        self.assertEqual(result["felipe@felipe.com"], 1)
        self.assertEqual(result["nivia@nivia.com"], 0)
        self.assertEqual(result["joao@joao.com"], 0)
