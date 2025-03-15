module WritersBase
  class HelpTool < Tool
    def exec(args = {})
      return Tool.all.map(&:help).flatten.join("\n")
    end

    def help
      return ['bin/wb.rb help - ヘルプ']
    end
  end
end
