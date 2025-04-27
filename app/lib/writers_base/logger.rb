module WritersBase
  class Logger < Ginseng::Logger
    include Package

    def info(obj)
      super(deep_mask_keys(obj))
    end

    def warn(obj)
      error(deep_mask_keys(obj))
    end

    def error(obj)
      super(deep_mask_keys(obj))
    end

    private

    def keys_to_mask
      return @config['/logger/keys_to_mask']
    end

    def mask
      return @config['/logger/mask']
    end

    def deep_mask_keys(obj)
      case obj
      when Hash
        return obj.each_with_object({}) do |(k, v), dest|
          if keys_to_mask.any?(k.to_s)
            dest[k] = mask
          else
            dest[k] = deep_mask_keys(v)
          end
        end
      when Array
        return obj.map {|e| deep_mask_keys(e)}
      else
        return obj
      end
    end
  end
end
