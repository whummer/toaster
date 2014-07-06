require 'test_helper'

class AnalysisControllerTest < ActionController::TestCase
  test "should get idempotence" do
    get :idempotence
    assert_response :success
  end

  test "should get convergence" do
    get :convergence
    assert_response :success
  end

end
