module Backups
  # Backup do Postgres (spec 13 / tarefa 4.2). Decisão 20/09: em vez do backup de volume do Railway
  # (exige plano Pro), `pg_dump --format=custom` do banco atual para o bucket privado do Active
  # Storage em `backups/postgres/<UTC>.dump`, mantendo os últimos KEEP. Roda pelo serviço cron do
  # Railway (`bin/rails backup:database`, README); restauração com `pg_restore` (rake backup:download).
  # O bucket já é criptografado em repouso (S3) e as credenciais são as do próprio app.
  class DatabaseDump
    PREFIX = "backups/postgres/"
    KEEP = 30

    def self.call(keep: KEEP) = new.call(keep:)

    def call(keep: KEEP)
      key = "#{PREFIX}#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}.dump"
      Tempfile.create([ "pg", ".dump" ]) do |file|
        dump_to(file.path)
        File.open(file.path, "rb") { |io| service.upload(key, io) }
      end
      prune(keep)
      key
    end

    # Chaves existentes, da mais recente para a mais antiga (só serviços com listagem: S3/MinIO).
    def keys
      return [] unless service.respond_to?(:bucket)

      service.bucket.objects(prefix: PREFIX).map(&:key).sort.reverse
    end

    def download(key, to:)
      File.open(to, "wb") { |file| service.download(key) { |chunk| file.write(chunk) } }
    end

    private
      # pg_dump lê a conexão de PG*; `configuration_hash` já resolve DATABASE_URL em host/porta/etc.
      def dump_to(path)
        db = ActiveRecord::Base.connection_db_config.configuration_hash
        env = {
          "PGHOST" => db[:host].to_s, "PGPORT" => db[:port].to_s, "PGUSER" => db[:username].to_s,
          "PGPASSWORD" => db[:password].to_s, "PGDATABASE" => db[:database].to_s
        }.compact_blank
        system(env, "pg_dump", "--format=custom", "--no-owner", "--no-privileges", "--file=#{path}", exception: true)
      end

      def prune(keep)
        keys.drop(keep).each { |key| service.delete(key) }
      end

      def service = ActiveStorage::Blob.service
  end
end
