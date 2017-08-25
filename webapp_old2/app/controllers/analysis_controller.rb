class AnalysisController < ApplicationController

  skip_before_action :verify_authenticity_token

  def idempotence
  end

  def convergence
  end

  def cur_auto()
    ScriptsController.cur_auto(session, params)
  end
  def cur_suite
    TestController.cur_suite(session, params)
  end

  helper_method :cur_auto, :cur_suite
end
