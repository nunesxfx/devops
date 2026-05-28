module DevOpsDemo
  module Models
    # Represents a deployment unit in the system
    struct Deployment
      property id : String
      property app_name : String
      property version : String
      property environment : String
      property status : DeploymentStatus
      property strategy : String
      property started_at : Time
      property finished_at : Time?
      property health_checks_passed : Int32
      property health_checks_total : Int32
      property logs : Array(String)

      def initialize(
        @app_name : String,
        @version : String,
        @environment : String,
        @strategy : String = "blue-green"
      )
        @id = "deploy-#{Random::Secure.hex(8)}"
        @status = DeploymentStatus::Pending
        @started_at = Time.utc
        @finished_at = nil
        @health_checks_passed = 0
        @health_checks_total = 3
        @logs = [] of String
      end

      def duration_ms : Int64?
        if fin = @finished_at
          ((fin - @started_at).total_milliseconds).to_i64
        end
      end

      def success_rate : Float64
        return 0.0 if @health_checks_total == 0
        (@health_checks_passed.to_f / @health_checks_total.to_f) * 100.0
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "id", @id
          json.field "app_name", @app_name
          json.field "version", @version
          json.field "environment", @environment
          json.field "status", @status.to_s.downcase
          json.field "strategy", @strategy
          json.field "started_at", @started_at.to_rfc3339
          json.field "finished_at", @finished_at.try(&.to_rfc3339)
          json.field "duration_ms", duration_ms
          json.field "health_checks_passed", @health_checks_passed
          json.field "health_checks_total", @health_checks_total
          json.field "success_rate", success_rate.round(2)
          json.field "logs", @logs
        end
      end
    end

    enum DeploymentStatus
      Pending
      Running
      HealthChecking
      Success
      Failed
      RolledBack
    end
  end
end
