import alvus/core/app_spec.{
  type AppSpec, type LogLevel, Debug, Err, Info, Warning,
}
import alvus/core/plugin.{type GeneratedFile, insert_plugin_data}
import alvus_genorm/generators/model_generator
import alvus_genorm/schema.{type Model}
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import gleam/string

pub const genorm_plugin = plugin.CodegenPlugin(
  orm_plugin,
  orm_plugin_data_to_dynamic,
  dynamic_to_orm_plugin_data,
  get_orm_data,
)

pub type OrmPluginData {
  OrmPluginData(models: List(Model))
}

fn orm_plugin(spec: AppSpec) -> #(AppSpec, List(GeneratedFile)) {
  case get_orm_data(spec) {
    option.None -> {
      let updated_spec =
        add_log(spec, Warning, "No ORM models found in plugin data")
      #(updated_spec, [])
    }
    option.Some(orm_data) -> {
      let updated_spec =
        add_log(
          spec,
          Info,
          "Generating models for "
            <> string.inspect(list.length(orm_data.models))
            <> " tables",
        )
      let generated_files =
        generate_model_files(orm_data.models, spec.codegen_root_path)
      let final_spec =
        add_log(
          updated_spec,
          Info,
          "Generated "
            <> string.inspect(list.length(generated_files))
            <> " files",
        )
      #(final_spec, generated_files)
    }
  }
}

fn orm_plugin_data_to_dynamic(data: OrmPluginData) -> Dynamic {
  dynamic.string(string.inspect(data.models))
}

fn dynamic_to_orm_plugin_data(input: Dynamic) -> Result(OrmPluginData, Nil) {
  case decode.run(input, decode.string) {
    Ok(_) -> Ok(OrmPluginData(models: []))
    Error(_) -> Error(Nil)
  }
}

fn get_orm_data(s: AppSpec) -> Option(OrmPluginData) {
  case s.plugin_storage |> dict.get("orm_plugin") {
    Ok(storage_dyn) -> {
      case dynamic_to_orm_plugin_data(storage_dyn) {
        Ok(data) -> option.Some(data)
        _ -> option.None
      }
    }
    Error(_) -> option.None
  }
}

/// Public API for consumers to set up ORM models in the plugin pipeline
pub fn with_models(spec: AppSpec, models: List(Model)) -> AppSpec {
  let orm_data = OrmPluginData(models: models)
  let dynamic_data = orm_plugin_data_to_dynamic(orm_data)
  insert_plugin_data(spec, "orm_plugin", dynamic_data)
}

fn add_log(spec: AppSpec, level: LogLevel, message: String) -> AppSpec {
  let current_logs = case dict.get(spec.logs, "genorm") {
    Ok(logs) -> logs
    Error(_) -> []
  }
  let log_entry = case level {
    app_spec.Debug -> #(app_spec.Debug, message)
    app_spec.Info -> #(app_spec.Info, message)
    Warning -> #(Warning, message)
    app_spec.Err -> #(app_spec.Err, message)
    _ -> #(app_spec.Info, message)
  }
  let updated_logs = [log_entry, ..current_logs]
  app_spec.AppSpec(..spec, logs: dict.insert(spec.logs, "genorm", updated_logs))
}

fn generate_model_files(
  models: List(Model),
  root_path: String,
) -> List(GeneratedFile) {
  models
  |> list.map(fn(model) {
    let model_name = model_generator.get_model_type_name(model)
    let file_path =
      root_path <> "/models/" <> string.lowercase(model_name) <> ".gleam"
    let content = model_generator.generate_complete_model_file(model)

    plugin.GeneratedFile(path: file_path, content: content, description: "")
  })
}
