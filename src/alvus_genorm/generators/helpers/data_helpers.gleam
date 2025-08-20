import alvus_genorm/schema.{type Field}
import gleam/list

pub fn field_type_to_gleam_type_as_string(field: Field) -> String {
  let optional = is_field_optional(field)
  let base_type = case field.field_type {
    schema.BigInt(_) -> "Int"
    schema.Int(_) -> "Int"
    schema.Serial(_) -> "Int"
    schema.Text(_, _) -> "String"
    schema.Char(_, _) -> "String"
    schema.UUID(_) -> "String"
    schema.Boolean(_) -> "Bool"
    schema.Float(_) -> "Float"
    schema.Double(_) -> "Float"
    schema.Decimal(_, _, _) -> "String"  // Represent as string to preserve precision
    schema.Date(_) -> "String"  // ISO date string
    schema.Time(_) -> "String"  // ISO time string
    schema.DateTime(_) -> "String"  // ISO datetime string
    schema.DateTimeWithTimezone(_) -> "String"  // ISO datetime with timezone
    schema.Json(_) -> "String"  // JSON as string
    schema.JsonB(_) -> "String"  // JSONB as string
    schema.Array(element_type, _) -> "List(" <> field_type_to_gleam_base_type(element_type) <> ")"
    schema.Enum(_, _) -> "String"  // Enum values as strings
    schema.Binary(_) -> "BitArray"  // Binary data
  }
  case optional {
    True -> "Option(" <> base_type <> ")"
    _ -> base_type
  }
}

// Helper function to get base type for array elements
fn field_type_to_gleam_base_type(field_type: schema.FieldType) -> String {
  case field_type {
    schema.BigInt(_) -> "Int"
    schema.Int(_) -> "Int"
    schema.Serial(_) -> "Int"
    schema.Text(_, _) -> "String"
    schema.Char(_, _) -> "String"
    schema.UUID(_) -> "String"
    schema.Boolean(_) -> "Bool"
    schema.Float(_) -> "Float"
    schema.Double(_) -> "Float"
    schema.Decimal(_, _, _) -> "String"
    schema.Date(_) -> "String"
    schema.Time(_) -> "String"
    schema.DateTime(_) -> "String"
    schema.DateTimeWithTimezone(_) -> "String"
    schema.Json(_) -> "String"
    schema.JsonB(_) -> "String"
    schema.Array(element_type, _) -> "List(" <> field_type_to_gleam_base_type(element_type) <> ")"
    schema.Enum(_, _) -> "String"
    schema.Binary(_) -> "BitArray"
  }
}

fn is_field_optional(field: Field) -> Bool {
  field.attributes
  |> list.any(fn(attr) { [schema.Nullable] |> list.contains(attr) })
}
