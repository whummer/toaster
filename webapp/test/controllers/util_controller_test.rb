require 'test_helper'

class UtilControllerTest < ActionController::TestCase
  test "should get chef" do
    get :chef
    assert_response :success
  end

end
