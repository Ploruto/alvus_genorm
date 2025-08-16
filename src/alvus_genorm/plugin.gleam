import alvus/core/app_spec.{type AppSpec}
import alvus/core/plugin.{
  type CodegenPlugin, type GeneratedFile, insert_plugin_data,
}
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/result

pub const genorm_plugin = plugin.CodegenPlugin(
  orm_plugin,
  orm_plugin_data_to_dynamic,
  dynamic_to_orm_plugin_data,
  get_orm_data,
)

pub type OrmPluginData {
  OrmPluginData(orm_extra_data: String)
}

fn orm_plugin(spec: AppSpec) -> #(AppSpec, List(GeneratedFile)) {
  let data = OrmPluginData(orm_extra_data: "some value")
  let dynamic_data = orm_plugin_data_to_dynamic(data)
  let new_spec = insert_plugin_data(spec, "orm_plugin", dynamic_data)
  #(new_spec, [])
}

fn orm_plugin_data_to_dynamic(data: OrmPluginData) -> Dynamic {
  dynamic.string(data.orm_extra_data)
}

fn dynamic_to_orm_plugin_data(input: Dynamic) -> Result(OrmPluginData, Nil) {
  case decode.run(input, decode.string) {
    Ok(data) -> Ok(OrmPluginData(orm_extra_data: data))
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
