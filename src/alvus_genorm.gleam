import alvus/core/app_spec.{type AppSpec}
import alvus_genorm/generators/model_generator
import alvus_genorm/generators/query_generators/full
import alvus_genorm/generators/query_generators/user_insert
import gleam/io

pub fn main() -> Nil {
  user_insert.example_wont_succeed()
  Nil
}
