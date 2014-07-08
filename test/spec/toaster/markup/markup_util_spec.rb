
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#
require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

require 'toaster/markup/markup_util'

include Toaster

describe MarkupUtil, "::get_value_by_path" do

  markup = {"packages" => {"foobar" => "1.2.3", 
    "json--map--entry" =>
    [ {"key"=>"apache2.2-bin", "value"=>"1.2"}, 
      {"key"=>"mysql", "value"=>"2.3"}]
  }}
  path1 = "packages['apache2.2-bin']"
  path2 = "packages['foobar']"
  path3 = "packages.foobar"
  path4 = "packages.'mysql'"
  path5 = "packages.'apache2.2-bin'."

  it "correctly selects nodes based on JSON path" do
    value = MarkupUtil.get_value_by_path(markup, path1, true)
    value.should eq("1.2")
    value = MarkupUtil.get_value_by_path(markup, path2)
    value.should eq("1.2.3")
    value = MarkupUtil.get_value_by_path(markup, path3)
    value.should eq("1.2.3")
    value = MarkupUtil.get_value_by_path(markup, path4)
    value.should eq("2.3")
    value = MarkupUtil.get_value_by_path(markup, path5, true)
    value.should eq("1.2")
  end

end
