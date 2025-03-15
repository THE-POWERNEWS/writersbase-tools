module WritersBase
  class AccessLogCompressTool < Tool
    def exec(args = {})
      result = {success: [], failure: []}
      finder.execute.map do |file|
        Thread.new do
          compress(file)
          result[:success].push(file)
        rescue => e
          result[:failure].push({file:, error: e.message.strip})
        end
      end.each(&:join)
      return result
    end

    def compress(path)
      command = Ginseng::CommandLine.new(['gzip', '-f', path])
      command.exec
      raise command.stderr unless command.status.zero?
    end

    def finder
      unless @finder
        @finder = Ginseng::FileFinder.new
        @finder.dir = dir
        @finder.patterns = ['*.log']
        @finder.mtime = days
      end
      return @finder
    end

    def dir
      return config["/#{underscore}/dir"]
    end

    def days
      return config["/#{underscore}/days"]
    end

    def description
      return "#{dir}の#{days}日経過したログファイルを、gzip圧縮します。"
    end
  end
end
