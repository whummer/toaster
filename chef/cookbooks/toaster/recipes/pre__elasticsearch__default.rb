#
# This pre-processing recipe fixes some requirements for elasticsearch.
# 

# template generation fails with an exception if this attribute is not set
node.set[:elasticsearch][:seeds] = []
