# Sidekiq como adapter do Active Job (config.active_job.queue_adapter = :sidekiq nos ambientes).
redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# Falha cedo em argumentos não serializáveis (símbolos, objetos), inclusive em test.
Sidekiq.strict_args!
