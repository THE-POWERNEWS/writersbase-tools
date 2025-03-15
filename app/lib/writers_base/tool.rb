module WritersBase
  class Tool
    include Package

    def exec(args = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def body(args = {})
      result = exec(args)
      contents = []
      if result.is_a?(String)
        contents.push(result)
      else
        contents.push(JSON.pretty_generate(result))
      end
      return contents.join("\n")
    end

    def help
      return ["-- #{self.class} のヘルプは未定義 --"]
    end

    def self.create(name)
      return "WritersBase::#{name.camelize}Tool".constantize.new
    end

    def self.all
      return enum_for(__method__) unless block_given?
      Dir.glob(File.join(Environment.dir, 'app/lib/writers_base/tool/*.rb')).each do |path|
        yield create(File.basename(path, '.rb').sub('_tool', ''))
      end
    end
  end
end
