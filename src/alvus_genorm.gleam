import alvus/core/app_spec.{type AppSpec}
import alvus_genorm/generators/model_generator
import gleam/io

pub fn main() -> Nil {
  model_generator.dev_example()
}
