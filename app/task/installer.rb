module WritersBase
  extend Rake::DSL

  desc 'uninstall tools'
  task :uninstall do
    WritersBase::Installer.instance.uninstall
  end

  desc 'install tools'
  task :install do
    WritersBase::Installer.instance.install
  end
end
