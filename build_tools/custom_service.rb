require 'json'

module BuildTools
  class CustomService

    # @option options [required, String] :service_name
    # @option options [String] :gem_version
    # @option options [String] :gem_name
    # @option options [required, String] :model_path
    # @option options [required, String] :default_endpoint
    def initialize(options = {})
      @svc_name = upcase_first(options.fetch(:service_name))

      @default_endpoint = options.fetch(:default_endpoint)
      @model_path = options.fetch(:model_path)

      # Optional
      @gem_version = options[:gem_version] || '1.0.0'
      @gem_name = options[:gem_name] || "#{@svc_name.downcase}-sdk"
      @output_dir = options[:output_dir] || File.expand_path('../../gems', __FILE__)
    end

    def build
      AwsSdkCodeGenerator::Service.new(
        name: @svc_name,
        module_name: @svc_name, # avoid AWS prefix
        gem_name: @gem_name,
        gem_version: @gem_version,
        api: load_json(@model_path), # contains both api and docs
        gem_dependencies: gem_dependencies,
        default_endpoint: @default_endpoint,
        add_plugins: add_plugins([
          "#{@svc_name}::Plugins::Authorizer",
          "#{@svc_name}::Plugins::APIGEndpoint"
        ]),
        remove_plugins: ['Aws::Plugins::RegionalEndpoint']
      )
    end

    private

    def load_json(model_dir)
      JSON.load(File.read(model_path(model_dir)))
    end

    def model_path(model_dir)
      path = File.expand_path("#{model_dir}/service-2.json", __FILE__)
      File.exists?(path) ? path : nil
    end

    def gem_dependencies
      {
        'aws-sdk-core' => '~> 3.0.0.rc20', # After GA => 3.0
        'aws-sigv4' => '~> 1.0'
      }
    end

    def add_plugins(plugins)
      plugins.inject({}) do |hash, plugin|
        hash[plugin] = plugin_path(plugin)
        hash
      end
    end

    def plugin_path(plugin_name)
      parts = plugin_name.split('::')
      parts = parts.map { |part| AwsSdkCodeGenerator::Underscore.underscore(part) }
      parts.shift # Shift off service module then append gem path

      (["#{@output_dir}/#{@gem_name}/lib/#{@gem_name}"] + parts).join('/') + '.rb'
    end

    def upcase_first(name)
      if name[0] =~ /[a-z]/
        name.size == 1 ? name.upcase : name[0].upcase + name[1..-1]
      else
        name
      end
    end

  end
end
