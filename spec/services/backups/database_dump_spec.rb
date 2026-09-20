require "rails_helper"

# Backup do banco para o bucket (spec 13, tarefa 4.2). O pg_dump em si é stubado: o CI tem client
# de outra versão; a task foi validada de ponta a ponta (dump → MinIO → pg_restore) em 20/09.
RSpec.describe Backups::DatabaseDump do
  let(:service) { ActiveStorage::Blob.service }

  it "roda o pg_dump com a conexão atual (PG*), sobe o arquivo em backups/postgres/<UTC>.dump e devolve a chave" do
    dump = described_class.new
    db = ActiveRecord::Base.connection_db_config.configuration_hash
    allow(dump).to receive(:system) do |_env, *cmd, exception:|
      File.write(cmd.last.delete_prefix("--file="), "PGDMP")
      true
    end

    travel_to Time.utc(2026, 9, 20, 6, 0, 0) do
      key = dump.call
      expect(key).to eq("backups/postgres/20260920T060000Z.dump")
      expect(service.exist?(key)).to be(true)
      expect(service.download(key)).to eq("PGDMP")
      service.delete(key)
    end
    expect(dump).to have_received(:system).with(
      hash_including("PGDATABASE" => db[:database].to_s), "pg_dump", "--format=custom", "--no-owner", "--no-privileges", /\A--file=/, exception: true
    )
  end

  it "propaga a falha do pg_dump sem subir nada" do
    dump = described_class.new
    allow(dump).to receive(:system).and_raise(RuntimeError, "Command failed with exit 1: pg_dump")

    expect { dump.call }.to raise_error(RuntimeError, /pg_dump/)
  end

  it "sem listagem no serviço (Disk) não tem o que podar e devolve lista vazia" do
    expect(described_class.new.keys).to eq([])
  end

  it "com listagem (S3) mantém só os N mais recentes" do
    dump = described_class.new
    keys = (1..4).map { |i| "backups/postgres/2026090#{i}T060000Z.dump" }
    allow(dump).to receive(:keys).and_return(keys.reverse)
    allow(service).to receive(:delete)

    dump.send(:prune, 2)

    expect(service).to have_received(:delete).with(keys[1]).ordered
    expect(service).to have_received(:delete).with(keys[0]).ordered
    expect(service).not_to have_received(:delete).with(keys[3])
  end
end
