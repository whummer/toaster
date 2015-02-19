# https://forge.puppetlabs.com/nodes/php

include php

class { ['php::fpm', 'php::cli', 'php::extension::apc']:

}
