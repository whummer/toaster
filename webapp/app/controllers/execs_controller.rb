require "toaster/model/task"

class ExecsController < ApplicationController

	def automation_runs
		auto = cur_auto
	end

	def task_executions
	end

	def list
	end

	def delete_run
    run = cur_run
    if run
      run.delete()
      msg = "Successfully deleted automation run with UUID '#{run.uuid}'"
      flash[:notice] ? (flash[:notice] << msg) : (flash[:notice] = [msg])
    end
    redirect_to "/execs"
	end

	def cur_auto()
		ScriptsController.cur_auto(session, params)
	end
	def cur_runs()
		a = cur_auto
		if a
			return cur_auto.automation_runs
		else
			return AutomationRun.find()
		end
	end

  def cur_run()
  	ExecsController.cur_run(session, params)
  end
	def self.cur_run(session, params)
		a = ScriptsController.cur_auto(session, params)
		return nil if !a
		if params[:run_id]
			a.automation_runs.each do |r|
				if "#{r.id}" == params[:run_id]
					return r
				end
			end
		end
		return nil
	end
	def cur_task()
		ExecsController.cur_task(session, params)
	end
	def self.cur_task(session, params)
		if params[:task_id]
			return Task.find(params[:task_id])
		end
	end
	def cur_exec()
		if params[:task_exec_id]
			return TaskExecution.find(params[:task_exec_id])
		end
	end

	helper_method :cur_auto, :cur_runs, :cur_run, :cur_task, :cur_exec
end
