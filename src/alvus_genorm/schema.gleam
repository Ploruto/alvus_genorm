import gleam/set.{type Set}

/// Represents a database model with its table name, fields, and relationships.
/// This is the main type used to define the structure of a database table
/// and generate type-safe Gleam code for database operations.
pub type Model {
  /// `table_name` refers to the SQL table name that is to be created.
  /// It will be singularized and a type safe API will be generated to interact with it.
  Model(
    table_name: String,
    fields: List(Field),
    relationships: List(Relationship),
  )
}

/// Represents a single field/column in a database table.
/// Contains the column name, data type, and any attributes like indexes or constraints.
pub type Field {
  Field(
    column_name: String,
    field_type: FieldType,
    attributes: List(FieldAttributes),
    validation_rules: List(ValidationRule),
  )
}

/// Attributes that can be applied to database fields.
/// These control database-level constraints and optimizations.
pub type FieldAttributes {
  /// Ensures the field value is unique across all rows in the table
  Unique
  /// Creates a database index on this field for faster queries
  Indexed
  /// Automatically generates a UUID value when inserting new records
  AutoUUID
  /// Indicates this field references another table's primary key
  ForeignKey
  /// Allows the field to contain NULL values
  Nullable
}

/// Validation rules that can be applied to fields.
/// These are used during code generation to create type-safe validation functions.
pub type ValidationRule {
  /// Validates that the field contains a valid email address
  Email
  /// Ensures the field has at least the specified number of characters
  MinLength(Int)
  /// Ensures the field has at most the specified number of characters
  MaxLength(Int)
  /// Ensures numeric fields are at least the specified value
  Min(Int)
  /// Ensures numeric fields are at most the specified value
  Max(Int)
}

/// Database field types that map to both SQL types and Gleam types.
/// Used during code generation to create the appropriate type annotations.
pub type FieldType {
  /// 32-bit integer
  Int
  /// 64-bit integer
  BigInt
  /// Auto-incrementing integer (typically for primary keys)
  Serial
  /// Universally unique identifier
  UUID
  /// Variable-length text with maximum length
  Text(Int)
}

/// Defines relationships between database tables.
/// These are used to generate type-safe methods for loading related data.
pub type Relationship {
  /// One-to-many relationship where this model has many of the target model.
  /// Example: User has many Posts
  HasMany(
    // Table name of the related model
    target_table: String,
    // Column in target table that references this table
    foreign_key: String,
    // Column in this table (usually primary key)
    local_key: String,
    // Name for the relationship accessor
    as_name: String,
  )

  /// Many-to-one relationship where this model belongs to one of the target model.
  /// Example: Post belongs to User
  BelongsTo(
    // Table name of the related model
    target_table: String,
    // Column in this table that references target table
    foreign_key: String,
    // Column in target table (usually primary key)
    target_key: String,
    // Name for the relationship accessor
    as_name: String,
  )

  /// One-to-one relationship where this model has one of the target model.
  /// Example: User has one Profile
  HasOne(
    // Table name of the related model
    target_table: String,
    // Column in target table that references this table
    foreign_key: String,
    // Column in this table (usually primary key)
    local_key: String,
    // Name for the relationship accessor
    as_name: String,
  )

  /// Many-to-many relationship through a junction table.
  /// Example: User has many Roles through UserRoles
  ManyToMany(
    // Table name of the related model
    target_table: String,
    // Name of the junction/pivot table
    junction_table: String,
    // Column in this table (usually primary key)
    local_key: String,
    // Column in junction table referencing this table
    junction_local_key: String,
    // Column in junction table referencing target table
    junction_target_key: String,
    // Column in target table (usually primary key)
    target_key: String,
    // Name for the relationship accessor
    as_name: String,
  )
}
