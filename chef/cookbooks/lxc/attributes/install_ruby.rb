
default['ruby']['version'] = "2.0.0-p0"
default['ruby']['version_short'] = "2.0.0"

require "erb"
require "ostruct"
class NamespacedERB < OpenStruct
  def render(template)
    ERB.new(template).result(binding)
  end
end
file = File.read(File.join(File.dirname(__FILE__), "..", "files", "install.chef.sh"))
erb = NamespacedERB.new(:node => node)
set['ruby']['_install_script'] = erb.render(file)

set['ruby']['install_script']['fedora'] = <<-EOH

  	# install some dependencies
  	yum -y install bison autoconf automake zlib git libyaml gcc-c++ patch readline readline-devel sed
  	yum -y install zlib-devel libyaml-devel libffi-devel openssl-devel make bzip2 libtool iconv-devel
  
  	# start the actual RVM installation
  	#{node['ruby']['_install_script']}
EOH


set['ruby']['install_script']['ubuntu'] = <<-EOH

  	# force non-interactive install mode
  	export DEBIAN_FRONTEND=noninteractive

  	# install some dependencies

    # The following line fails under Ubuntu quantal..
    apt-get -y --force-yes install libc6-dev-amd6
    apt-get -y --force-yes install libeditline-dev build-essential
  	apt-get -y --force-yes install bison git autoconf automake patch make bzip2 zlib1g-dev sed libtool
  	apt-get -y --force-yes install less screen whiptail tar lsof unzip curl wget patch apt-utils make vim
  
  	# RVM wants us to install even more dependencies...
  	# removed package "openssl" from list 
  	apt-get -y --force-yes install libreadline-dev libedit-dev
  	apt-get -y --force-yes install libssl-dev
  	apt-get -y --force-yes install git-core zlib1g zlib1g-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev curl 
  	apt-get -y --force-yes install libxslt-dev autoconf libc6-dev ncurses-dev automake bison subversion pkg-config
  	apt-get -y --force-yes install lib32z1-dev
  
  	# start the actual RVM installation
  	#{node['ruby']['_install_script']}
EOH
