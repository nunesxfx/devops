require "../services/metrics_service"

module DevOpsDemo
  module Routes
    module Health
      def self.register(app)
        # Simple health check
        app.get "/health" do |env|
          start = Time.monotonic
          env.response.content_type = "application/json"

          response = {
            "status"         => "healthy",
            "service"        => "crystal-devops-demo",
            "version"        => "1.0.0",
            "language"       => "Crystal #{Crystal::VERSION}",
            "uptime_seconds" => Services::MetricsService.uptime_seconds,
            "timestamp"      => Time.utc.to_rfc3339,
            "checks"         => {
              "api"    => "✅ UP",
              "memory" => "✅ OK",
              "fiber"  => "✅ #{Fiber.count} active",
            },
          }.to_json

          duration = (Time.monotonic - start).total_milliseconds.to_i64
          Services::MetricsService.record_request(duration)
          response
        end

        # Readiness probe (Kubernetes style)
        app.get "/ready" do |env|
          env.response.content_type = "application/json"
          {
            "ready"     => true,
            "timestamp" => Time.utc.to_rfc3339,
          }.to_json
        end

        # Liveness probe
        app.get "/live" do |env|
          env.response.content_type = "application/json"
          {"alive" => true}.to_json
        end
      end
    end
  end
end
