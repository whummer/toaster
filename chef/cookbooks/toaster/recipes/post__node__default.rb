#
# At the time of writing, this recipe fails because curl cannot download
# the given file (curl does not follow HTTP redirects by default). 
# This post-processing recipe should fix the bug.
#

bash "install_npm" do
  user "root"
    cwd "/tmp/"
    code <<-EOH
    # original:
    # curl http://npmjs.org/install.sh | clean=no sh
    # fixed:
    curl -L http://npmjs.org/install.sh | clean=no sh
    EOH
end
