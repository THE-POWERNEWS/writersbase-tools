module WritersBase
  class AccessLogCompressTool < Tool
    def exec(args = {})
      result = {
        success: Concurrent::Array.new,
        failure: Concurrent::Array.new,
      }
      Parallel.each(finder.execute, in_threads: Parallel.processor_count) do |file|
        compress(file)
        result[:success].push(file)
      rescue => e
        result[:failure].push(file:, error: e.message.strip)
      end
      return result
    end

    def description
      return "#{dir}の#{days}日経過したログファイルを、zstd圧縮します。"
    end

    private

    def finder
      unless @finder
        @finder = Ginseng::FileFinder.new
        @finder.dir = dir
        @finder.patterns = ['*.log']
        @finder.mtime = days
      end
      return @finder
    end
  end
end
