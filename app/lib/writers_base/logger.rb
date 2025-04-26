module WritersBase
  class Logger < Ginseng::Logger
    include Package

    alias warn info
  end
end
