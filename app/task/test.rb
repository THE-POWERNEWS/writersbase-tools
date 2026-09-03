module WritersBase
  extend Rake::DSL

  # ⚠ テストの正本は bin/test.rb。rake からも同じ経路を通す（CI が叩くのはこちら）。
  desc 'run tests'
  task :test do
    sh 'bin/test.rb'
  end

  desc 'run rubocop'
  task :lint do
    sh 'bundle exec rubocop'
  end
end
