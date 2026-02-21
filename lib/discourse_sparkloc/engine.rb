# frozen_string_literal: true

module ::DiscourseSparkloc
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseSparkloc
  end
end
