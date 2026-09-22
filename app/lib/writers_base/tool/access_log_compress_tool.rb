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
        # ⚠ 他の道具と同じく、積む前に個別に出す。集約の `result:` 行が落ちると
        # どのファイルで失敗したかがどこにも残らない（#123・#119）
        logger.error(tool: underscore, file:, error: e.message.strip)
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
        # ⚠⚠ `*.log` に戻さないこと。`Find.find` は再帰するので、nginx が開いたままの
        # `error.log` にも当たる。開いたファイルを `zstd --rm` で消すと、nginx は削除済みの
        # inode へ書き続け、**ログは静かに失われ、ディスクも空かない**（#123）。
        # ⚠ 「開いていないか」を確かめる案（fuser / fstat）はプラットフォームごとに
        # 別物になるので採らず、**ローテート済みと分かる名前**に絞った。
        @finder.patterns = patterns.to_a
        @finder.mtime = days
      end
      return @finder
    end
  end
end
