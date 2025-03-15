module WritersBase
  class Environment < Ginseng::Environment
    include Package

    def self.name
      return File.basename(dir)
    end

    def self.dir
      return WritersBase.dir
    end

    def self.rake?
      return ENV['RAKE'].present? && !test? rescue false
    end

    def self.test?
      return ENV['TEST'].present? rescue false
    end

    def self.type
      return config['/environment'] || 'development'
    end

    def self.development?
      return type == 'development'
    end

    def self.production?
      return type == 'production'
    end
  end
end
