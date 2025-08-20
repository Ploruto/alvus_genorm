import alvus_genorm/schema/validation/array_validation.{type ArrayValidation}
import alvus_genorm/schema/validation/binary_validation.{type BinaryValidation}
import alvus_genorm/schema/validation/boolean_validation.{type BooleanValidation}
import alvus_genorm/schema/validation/date_validation.{type DateValidation}
import alvus_genorm/schema/validation/datetime_validation.{type DateTimeValidation}
import alvus_genorm/schema/validation/decimal_validation.{type DecimalValidation}
import alvus_genorm/schema/validation/enum_validation.{type EnumValidation}
import alvus_genorm/schema/validation/float_validation.{type FloatValidation}
import alvus_genorm/schema/validation/int_validation.{type IntValidation}
import alvus_genorm/schema/validation/json_validation.{type JsonValidation}
import alvus_genorm/schema/validation/text_validation.{type TextValidation}
import alvus_genorm/schema/validation/time_validation.{type TimeValidation}
import alvus_genorm/schema/validation/uuid_validation.{type UuidValidation}

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
  )
}

/// Attributes that can be applied to database fields.
/// These control DATABASE-LEVEL constraints, defaults, and optimizations.
/// These are separate from validation rules which handle APPLICATION-LEVEL validation.
pub type FieldAttributes {
  /// Marks this field as the primary key
  PrimaryKey
  /// Ensures the field value is unique across all rows in the table (UNIQUE constraint)
  Unique
  /// Creates a database index on this field for faster queries
  Indexed
  /// Automatically generates a UUID value when inserting new records (database-level default)
  AutoUUID
  /// Indicates this field references another table's primary key (FOREIGN KEY constraint)
  ForeignKey
  /// Allows the field to contain NULL values (database-level nullability)
  Nullable
  /// Sets a default value at the database level (e.g., DEFAULT 'active', DEFAULT NOW())
  DefaultValue(String)
  /// Auto-increment field (for non-Serial fields that need auto-increment)
  AutoIncrement
  /// Database check constraint (e.g., CHECK (age > 0))
  CheckConstraint(String)
  /// Foreign key cascade behavior on delete
  CascadeDelete
  /// Foreign key cascade behavior on update
  CascadeUpdate
  /// Set foreign key to NULL on delete
  SetNullOnDelete
  /// Set foreign key to NULL on update
  SetNullOnUpdate
  /// Specify collation for text fields (e.g., 'en_US.UTF-8')
  Collation(String)
  /// Generated/computed column
  Generated
}


/// Database field types that map to both SQL types and Gleam types.
/// Used during code generation to create the appropriate type annotations.
/// Each type embeds its own validation rules for type safety.
pub type FieldType {
  /// 32-bit integer with numeric validations
  Int(validations: List(IntValidation))
  /// 64-bit integer with numeric validations
  BigInt(validations: List(IntValidation))
  /// Auto-incrementing integer (typically for primary keys)
  Serial(validations: List(IntValidation))
  /// Universally unique identifier
  UUID(validations: List(UuidValidation))
  /// Variable-length text with maximum length and text validations
  Text(max_length: Int, validations: List(TextValidation))
  /// Fixed-length text with exact character count
  Char(length: Int, validations: List(TextValidation))
  /// Boolean field with boolean validations
  Boolean(validations: List(BooleanValidation))
  /// 32-bit floating point number
  Float(validations: List(FloatValidation))
  /// 64-bit floating point number
  Double(validations: List(FloatValidation))
  /// Fixed precision decimal for monetary values - DECIMAL(precision, scale)
  Decimal(precision: Int, scale: Int, validations: List(DecimalValidation))
  /// Date only (no time component)
  Date(validations: List(DateValidation))
  /// Time only (no date component)
  Time(validations: List(TimeValidation))
  /// Date and time without timezone
  DateTime(validations: List(DateTimeValidation))
  /// Date and time with timezone (PostgreSQL TIMESTAMPTZ)
  DateTimeWithTimezone(validations: List(DateTimeValidation))
  /// JSON data (PostgreSQL JSON type)
  Json(validations: List(JsonValidation))
  /// Binary JSON data (PostgreSQL JSONB type)
  JsonB(validations: List(JsonValidation))
  /// Array of another field type
  Array(element_type: FieldType, validations: List(ArrayValidation))
  /// Enumeration with predefined values
  Enum(values: List(String), validations: List(EnumValidation))
  /// Binary data (PostgreSQL BYTEA)
  Binary(validations: List(BinaryValidation))
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
