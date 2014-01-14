
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#
require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

require 'rubygems'
require 'toaster/db/mongodb'
require 'toaster/markup/markup_util'

include Toaster

describe MarkupUtil, "::get_value_by_path" do

  obj = {"foo" => {"bar" => ["foo1", {"foo2" => "bar2"}]}}

  it "correctly extracts values from simple path expressions" do
    Toaster::MongoDB.extract_by_expression(obj, "foo").should eq({"bar" => ["foo1", {"foo2" => "bar2"}]})
    Toaster::MongoDB.extract_by_expression(obj, "foo.bar").should eq(["foo1", {"foo2" => "bar2"}])
    Toaster::MongoDB.extract_by_expression(obj, "foo.bar.0").should eq("foo1")
    Toaster::MongoDB.extract_by_expression(obj, "foo.bar.1").should eq({"foo2" => "bar2"})
    Toaster::MongoDB.extract_by_expression(obj, "foo.bar.1.foo2").should eq("bar2")
  end

  it "updates existing entries" do

    if $run_tests_involving_db
      mongo = nil
      begin
        mongo = Toaster::DB.instance
      rescue => ex
        puts "WARN: Could not connect to database.."
      end
      if mongo
        obj1 = mongo.save(obj, ["foo.bar.0", "foo.bar.1.foo2"])
        obj2 = mongo.save(obj, ["foo.bar.0", "foo.bar.1.foo2"])
        obj1["_id"].should_not be_nil
        obj1["_id"].should_not be("")
        obj1["_id"].should eq(obj2["_id"])
      end
    end
    
  end

end
