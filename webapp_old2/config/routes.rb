

Toaster::Application.routes.draw do

  resources :automations

  # global requires
  $LOAD_PATH << File.join(File.dirname(__FILE__), "../../lib") 
  require "toaster/model/user"
  require "toaster/util/load_bundler"
  # use authentication based on "devise"
  devise_for :user, :class_name => 'User'

  get "scripts" => "scripts#scripts"
  get "scripts/tasks" => "scripts#tasks"
  get "scripts/graph" => "scripts#graph"
  match "scripts/:auto_id/graph" => "scripts#graph", :via => [:get, :post]
  match "graph/:auto_id/graph_frame" => "graph#graph_frame", :via => [:get, :post]
  get "scripts/:auto_id/details" => "scripts#scripts"
  get "scripts/:auto_id/tasks" => "scripts#tasks"
  get "scripts/:auto_id/tasks/:task_id" => "scripts#tasks"
  match "scripts/:auto_id" => "scripts#edit", :via => [:get, :post, :patch]
  match "scripts/:auto_id" => "scripts#delete", :via => [:delete]
  match "/scripts/import/chef" => "scripts#import_chef", :via => [:get, :post]

  get "test/suites"
  match "test/suites/:suite_id" => "test#suites", :via => [:get, :post]
  match "test/suites/:suite_id" => "test#delete_suite", :via => [:delete]
  match "test/suites/:suite_id/:case_id" => "test#reset_case", :via => [:delete]
  match "test/exec/:suite_id/:case_id" => "test#exec_case", :via => [:post]
  match "test/exec/:suite_id" => "test#exec_suite", :via => [:post]
  get "test/cases"
  match "test/gen", :via => [:get, :post]
  match "test/gen/:auto_id" => "test#gen", :via => [:get, :post]

  match "graph/:auto_id/graph_frame" => "scripts#graph", :via => [:get, :post]

  get "execs/list"
  match "execs/tasks" => "execs#task_executions", :via => [:get]
  match "execs/:auto_id/tasks" => "execs#task_executions", :via => [:get]
  match "execs/:auto_id/tasks/:task_id" => "execs#task_executions", :via => [:get]
  match "execs/:auto_id/tasks/:task_id/:task_exec_id" => "execs#task_executions", :via => [:get]
  match "execs/:auto_id/:run_id" => "execs#automation_runs", :via => [:get]
  match "execs/:auto_id/:run_id" => "execs#delete_run", :via => [:delete]
  match "execs/:auto_id/:run_id/tasks" => "execs#task_executions", :via => [:get]
  match "execs/:auto_id" => "execs#automation_runs", :via => [:get]
  match "execs" => "execs#automation_runs", :via => [:get]

  get "analysis/index" => "analysis#index"
  get "analysis/index/:auto_id" => "analysis#index"
  get "analysis/idem" => "analysis#idempotence"
  get "analysis/conv" => "analysis#convergence"
  match "analysis/idem/auto/:auto_id" => "analysis#idempotence", :via => [:get, :post]
  match "analysis/conv/auto/:auto_id" => "analysis#convergence", :via => [:get, :post]
  match "analysis/idem/task/:task_id" => "analysis#idempotence", :via => [:get, :post]
  match "analysis/conv/task/:task_id" => "analysis#convergence", :via => [:get, :post]

  match "util/chef", :via => [:get, :post]

  get "settings/containers"
  post "settings/containers"
  get "settings/config"
  post "settings/config", :as => :save

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'
  root 'scripts#scripts'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
