module WritersBase
  class Environment < Ginseng::Environment
    def self.name
      return File.basename(dir)
    end

    def self.dir
      return WritersBase.dir
    end
  end
end
