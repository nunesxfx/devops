require "./spec_helper"

describe DevOpsDemo::Models::PipelineRun do
  describe "#initialize" do
    it "creates pipeline run with correct defaults" do
      run = DevOpsDemo::Models::PipelineRun.new(
        pipeline_name: "my-pipeline",
        branch: "main"
      )

      run.pipeline_name.should eq "my-pipeline"
      run.branch.should eq "main"
      run.triggered_by.should eq "push"
      run.status.should eq DevOpsDemo::Models::PipelineStatus::Queued
      run.id.should start_with "run-"
      run.stages.size.should eq 6
    end

    it "generates unique IDs" do
      ids = (1..10).map { DevOpsDemo::Models::PipelineRun.new("pipeline", "main").id }
      ids.uniq.size.should eq 10
    end
  end

  describe "#passed_stages" do
    it "returns 0 initially" do
      run = DevOpsDemo::Models::PipelineRun.new("p", "main")
      run.passed_stages.should eq 0
    end

    it "counts success stages correctly" do
      run = DevOpsDemo::Models::PipelineRun.new("p", "main")
      run.stages[0].status = DevOpsDemo::Models::StageStatus::Success
      run.stages[1].status = DevOpsDemo::Models::StageStatus::Success
      run.passed_stages.should eq 2
    end
  end

  describe "#total_duration_ms" do
    it "returns nil when running" do
      run = DevOpsDemo::Models::PipelineRun.new("p", "main")
      run.total_duration_ms.should be_nil
    end

    it "returns duration when finished" do
      run = DevOpsDemo::Models::PipelineRun.new("p", "main")
      run.finished_at = run.started_at + 10.seconds
      run.total_duration_ms.should_not be_nil
    end
  end
end

describe DevOpsDemo::Services::PipelineService do
  describe ".trigger" do
    it "creates a pipeline run and returns it" do
      run = DevOpsDemo::Services::PipelineService.trigger(
        pipeline_name: "test-pipeline",
        branch: "feature/test"
      )

      run.id.should_not be_empty
      run.pipeline_name.should eq "test-pipeline"
      run.branch.should eq "feature/test"
    end

    it "stores the run and makes it findable" do
      run = DevOpsDemo::Services::PipelineService.trigger(
        pipeline_name: "findable-pipeline"
      )

      found = DevOpsDemo::Services::PipelineService.find(run.id)
      found.should_not be_nil
      found.try(&.pipeline_name).should eq "findable-pipeline"
    end
  end

  describe ".find" do
    it "returns nil for unknown id" do
      result = DevOpsDemo::Services::PipelineService.find("nonexistent-id")
      result.should be_nil
    end
  end
end

describe DevOpsDemo::Services::MetricsService do
  describe ".record_request" do
    it "increments request count" do
      before = DevOpsDemo::Services::MetricsService.request_count
      DevOpsDemo::Services::MetricsService.record_request(50)
      after = DevOpsDemo::Services::MetricsService.request_count
      after.should be > before
    end

    it "increments error count on failure" do
      before = DevOpsDemo::Services::MetricsService.error_count
      DevOpsDemo::Services::MetricsService.record_request(50, success: false)
      after = DevOpsDemo::Services::MetricsService.error_count
      after.should be > before
    end
  end

  describe ".uptime_seconds" do
    it "returns positive uptime" do
      DevOpsDemo::Services::MetricsService.uptime_seconds.should be >= 0
    end
  end

  describe ".snapshot" do
    it "returns a complete metrics hash" do
      snapshot = DevOpsDemo::Services::MetricsService.snapshot
      snapshot.keys.should contain "uptime_seconds"
      snapshot.keys.should contain "total_requests"
      snapshot.keys.should contain "error_count"
      snapshot.keys.should contain "crystal_version"
    end
  end
end
