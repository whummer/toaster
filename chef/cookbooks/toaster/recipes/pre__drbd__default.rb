# overwrite Node#save to make this work under Chef-solo
#module MySaveOverwrite
#  def save
#  end
#end
#node.extend(MySaveOverwrite)
node.define_singleton_method(:save) { }