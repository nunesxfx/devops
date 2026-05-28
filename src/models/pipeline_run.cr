module DevOpsDemo
  module Models
    # Represents a CI/CD pipeline execution
    struct PipelineRun
      property id : String
      property pipeline_name : String
      property branch : String
      property commit_sha : String
      property triggered_by : String
      property status : PipelineStatus
      property stages : Array(PipelineStage)
      property started_at : Time
      property finished_at : Time?

      def initialize(
        @pipeline_name : String,
        @branch : String = "main",
        @commit_sha : String = Random::Secure.hex(7),
        @triggered_by : String = "push"
      )
        @id = "run-#{Random::Secure.hex(8)}"
        @status = PipelineStatus::Queued
        @started_at = Time.utc
        @finished_at = nil
        @stages = build_default_stages
      end

      private def build_default_stages : Array(PipelineStage)
        [
          PipelineStage.new("🔍 Lint & Format", 800),
          PipelineStage.new("🏗️  Build", 2500),
          PipelineStage.new("🧪 Unit Tests", 1800),
          PipelineStage.new("🔒 Security Scan", 1200),
          PipelineStage.new("📦 Package", 900),
          PipelineStage.new("🚀 Deploy", 1500),
        ]
      end

      def total_duration_ms : Int64?
        if fin = @finished_at
          ((fin - @started_at).total_milliseconds).to_i64
        end
      end

      def passed_stages : Int32
        @stages.count(&.status.== StageStatus::Success)
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "id", @id
          json.field "pipeline_name", @pipeline_name
          json.field "branch", @branch
          json.field "commit_sha", @commit_sha
          json.field "triggered_by", @triggered_by
          json.field "status", @status.to_s.downcase
          json.field "started_at", @started_at.to_rfc3339
          json.field "finished_at", @finished_at.try(&.to_rfc3339)
          json.field "total_duration_ms", total_duration_ms
          json.field "passed_stages", passed_stages
          json.field "total_stages", @stages.size
          json.field "stages", @stages
        end
      end
    end

    struct PipelineStage
      property name : String
      property status : StageStatus
      property duration_ms : Int32
      property logs : Array(String)

      def initialize(@name : String, @duration_ms : Int32)
        @status = StageStatus::Pending
        @logs = [] of String
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "name", @name
          json.field "status", @status.to_s.downcase
          json.field "duration_ms", @duration_ms
          json.field "logs", @logs
        end
      end
    end

    enum PipelineStatus
      Queued
      Running
      Success
      Failed
      Cancelled
    end

    enum StageStatus
      Pending
      Running
      Success
      Failed
      Skipped
    end
  end
end
