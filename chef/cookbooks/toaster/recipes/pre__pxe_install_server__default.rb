#
# If the required parameter node[:pxe_install_server][:releases] 
# is not set, the recipe fails with an exception.
#

node.set[:pxe_install_server][:releases] = {}