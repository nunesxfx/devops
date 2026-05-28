require "../services/pipeline_service"
require "../services/metrics_service"

module DevOpsDemo
  module Routes
    module Pipeline
      def self.register(app)
        # List all pipeline runs
        app.get "/pipeline" do |env|
          start = Time.monotonic
          env.response.content_type = "application/json"

          runs = Services::PipelineService.all_runs

          response = {
            "total"         => runs.size,
            "success_count" => Services::PipelineService.success_count,
            "failure_count" => Services::PipelineService.failure_count,
            "runs"          => runs,
          }.to_json

          duration = (Time.monotonic - start).total_milliseconds.to_i64
          Services::MetricsService.record_request(duration)
          response
        end

        # Trigger a new pipeline run
        app.post "/pipeline/run" do |env|
          start = Time.monotonic
          env.response.content_type = "application/json"

          body = env.request.body.try(&.gets_to_end) || "{}"
          params = JSON.parse(body)

          branch = params["branch"]?.try(&.as_s) || "main"
          pipeline_name = params["pipeline_name"]?.try(&.as_s) || "crystal-devops-demo"
          inject_failure = params["inject_failure"]?.try(&.as_bool) || false

          run = Services::PipelineService.trigger(
            pipeline_name: pipeline_name,
            branch: branch,
            inject_failure: inject_failure
          )

          env.response.status_code = 202 # Accepted

          response = {
            "message" => "Pipeline triggered successfully",
            "run_id"  => run.id,
            "status"  => run.status.to_s.downcase,
            "poll_url" => "/pipeline/#{run.id}",
          }.to_json

          duration = (Time.monotonic - start).total_milliseconds.to_i64
          Services::MetricsService.record_request(duration)
          response
        end

        # Get status of a specific run
        app.get "/pipeline/:id" do |env|
          start = Time.monotonic
          env.response.content_type = "application/json"

          id = env.params.url["id"]
          run = Services::PipelineService.find(id)

          if run
            response = run.to_json
            duration = (Time.monotonic - start).total_milliseconds.to_i64
            Services::MetricsService.record_request(duration)
            response
          else
            env.response.status_code = 404
            duration = (Time.monotonic - start).total_milliseconds.to_i64
            Services::MetricsService.record_request(duration, success: false)
            {"error" => "Pipeline run not found", "id" => id}.to_json
          end
        end

        # Pipeline stats summary
        app.get "/pipeline/stats/summary" do |env|
          env.response.content_type = "application/json"
          total = Services::PipelineService.run_count
          success = Services::PipelineService.success_count
          failure = Services::PipelineService.failure_count
          success_rate = total > 0 ? ((success.to_f / total.to_f) * 100).round(1) : 0.0

          {
            "total_runs"   => total,
            "success"      => success,
            "failures"     => failure,
            "success_rate" => success_rate,
            "grade"        => grade_for(success_rate),
          }.to_json
        end
      end

      private def self.grade_for(rate : Float64) : String
        case rate
        when 95..100 then "A+ 🏆"
        when 85..95  then "A  ✅"
        when 70..85  then "B  ⚠️"
        when 50..70  then "C  🟡"
        else              "F  ❌"
        end
      end
    end
  end
end
