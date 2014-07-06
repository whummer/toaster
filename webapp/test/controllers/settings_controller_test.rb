require 'test_helper'

class SettingsControllerTest < ActionController::TestCase
  test "should get containers" do
    get :containers
    assert_response :success
  end

end
