import gleam/set.{type Set}

pub type Model {
  /// `table_name` refers to the SQL table name that is to be created.
  /// It will be singularized and a type safe API will be generated to interact with it.
  Model(
    table_name: String,
    fields: List(Field),
    relationships: List(Relationship),
  )
}

pub type Field {
  Field(
    column_name: String,
    field_type: FieldType,
    attributes: List(FieldAttributes),
  )
}

pub type FieldAttributes {
  Unique
  Indexed
  AutoUUID
  ForeignKey
}

pub type ValidationRule {
  Email
  MinLength(Int)
  MaxLength(Int)
  Min(Int)
  Max(Int)
}

pub type FieldType {
  Int
  BigInt
  Serial
  UUID
  Text(Int)
}

pub type Relationship {
  HasMany
}
