require "toaster/test/test_suite"
require "toaster/test/test_coverage"
require "toaster/test/test_generator"
require "toaster/api"

class TestController < ApplicationController
  skip_before_action :verify_authenticity_token
  def suites
  end

  skip_before_action :verify_authenticity_token
  def cases
  end

  def cur_auto
  	ScriptsController.cur_auto(session, params)
  end

  def gen
    if params[:selectAuto]
      redirect_to "/test/gen/#{params[:automation]}"
    elsif params[:submitGen]
      auto = cur_auto

      suite = TestSuite.new(
        :automation => auto,
        :user => current_user,
        :lxc_prototype => params[:prototype],
        :parameter_test_values => {}
      )
      idem = param('idempotenceN').gsub(/\s+/, "")
      if idem.include?("..")
        idem = eval("#{idem}").to_a
      else
        idem = [idem.to_i]
      end
      suite.test_coverage_goal = TestCoverageGoal.create(
        idem,
        params[:skipN].split(/[\s,;]+/).collect{|a| a.to_i},
        params[:skipNsucc].split(/[\s,;]+/).collect{|a| a.to_i},
        params[:combineN].split(/[\s,;]+/).collect{|a| a.to_i}, 
        params[:combineNsucc].split(/[\s,;]+/).collect{|a| a.to_i},
        params[:graphCoverage] == "transisions" ? 
            StateGraphCoverage::TRANSITIONS : StateGraphCoverage::STATES
      )
      gen = TestGenerator.new(suite)
      tests = gen.gen_all_tests()
      suite.test_cases = tests
      suite.save
      redirect_to "/test/suites/#{suite.id}"
    end
  end

  def reset_case
    test_case = cur_case
    if test_case
      test_case.start_time = nil
      test_case.end_time = nil
      if test_case.automation_run
        test_case.automation_run.destroy
      end
      test_case.executing_host = nil
      test_case.save
      redirect_to "/test/suites/#{test_case.test_suite.id}"
    else
      redirect_to "/test/suites"
    end
  end

  def exec_case
    test_case = cur_case
    client = service_client
    session[:suite_cur] = nil
    blocking = false
    session[:exec_output] = client.runtest(test_case.uuid, blocking)
    redirect_to "/test/suites/#{params["suite_id"]}"
  end

  def exec_suite
    test_suite = cur_suite
    client = service_client
    session[:suite_cur] = nil
    session[:exec_output] = client.runtests(test_suite.uuid)
    redirect_to "/test/suites/#{params["suite_id"]}"
  end

  def delete_suite
    if cur_suite
      puts "deleting suite #{cur_suite}"
      session[:suite_cur] = nil
      cur_suite.destroy
      redirect_to "/test/suites"
    end
  end

  # HELPER METHODS #

  def service_client
    ToasterAppClient.new(session["service.host"], session["service.port"])
  end

  def cur_suite
    TestController.cur_suite(session, params)
  end
  def self.cur_suite(session, params)
    suite = nil
    if !session[:suite_cur] || "#{session[:suite_cur].id}" != params[:suite_id]
      session[:suite_cur] = nil
      if params[:suite_id]
        suite = TestSuite.find(params[:suite_id])
        #session[:suite_cur] = suite # don't cache, to avoid inconsistencies...
      end
    end
    suite
  end

  def cur_case
    TestController.cur_case(session, params)
  end
  def self.cur_case(session, params)
    if params[:case_id]
      return TestCase.find(params[:case_id])
    end
  end

  helper_method :l, :lk, :set_param, :param, :cur_auto, :cur_suite, :cur_case
end
