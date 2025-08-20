import alvus/core/app_spec.{type AppSpec}
import alvus_genorm/generators/model_generator
import alvus_genorm/generators/query_generators/full
import gleam/io

pub fn main() -> Nil {
  full.example_dev()
  Nil
}
