module WritersBase
  module Package
    def environment_class
      return Environment
    end

    def package_class
      return Package
    end

    def config_class
      return Config
    end

    def config
      return Config.instance
    end

    def self.name
      return 'writers_base'
    end

    def self.url
      return Config.instance['/package/url']
    end

    def self.authors
      return Config.instance['/package/authors']
    end

    def self.included(base)
      base.extend(Methods)
    end

    module Methods
      def config
        return Config.instance
      end
    end
  end
end
