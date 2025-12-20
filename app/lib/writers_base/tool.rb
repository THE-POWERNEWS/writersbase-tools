module WritersBase
  class Tool
    attr_reader :logger, :config

    def exec(args = {})
      raise Ginseng::ImplementError, "'#{__method__}' not implemented"
    end

    def body(args = {})
      result = exec(args)
      logger.info(tool: underscore, result:)
      contents = []
      if result.is_a?(String)
        contents.push(result)
      else
        contents.push(JSON.pretty_generate(result))
      end
      return contents.join("\n")
    end

    def underscore
      return self.class.to_s.underscore.split('/').last.sub(/_tool$/, '')
    end

    def description
      return "#{underscore} のヘルプは未定義"
    end

    def help
      return ["bin/wb #{underscore}", "  #{description}", '']
    end

    def test?
      return Environment.test?
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

    private

    def initialize
      @logger = Logger.new
      @config = Config.instance
    end

    def compress(path)
      logger.info(tool: underscore, path:, message: '圧縮開始')
      command = CommandLine.new(['zstd', "-#{config['/zstd/level']}", '--rm', '-f', path])
      command.exec unless Environment.test?
      raise command.stderr unless command.status.zero?
      logger.info(tool: underscore, path:, message: '圧縮終了')
      return "#{path}.zst"
    end

    def method_missing(method, *args)
      return config["/#{underscore}/#{method}"] if args.empty?
      return super
    end

    def respond_to_missing?(method, *args)
      return args.empty? if args.is_a?(Array)
      return super
    end
  end
end
