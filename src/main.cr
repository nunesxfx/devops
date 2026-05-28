require "kemal"
require "json"

require "./models/deployment"
require "./models/pipeline_run"
require "./services/pipeline_service"
require "./services/metrics_service"
require "./routes/health"
require "./routes/metrics"
require "./routes/pipeline"
require "./routes/deploy"

module DevOpsDemo
  VERSION = "1.0.0"

  # CORS middleware — allow dashboard to call API
  before_all do |env|
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    env.response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
  end

  options "/*" do |env|
    env.response.headers["Allow"] = "GET, POST, OPTIONS"
    env.response.status_code = 204
    ""
  end

  # Register all routes
  Routes::Health.register(Kemal::RouteHandler::INSTANCE)
  Routes::Metrics.register(Kemal::RouteHandler::INSTANCE)
  Routes::Pipeline.register(Kemal::RouteHandler::INSTANCE)
  Routes::Deploy.register(Kemal::RouteHandler::INSTANCE)

  # Root / info endpoint
  get "/" do |env|
    env.response.content_type = "application/json"
    {
      "service"     => "🔮 Crystal DevOps Demo",
      "version"     => VERSION,
      "language"    => "Crystal #{Crystal::VERSION}",
      "description" => "High-performance DevOps demonstration system",
      "endpoints"   => {
        "health"           => "GET /health",
        "metrics"          => "GET /metrics",
        "metrics_prom"     => "GET /metrics/prometheus",
        "pipeline_list"    => "GET /pipeline",
        "pipeline_trigger" => "POST /pipeline/run",
        "pipeline_status"  => "GET /pipeline/:id",
        "pipeline_stats"   => "GET /pipeline/stats/summary",
        "deploy_list"      => "GET /deploy",
        "deploy_trigger"   => "POST /deploy",
        "deploy_status"    => "GET /deploy/:id",
      },
      "uptime" => Services::MetricsService.uptime_seconds,
    }.to_json
  end

  # Pre-populate with some demo data for the presentation
  spawn do
    sleep 2.seconds

    puts "\n🔮 Seeding demo data for presentation..."

    # Trigger 3 successful pipelines
    3.times do |i|
      Services::PipelineService.trigger(
        pipeline_name: "crystal-devops-demo",
        branch: ["main", "develop", "feature/crystal-perf"][i]
      )
      sleep 0.5.seconds
    end

    puts "✅ Demo data seeded!\n"
  end
end

# Configure Kemal
Kemal.config.port = (ENV["PORT"]? || "3000").to_i
Kemal.config.env = ENV["KEMAL_ENV"]? || "production"
Kemal.run
