# postgresql::server version 2.1.0 fails with nil 
# pointer exception if this attribute is not set
node.set['postgresql']['password']['postgres'] = "foobar"
