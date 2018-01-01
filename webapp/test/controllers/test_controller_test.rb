require 'test_helper'

class TestControllerTest < ActionController::TestCase
  test "should get suites" do
    get :suites
    assert_response :success
  end

  test "should get cases" do
    get :cases
    assert_response :success
  end

end
