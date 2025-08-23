import alvus/core/plugin.{type GeneratedFile}
import alvus_genorm/generators/model_generator
import alvus_genorm/schema
import gleam/io

pub fn main() -> Nil {
  io.println("Alvus GenORM - Ready for code generation")
  
  // Example usage demonstration
  example_usage()
  Nil
}

/// Demonstrates how to use Alvus GenORM with the plugin system
fn example_usage() {
  io.println("\n=== Alvus GenORM Usage Example ===")
  
  // Define your database schema
  let user_model = schema.Model(
    table_name: "users",
    fields: [
      schema.Field(
        column_name: "id",
        field_type: schema.Serial([]),
        attributes: [schema.PrimaryKey],
      ),
      schema.Field(
        column_name: "username", 
        field_type: schema.Text(50, []),
        attributes: [schema.Unique],
      ),
      schema.Field(
        column_name: "email",
        field_type: schema.Text(255, []),
        attributes: [schema.Unique],
      ),
      schema.Field(
        column_name: "bio",
        field_type: schema.Text(1000, []),
        attributes: [schema.Nullable],
      ),
    ],
    relationships: [
      schema.HasMany(
        target_table: "posts",
        local_key: "id", 
        foreign_key: "author_id",
        as_name: "posts",
      ),
    ],
  )

  let post_model = schema.Model(
    table_name: "posts",
    fields: [
      schema.Field(
        column_name: "id",
        field_type: schema.UUID([]),
        attributes: [schema.PrimaryKey, schema.AutoUUID],
      ),
      schema.Field(
        column_name: "title",
        field_type: schema.Text(200, []),
        attributes: [],
      ),
      schema.Field(
        column_name: "content", 
        field_type: schema.Text(5000, []),
        attributes: [],
      ),
      schema.Field(
        column_name: "author_id",
        field_type: schema.Int([]),
        attributes: [schema.ForeignKey],
      ),
    ],
    relationships: [
      schema.BelongsTo(
        target_table: "users",
        foreign_key: "author_id",
        target_key: "id", 
        as_name: "author",
      ),
    ],
  )

  io.println("Defined models: User, Post")
  io.println("✓ User has username, email, bio fields")
  io.println("✓ User has many posts relationship")
  io.println("✓ Post belongs to user relationship")
  io.println("\nTo use with Alvus plugin system:")
  io.println("1. Create AppSpec")
  io.println("2. Use plugin.with_models(spec, [user_model, post_model])")
  io.println("3. Add genorm_plugin to your plugin pipeline") 
  io.println("4. Generated files will be created in codegen_root_path/models/")
  
  // Show what would be generated
  io.println("\n=== Generated User Model Preview ===")
  let user_generated = model_generator.generate_complete_model_file(user_model)
  io.println(user_generated)
}
