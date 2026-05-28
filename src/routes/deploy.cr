require "../models/deployment"
require "../services/metrics_service"

module DevOpsDemo
  module Routes
    module Deploy
      @@deployments = [] of Models::Deployment
      @@mutex = Mutex.new

      def self.register(app)
        # List all deployments
        app.get "/deploy" do |env|
          start = Time.monotonic
          env.response.content_type = "application/json"

          deploys = @@mutex.synchronize { @@deployments.dup }

          response = {
            "total"       => deploys.size,
            "deployments" => deploys,
          }.to_json

          duration = (Time.monotonic - start).total_milliseconds.to_i64
          Services::MetricsService.record_request(duration)
          response
        end

        # Trigger new deployment
        app.post "/deploy" do |env|
          start = Time.monotonic
          env.response.content_type = "application/json"

          body = env.request.body.try(&.gets_to_end) || "{}"
          params = JSON.parse(body)

          app_name = params["app_name"]?.try(&.as_s) || "crystal-devops-demo"
          version = params["version"]?.try(&.as_s) || "v1.0.#{rand(100)}"
          environment = params["environment"]?.try(&.as_s) || "production"
          strategy = params["strategy"]?.try(&.as_s) || "blue-green"

          deployment = Models::Deployment.new(
            app_name: app_name,
            version: version,
            environment: environment,
            strategy: strategy
          )

          @@mutex.synchronize { @@deployments.unshift(deployment) }

          # Run deployment simulation in background
          spawn { simulate_deployment(deployment) }

          env.response.status_code = 202
          response = {
            "message"       => "Deployment initiated",
            "deployment_id" => deployment.id,
            "strategy"      => strategy,
            "poll_url"      => "/deploy/#{deployment.id}",
          }.to_json

          duration = (Time.monotonic - start).total_milliseconds.to_i64
          Services::MetricsService.record_request(duration)
          response
        end

        # Get specific deployment status
        app.get "/deploy/:id" do |env|
          start = Time.monotonic
          env.response.content_type = "application/json"

          id = env.params.url["id"]
          deploy = @@mutex.synchronize { @@deployments.find { |d| d.id == id } }

          if deploy
            response = deploy.to_json
            duration = (Time.monotonic - start).total_milliseconds.to_i64
            Services::MetricsService.record_request(duration)
            response
          else
            env.response.status_code = 404
            duration = (Time.monotonic - start).total_milliseconds.to_i64
            Services::MetricsService.record_request(duration, success: false)
            {"error" => "Deployment not found", "id" => id}.to_json
          end
        end
      end

      private def self.simulate_deployment(deploy : Models::Deployment)
        deploy.status = Models::DeploymentStatus::Running
        deploy.logs << "[#{Time.utc.to_s}] 🚀 Starting #{deploy.strategy} deployment"
        deploy.logs << "[#{Time.utc.to_s}] 📦 Pulling image: #{deploy.app_name}:#{deploy.version}"

        sleep 1.second

        deploy.status = Models::DeploymentStatus::HealthChecking
        deploy.logs << "[#{Time.utc.to_s}] 🔍 Running health checks..."

        3.times do |i|
          sleep 0.8.seconds
          deploy.health_checks_passed += 1
          deploy.logs << "[#{Time.utc.to_s}] ✅ Health check #{i + 1}/3 passed"
        end

        sleep 0.5.seconds
        deploy.status = Models::DeploymentStatus::Success
        deploy.finished_at = Time.utc
        deploy.logs << "[#{Time.utc.to_s}] 🎉 Deployment successful! #{deploy.version} is live."
        deploy.logs << "[#{Time.utc.to_s}] 💙 Blue-green switch complete — 100% traffic routed to new version."
      end
    end
  end
end
