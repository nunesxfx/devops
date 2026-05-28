require "../services/metrics_service"

module DevOpsDemo
  module Routes
    module Metrics
      def self.register(app)
        # Prometheus-compatible metrics snapshot
        app.get "/metrics" do |env|
          start = Time.monotonic
          env.response.content_type = "application/json"

          snapshot = Services::MetricsService.snapshot
          response = snapshot.to_json

          duration = (Time.monotonic - start).total_milliseconds.to_i64
          Services::MetricsService.record_request(duration)
          response
        end

        # Prometheus text format (for Prometheus scraping)
        app.get "/metrics/prometheus" do |env|
          env.response.content_type = "text/plain; version=0.0.4"
          s = Services::MetricsService.snapshot

          String.build do |io|
            io << "# HELP crystal_uptime_seconds Application uptime in seconds\n"
            io << "# TYPE crystal_uptime_seconds gauge\n"
            io << "crystal_uptime_seconds #{s["uptime_seconds"]}\n\n"

            io << "# HELP crystal_requests_total Total HTTP requests\n"
            io << "# TYPE crystal_requests_total counter\n"
            io << "crystal_requests_total #{s["total_requests"]}\n\n"

            io << "# HELP crystal_errors_total Total HTTP errors\n"
            io << "# TYPE crystal_errors_total counter\n"
            io << "crystal_errors_total #{s["error_count"]}\n\n"

            io << "# HELP crystal_response_time_avg_ms Average response time\n"
            io << "# TYPE crystal_response_time_avg_ms gauge\n"
            io << "crystal_response_time_avg_ms #{s["avg_response_ms"]}\n\n"

            io << "# HELP crystal_response_time_p99_ms P99 response time\n"
            io << "# TYPE crystal_response_time_p99_ms gauge\n"
            io << "crystal_response_time_p99_ms #{s["p99_response_ms"]}\n"
          end
        end
      end
    end
  end
end
