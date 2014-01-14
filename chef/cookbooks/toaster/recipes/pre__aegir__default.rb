# Recipe aegir::default attempts to notify service "php5-fpm", which is 
# actually defined under the name "php-fpm" in cookbook php-fpm::default.
# --> hence, define it under the new name here!
php_fpm_service_name = "php5-fpm"
if platform_family?("rhel")
  php_fpm_service_name = "php-fpm"
end
service "php5-fpm" do
  service_name php_fpm_service_name
  supports :start => true, :stop => true, :restart => true, :reload => true
  action [ :enable, :restart ]
end