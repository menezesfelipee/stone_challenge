from marshmallow import fields, Schema, validate, ValidationError


def elements_are_unique(arr):
    if len(arr) != len(set(arr)):
        raise ValidationError("E-mails must be unique.")


class ItemShoppingSchema(Schema):
    name = fields.String(required=True)
    price = fields.Integer(
        required=True,
        strict=True,
        validate=validate.Range(min=0)
    )
    quantity = fields.Integer(
        required=True,
        strict=True,
        validate=validate.Range(min=0)
    )


class ArgsSchema(Schema):
    shopping_list = fields.List(
        fields.Nested(ItemShoppingSchema),
        required=True,
        validate=validate.Length(min=1)
    )
    emails = fields.List(
        fields.String(validate=validate.Email()),
        required=True,
        validate=validate.And(
            validate.Length(min=1),
            elements_are_unique
        )
    )
