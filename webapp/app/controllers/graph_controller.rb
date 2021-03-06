class GraphController < BaseController
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery :with => :exception

  # use authentication based on "devise"
  before_filter :authenticate_user!

  # global requires
  $LOAD_PATH << File.join(File.dirname(__FILE__), "../../../../../lib") 

	def cur_auto()
		ScriptsController.cur_auto(session, params)
	end

	helper_method :cur_auto
end
