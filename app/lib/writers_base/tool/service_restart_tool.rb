module WritersBase
  class ServiceRestartTool < Tool
    def exec(args = {})
      result = {success: [], failure: []}
      services.each do |name|
        logger.info(tool: underscore, service: name, message: '再起動開始')
        execute(['service', name, 'restart'])
        result[:success].push(name)
      rescue => e
        logger.error(tool: underscore, service: name, error: e.message.strip)
        result[:failure].push(service: name, error: e.message.strip)
      end
      return result
    end

    def description
      return '設定されたサービスを再起動します。'
    end
  end
end
