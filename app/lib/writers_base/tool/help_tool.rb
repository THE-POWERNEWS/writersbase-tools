module WritersBase
  class HelpTool < Tool
    def exec(args = {})
      return Tool.all.map(&:help).flatten.join("\n")
    end

    def description
      return 'このヘルプ'
    end
  end
end
