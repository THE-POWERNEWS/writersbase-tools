module WritersBase
  extend Rake::DSL

  namespace :bundle do
    desc 'update gems'
    task :update do
      sh 'bundle update'
    end

    desc 'check gems'
    task :check do
      unless Environment.gem_fresh?
        warn 'gems is not fresh.'
        exit 1
      end
    end
  end
end
