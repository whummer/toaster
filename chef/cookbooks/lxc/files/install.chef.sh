# update installation of Ruby using RVM

distribution=""
if [ "`cat /etc/issue | grep Fedora`" != "" ]; then
	distribution="fedora"
elif [ "`cat /etc/issue | grep Ubuntu`" != "" ]; then
	distribution="ubuntu"
fi

RUBY_VERSION='<%= node["ruby"]["version"] %>'
if [ "${RUBY_VERSION:0:1}" == "<" ]; then
	RUBY_VERSION=ruby-2.0.0-p0
fi

gem_opts="--no-ri --no-rdoc"

existing=`which ruby`
if [ "$existing" == "" ]; then

	echo "INFO: updating installation of Ruby using RVM"
	if [ "$distribution" == "fedora" ]; then
		# removed package from list: rubygem-rvm
		yum -y install bison autoconf automake zlib git libyaml gcc-c++ patch readline readline-devel sed
		yum -y install zlib-devel libyaml-devel libffi-devel openssl-devel make bzip2 libtool iconv-devel unzip

	elif [ "$distribution" == "ubuntu" ]; then

		# force non-interactive install mode
		export DEBIAN_FRONTEND=noninteractive

		# The following line fails under Ubuntu quantal..
		apt-get -y install build-essential libc6-dev-amd64 libtool

		apt-get -y install bison git autoconf automake rubygems patch make bzip2 zlib1g-dev sed
		apt-get -y install less screen whiptail tar lsof unzip curl wget patch apt-utils make vim

		# RVM wants us to install even more dependencies...
		# removed package "openssl" from list
		apt-get -y install libreadline6 libreadline6-dev curl 
		apt-get -y install git-core zlib1g zlib1g-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev 
		apt-get -y install libxslt-dev autoconf libc6-dev ncurses-dev automake bison subversion pkg-config

		apt-get -y install lib32z1-dev

	fi

	curl -L https://get.rvm.io | bash -s stable
	source /usr/local/rvm/scripts/rvm
	source /etc/profile.d/rvm.sh

	if [ "$rvm_path" == "" ]; then
		rvm_path=/usr/local/rvm
	fi
	#rvm get head
	rvm get stable

	# enable "autolibs" feature in new RVM versions
	rvm autolibs enable

	rvm install $RUBY_VERSION

	source /usr/local/rvm/scripts/rvm

	# install common gems
	gem install $gem_opts rspec format
	# gem bundler required for Ruby 2.0.0
	gem install bundler --pre

	rvm use $RUBY_VERSION

fi

existing=`cat /root/.bashrc | grep "rvm use"`
if [ "$existing" == "" ]; then

	# add two lines to the beginning (!) of /root/.bashrc
	if [ "`cat /root/.bashrc | grep 'rvm use'`" == "" ]; then
		sed -i "2isource /usr/local/rvm/scripts/rvm" /root/.bashrc
		sed -i "3irvm use $RUBY_VERSION" /root/.bashrc
	fi

	echo "INFO: You might have to run 'bash' to load required Ruby environment variables."

fi

existing=`which chef-solo > /dev/null 2>&1`
if [ "$existing" == "" ]; then
	gem install $gem_opts chef
fi

# update gem system to avoid incompatibilities later on, e.g.:
# http://efreedom.net/Question/1-15266444/Unable-Install-Bson-Ext-182-Gem
gem update --system


