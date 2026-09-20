# Backup do banco (spec 13). Em produção roda como serviço cron do Railway: `bin/rails backup:database`
# todo dia 06:00 UTC (README → Produção). Restauração: baixar e `pg_restore` (ver backup:download).
namespace :backup do
  desc "pg_dump do banco atual para o bucket (backups/postgres/<UTC>.dump), mantendo os últimos 30"
  task database: :environment do
    key = Backups::DatabaseDump.call
    puts "Backup enviado: #{key}"
  rescue => e
    Sentry.capture_exception(e)
    raise
  end

  desc "Lista os backups no bucket, do mais recente para o mais antigo"
  task list: :environment do
    puts Backups::DatabaseDump.new.keys
  end

  desc "Baixa um backup: rake backup:download[backups/postgres/20260920T060000Z.dump,tmp/prod.dump]"
  task :download, [ :key, :path ] => :environment do |_t, args|
    path = args[:path].presence || Rails.root.join("tmp", File.basename(args[:key])).to_s
    Backups::DatabaseDump.new.download(args[:key], to: path)
    puts "Salvo em #{path}. Restaurar em um banco vazio: pg_restore --no-owner --no-privileges -d <DATABASE_URL> #{path}"
  end
end
