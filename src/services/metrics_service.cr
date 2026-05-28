require "../models/deployment"

module DevOpsDemo
  module Services
    # MetricsService collects and aggregates system + application metrics
    class MetricsService
      @@request_count = Atomic(Int64).new(0)
      @@error_count = Atomic(Int64).new(0)
      @@start_time = Time.utc
      @@response_times = [] of Int64
      @@mutex = Mutex.new

      def self.record_request(duration_ms : Int64, success : Bool = true)
        @@request_count.add(1)
        @@error_count.add(1) unless success
        @@mutex.synchronize do
          @@response_times << duration_ms
          @@response_times = @@response_times.last(1000) # keep last 1000
        end
      end

      def self.uptime_seconds : Int64
        (Time.utc - @@start_time).total_seconds.to_i64
      end

      def self.request_count : Int64
        @@request_count.get
      end

      def self.error_count : Int64
        @@error_count.get
      end

      def self.error_rate : Float64
        total = @@request_count.get
        return 0.0 if total == 0
        (@@error_count.get.to_f / total.to_f) * 100.0
      end

      def self.avg_response_time_ms : Float64
        @@mutex.synchronize do
          return 0.0 if @@response_times.empty?
          @@response_times.sum.to_f / @@response_times.size.to_f
        end
      end

      def self.p99_response_time_ms : Int64
        @@mutex.synchronize do
          return 0 if @@response_times.empty?
          sorted = @@response_times.sort
          idx = (sorted.size * 0.99).ceil.to_i - 1
          sorted[idx.clamp(0, sorted.size - 1)]
        end
      end

      def self.snapshot : Hash(String, JSON::Any)
        uptime = uptime_seconds
        total_requests = request_count
        errors = error_count

        {
          "uptime_seconds"      => JSON::Any.new(uptime),
          "uptime_human"        => JSON::Any.new(format_uptime(uptime)),
          "total_requests"      => JSON::Any.new(total_requests),
          "error_count"         => JSON::Any.new(errors),
          "error_rate_pct"      => JSON::Any.new(error_rate.round(2)),
          "avg_response_ms"     => JSON::Any.new(avg_response_time_ms.round(2)),
          "p99_response_ms"     => JSON::Any.new(p99_response_time_ms),
          "requests_per_minute" => JSON::Any.new(requests_per_minute(total_requests, uptime)),
          "crystal_version"     => JSON::Any.new(Crystal::VERSION),
          "language"            => JSON::Any.new("Crystal"),
          "memory_mb"           => JSON::Any.new(estimated_memory_mb),
        }
      end

      private def self.format_uptime(seconds : Int64) : String
        days = seconds / 86400
        hours = (seconds % 86400) / 3600
        minutes = (seconds % 3600) / 60
        secs = seconds % 60
        "#{days}d #{hours}h #{minutes}m #{secs}s"
      end

      private def self.requests_per_minute(total : Int64, uptime : Int64) : Float64
        return 0.0 if uptime == 0
        (total.to_f / (uptime.to_f / 60.0)).round(2)
      end

      private def self.estimated_memory_mb : Float64
        # Simulate reasonable memory usage
        base = 18.5
        growth = (uptime_seconds / 3600.0) * 0.1
        (base + growth).round(2)
      end
    end
  end
end
