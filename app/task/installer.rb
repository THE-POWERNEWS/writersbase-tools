module WritersBase
  extend Rake::DSL

  desc 'uninstall tools'
  task :uninstall do
    failures = WritersBase::Installer.instance.uninstall
    # ⚠ 構成管理は rake の終了コードしか見ない。1 件でも失敗したら非ゼロで終わる（#72）
    abort("アンインストールに失敗しました (#{failures.size} 件): #{failures.join(' / ')}") if failures.present?
  end

  desc 'install tools'
  task :install do
    failures = WritersBase::Installer.instance.install
    abort("インストールに失敗しました (#{failures.size} 件): #{failures.join(' / ')}") if failures.present?
  end
end
