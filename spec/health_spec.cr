require "./spec_helper"

describe DevOpsDemo::Models::Deployment do
  describe "#initialize" do
    it "creates a deployment with correct defaults" do
      deploy = DevOpsDemo::Models::Deployment.new(
        app_name: "test-app",
        version: "v1.0.0",
        environment: "staging"
      )

      deploy.app_name.should eq "test-app"
      deploy.version.should eq "v1.0.0"
      deploy.environment.should eq "staging"
      deploy.strategy.should eq "blue-green"
      deploy.status.should eq DevOpsDemo::Models::DeploymentStatus::Pending
      deploy.health_checks_passed.should eq 0
      deploy.health_checks_total.should eq 3
      deploy.id.should start_with "deploy-"
    end

    it "accepts custom strategy" do
      deploy = DevOpsDemo::Models::Deployment.new(
        app_name: "api",
        version: "v2.0.0",
        environment: "production",
        strategy: "canary"
      )
      deploy.strategy.should eq "canary"
    end
  end

  describe "#success_rate" do
    it "returns 0.0 when no checks done" do
      deploy = DevOpsDemo::Models::Deployment.new("app", "v1", "prod")
      deploy.success_rate.should eq 0.0
    end

    it "returns 100.0 when all checks pass" do
      deploy = DevOpsDemo::Models::Deployment.new("app", "v1", "prod")
      deploy.health_checks_passed = 3
      deploy.success_rate.should eq 100.0
    end

    it "returns partial rate" do
      deploy = DevOpsDemo::Models::Deployment.new("app", "v1", "prod")
      deploy.health_checks_passed = 2
      deploy.success_rate.round(2).should eq 66.67
    end
  end

  describe "#duration_ms" do
    it "returns nil when not finished" do
      deploy = DevOpsDemo::Models::Deployment.new("app", "v1", "prod")
      deploy.duration_ms.should be_nil
    end

    it "returns duration when finished" do
      deploy = DevOpsDemo::Models::Deployment.new("app", "v1", "prod")
      deploy.finished_at = deploy.started_at + 3.seconds
      duration = deploy.duration_ms
      duration.should_not be_nil
      duration.should be >= 2900
      duration.should be <= 3100
    end
  end
end

describe DevOpsDemo::Models::DeploymentStatus do
  it "has correct variants" do
    DevOpsDemo::Models::DeploymentStatus::Pending.to_s.should eq "Pending"
    DevOpsDemo::Models::DeploymentStatus::Running.to_s.should eq "Running"
    DevOpsDemo::Models::DeploymentStatus::Success.to_s.should eq "Success"
    DevOpsDemo::Models::DeploymentStatus::Failed.to_s.should eq "Failed"
  end
end
