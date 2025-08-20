import alvus/core/app_spec.{type AppSpec}
import alvus_genorm/generators/model_generator
import alvus_genorm/generators/query_generators/partial
import gleam/io

pub fn main() -> Nil {
  partial.example_dev()
  Nil
}
