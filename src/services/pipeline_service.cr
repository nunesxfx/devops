require "../models/pipeline_run"

module DevOpsDemo
  module Services
    # PipelineService simulates a real CI/CD pipeline execution
    # with configurable stages, timing and failure injection
    class PipelineService
      @@runs = {} of String => Models::PipelineRun
      @@mutex = Mutex.new

      def self.all_runs : Array(Models::PipelineRun)
        @@mutex.synchronize { @@runs.values.sort_by(&.started_at).reverse }
      end

      def self.find(id : String) : Models::PipelineRun?
        @@mutex.synchronize { @@runs[id]? }
      end

      def self.run_count : Int32
        @@mutex.synchronize { @@runs.size }
      end

      def self.success_count : Int32
        @@mutex.synchronize do
          @@runs.values.count { |r| r.status.success? }
        end
      end

      def self.failure_count : Int32
        @@mutex.synchronize do
          @@runs.values.count { |r| r.status.failed? }
        end
      end

      # Trigger a new pipeline run asynchronously
      def self.trigger(
        pipeline_name : String = "crystal-devops-demo",
        branch : String = "main",
        inject_failure : Bool = false
      ) : Models::PipelineRun
        run = Models::PipelineRun.new(
          pipeline_name: pipeline_name,
          branch: branch
        )

        @@mutex.synchronize { @@runs[run.id] = run }

        # Execute pipeline stages in background fiber
        spawn do
          execute_pipeline(run, inject_failure)
        end

        run
      end

      private def self.execute_pipeline(run : Models::PipelineRun, inject_failure : Bool)
        run.status = Models::PipelineStatus::Running

        run.stages.each_with_index do |stage, index|
          stage.status = Models::StageStatus::Running
          stage.logs << "[#{Time.utc.to_s}] Starting stage: #{stage.name}"

          # Simulate stage work
          sleep(stage.duration_ms.milliseconds)

          # Inject failure at stage 3 (Unit Tests) if requested
          if inject_failure && index == 2
            stage.status = Models::StageStatus::Failed
            stage.logs << "[#{Time.utc.to_s}] ❌ FAILED: 3 tests failed"
            stage.logs << "  - spec/pipeline_spec.cr:42 — Expected 200, got 500"
            stage.logs << "  - spec/health_spec.cr:18 — Connection refused"
            run.status = Models::PipelineStatus::Failed
            run.finished_at = Time.utc

            # Mark remaining stages as skipped
            run.stages[(index + 1)..].each(&.status = Models::StageStatus::Skipped)
            return
          end

          stage.status = Models::StageStatus::Success
          stage.logs << "[#{Time.utc.to_s}] ✅ Completed in #{stage.duration_ms}ms"

          # Add realistic log output per stage
          case index
          when 0
            stage.logs << "  → crystal tool format --check src/"
            stage.logs << "  → ameba src/ — 0 issues found"
          when 1
            stage.logs << "  → shards install"
            stage.logs << "  → crystal build --release src/main.cr"
            stage.logs << "  → Binary size: 4.2MB | Build time: 2.5s"
          when 2
            stage.logs << "  → crystal spec --verbose"
            stage.logs << "  → 24 examples, 0 failures, 0 errors"
          when 3
            stage.logs << "  → trivy image crystal:1.14-alpine"
            stage.logs << "  → 0 critical, 0 high CVEs found"
          when 4
            stage.logs << "  → docker build --tag crystal-devops-demo:#{run.commit_sha}"
            stage.logs << "  → Image size: 52MB (multi-stage optimized)"
          when 5
            stage.logs << "  → kubectl set image deploy/app app=crystal-devops-demo:#{run.commit_sha}"
            stage.logs << "  → Rollout complete — 3/3 pods healthy"
          end
        end

        run.status = Models::PipelineStatus::Success
        run.finished_at = Time.utc
      end
    end
  end
end
