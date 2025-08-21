import alvus/core/app_spec.{type AppSpec}
import alvus_genorm/generators/model_generator
import alvus_genorm/generators/query_generators/user_full_with_relationships as rel
import alvus_genorm/generators/query_generators/user_insert
import gleam/io

pub fn main() -> Nil {
  rel.example_usage()
  Nil
}
