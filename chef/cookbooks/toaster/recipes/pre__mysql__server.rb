# Cookbook complains if passwords are not set
node.default["mysql"]["server_root_password"] = "testpassword"
node.default["mysql"]["server_repl_password"] = "testpassword"
node.default["mysql"]["server_debian_password"] = "testpassword"
