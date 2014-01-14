# fix a statement in recipe vmware::tools: 
# "if node.virtualization.system == 'vmware'" 
# (fails without this attribute definition)
node.set["virtualization"]["system"] = 'vmware'