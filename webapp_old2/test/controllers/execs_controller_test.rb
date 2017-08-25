require 'test_helper'

class ExecsControllerTest < ActionController::TestCase
  test "should get task" do
    get :task
    assert_response :success
  end

end
