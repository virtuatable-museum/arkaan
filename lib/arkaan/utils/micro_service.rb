module Arkaan
  module Utils
    # This class is a singleton to load and save parameters for the whole application.
    # @author Vincent Courtois <courtois.vincent@outlook.com>
    class MicroService
      include Singleton

      # @!attribute [r] name
      #   @return [String] the name of the service you want to load.
      attr_reader :service
      # @!attribute [r] location
      #   @return [String] the path to the file loading the whole application, used to deduce the loading paths.
      attr_reader :location
      # @!attribute [r] name
      #   @return [String] the name of the service, used later to instantiate it when the mongoid configuration is fully loaded.
      attr_reader :name
      # @!attribute [r] instance
      #   @return [Arkaan::Monitoring::Instance] the instance of the service currently deployed.
      attr_reader :instance
      # @!attribute [r] type
      #   @return [Symbol] the type of instance the application is declaring
      attr_reader :type

      def initialize
        @location = false
        @service = false
        @instance = false
        @name = false
        @type = ENV['INSTANCE_TYPE'] || :heroku
        @controller_classes = []
      end

      def get_controllers
        return [] if defined?(Controllers).nil?
        classes = Controllers.constants.map { |symbol| get_const(symbol) }
        return classes.select { |symbol| symbol.is_a? Class }
      end

      def get_const(symbol)
        return Object.const_get("Controllers::#{symbol.to_s}")
      end

      # Determines if the application can be loaded (all the parameters have been correctly set)
      # @return [Boolean] TRUE if the application can be safely loaded, FALSE otherwise.
      def loadable?
        return !!(service && location)
      end

      # Getter for the path on which the service is mapped.
      # @return [String, Boolean] the absolute path in the URL on which the service is mapped upon, or FALSE if it's not set already.
      def path
        return service ? service.path : false
      end

      # Look for the service and sets it if it's found in the database, or set it to nil if not found.
      # @param [String] service_name - the name of the service to look for in the database.
      # @return [Arkaan::utils::MicroService] the instance of the micro-service to chain other calls.
      def register_as(service_name)
        @name = service_name
        return self
      end

      # Sets the location of the file calling the micro service and initializing it so that it's used as root.
      # @param filename [String] the full naame of the file with the extension.
      # @return [Arkaan::utils::MicroService] the instance of the micro-service to chain other calls.
      def from_location(filename)
        @location = File.dirname(filename)
        return self
      end

      # Loads the application in standard (production/development) mode, without the test files.
      # @return [Arkaan::utils::MicroService] the instance of the micro-service to chain other calls.
      def in_standard_mode
        return load_application(test_mode: false)
      end

      # Loads the application in test mode, by adding the needed files to run the test suite to the standard loading process.
      # @return [Arkaan::utils::MicroService] the instance of the micro-service to chain other calls.
      def in_test_mode
        @location = File.join(location, '..')
        return load_application(test_mode: true)
      end

      # Loads the application as a websockets service. Only the websockets application should use that.
      # @return [Arkaan::utils::MicroService] the instance of the micro-service to chain other calls.
      def in_websocket_mode
        load_mongoid_configuration
        load_standard_files

        Arkaan::Monitoring::Websocket.find_or_create_by(url: ENV['WEBSOCKET_URL']).save
        return self
      end

      # Deactivates the current instance and the associated service if no more instances are available.
      def deactivate!
        instance.update_attribute(:running, false)
        service.update_attribute(:test_mode, false) if ENV['TEST_MODE']
      end

      private

      # Registers the service in the database if it has not been created already.
      def register_service
        @service = Arkaan::Monitoring::Service.create(key: @name, path: "/#{@name}")
      end

      # Register the instance of the currently deployed service in the database.
      # @return [Arkaan::Monitoring::Instance] the instance of the micro service currently running.
      def register_instance
        @instance = @service.instances.where(url: ENV['SERVICE_URL']).first
        if @instance.nil?
          @instance = Arkaan::Monitoring::Instance.create(service: @service, url: ENV['SERVICE_URL'], type: type)
        end
        @instance.update_attribute(:running, true)
        return @instance
      end

      # Loads the configuration for Mongoid, the files of the application, and registers the service and the instance in the database.
      # @param test_mode [Boolean] TRUE to run in test mode (from /spec), FALSE otherwise.
      # @return [Arkaan::Utils::MicroService] the current instance of the micro service to chain other calls.
      def load_application(test_mode: false)
        Dotenv.load
        load_mongoid_configuration(test_mode: test_mode)
        if !!(@name && location)
          @service = Arkaan::Monitoring::Service.where(key: @name).first
          register_service if @service.nil?
          if ENV['TEST_MODE']
            @service.update_attribute(:test_mode, true)
          end
          register_instance
          load_plugin!
          if service
            load_standard_files
            load_test_files if test_mode
          end
        end
        return self
      end

      def load_plugin!
        plugin = ENV['ADDITIONAL_PLUGIN']
        if !plugin.nil? && Arkaan::Utils::Plugins.constants.include?(plugin)
          Arkaan::Utils::Plugins.const_get(plugin).load!(@instance)
        end
      end

      def load_mongoid_configuration(test_mode: false)
        environment = test_mode ? 'test' : (ENV['RACK_ENV'] || 'development')
        Mongoid.load!('config/mongoid.yml', environment)
      end

      def load_standard_files
        require_folder('decorators')
        require_folder('services')
        require_folder('controllers')
      end

      def load_test_files
        require_folder('spec', 'support')
        require_folder('spec', 'shared')
      end

      def require_folder(*folders)
        Dir[File.join(location, folders, '**', '*.rb')].each do |filename|
          require filename
        end
      end
    end
  end
end