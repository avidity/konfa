$: << File.join(File.dirname(File.dirname(__FILE__)), "lib")

require 'konfa'

class MyKonfa < Konfa::Base
  @@env_variable_prefix = 'PREF_'
  @@variables = {
    :my_var         => 'default value',
    :default_is_nil => nil
  }
end

describe Konfa do
  let(:bool_file) { File.expand_path("../support/bool_config.yaml", __FILE__) }
  let(:good_file) { File.expand_path("../support/good_config.yaml", __FILE__) }
  let(:bad_file)  { File.expand_path("../support/bad_config.yaml", __FILE__) }
  let(:not_yaml)  { File.expand_path("../support/not_yaml.yaml", __FILE__) }


  context "#variables" do
    it "can list available configuration variables" do
      MyKonfa.variables.should be_kind_of Array
    end

    it "presents all variable keys as symbols" do
      MyKonfa.variables.all? {|v| v.kind_of? Symbol }.should be_true
    end
  end

  context "#dump" do
    it "can dump all existing variables and values" do
      MyKonfa.dump.should be_kind_of Hash
      MyKonfa.dump.keys.should == MyKonfa.variables
    end

    it "dumpes the current state" do
      original = MyKonfa.dump[:default_is_nil]
      MyKonfa.set :default_is_nil, 'not nil'
      MyKonfa.dump[:default_is_nil].should_not == original
    end
  end

  context "#get and #set" do

    before do
      @original = MyKonfa.dump
    end

    after do
      @original.each { |k, v| MyKonfa.set(k, v) }
    end

    it "all variables can be accessed or set" do
      MyKonfa.variables.each do |variable|
        MyKonfa.set(variable, 'test value').should_not be_nil
        MyKonfa.get(variable).should == 'test value'
      end
    end

    it "raises an exception if unknown configuration variable is accessed" do
      expect {
        MyKonfa.get :_this_is_totally_wrong
      }.to raise_error Konfa::UnsupportedVariableError
    end

    it "raises an exception if unknown configuration variable is being set" do
      expect {
        MyKonfa.set :_this_is_totally_wrong, 'some value'
      }.to raise_error Konfa::UnsupportedVariableError
    end
  end

  context "#initialize_from_yaml" do
    it "can be initialized with a YAML file" do
      expect {
        MyKonfa.initialize_from_yaml(good_file)
      }.to_not raise_error
      MyKonfa.get(:my_var).should == 'read from the yaml file'
    end

    it "returns parsed values" do
      MyKonfa.initialize_from_yaml(good_file).should == MyKonfa.dump
    end

    it "requires all keys in YAML file to be defined in config class" do
      expect {
        MyKonfa.initialize_from_yaml(bad_file)
      }.to raise_error Konfa::UnsupportedVariableError
    end

    it "handles Ruby's implicit type conversion" do
      MyKonfa.initialize_from_yaml(bool_file)
      MyKonfa.get(:my_var).should be_a(String)
      MyKonfa.get(:my_var).should == 'true'
    end
  end

  context "#initialize_from_env" do

    it "prefixes environment variables" do
      MyKonfa.env_variable_prefix.should == 'PREF_'
    end

    it "can be initialized with environment variables" do
      begin
        ENV["PREF_MY_VAR"] = 'set from env'
        ENV["IGNORE_MY_VAR"]  = 'should be ignored'

        expect {
          MyKonfa.initialize_from_env
        }.not_to raise_error

        MyKonfa.get(:my_var).should == 'set from env'
      ensure
        ENV.delete("PREF_MY_VAR")
        ENV.delete("IGNORE_MY_VAR")
      end
    end

    it "allows the default variable key prefix to be overridden" do
      begin
        ENV["COOL_PREFIX_MY_VAR"]  = 'set from env with cool prefix'
        ENV["PREF_MY_VAR"]         = 'should be ignored'

        MyKonfa.initialize_from_env('COOL_PREFIX_')
        MyKonfa.get(:my_var).should == 'set from env with cool prefix'
      ensure
        ENV.delete("COOL_PREFIX_MY_VAR")
        ENV.delete("PREF_MY_VAR")
      end
    end

    it "requires all keys in namespace to be defined in config class" do
      ENV["PREF_BAD_VARIABLE"] = 'should yield an error'

      expect {
        MyKonfa.initialize_from_env
      }.to raise_error Konfa::UnsupportedVariableError

      ENV.delete("PREF_BAD_VARIABLE")
    end
  end

  context "#with_config" do

    let(:test_value) { 'my test value' }

    before do
      MyKonfa.set(:my_var, test_value)
    end

    it "prevents existing values to be over written" do
      MyKonfa.with_config(:my_var => 'blah') do
        MyKonfa.get(:my_var).should eq('blah')
      end

      MyKonfa.get(:my_var).should be(test_value)
    end

    it "drops any new values set in block" do
      MyKonfa.with_config do
        MyKonfa.set(:my_var, 'blah')
        MyKonfa.get(:my_var).should eq('blah')
      end

      MyKonfa.get(:my_var).should be(test_value)
    end

    it "works even if an exception is raised" do
      expect {
        MyKonfa.with_config(:my_var => 'blah') do
          MyKonfa.get(:my_var).should eq('blah')
          raise Exception.new('This is en error')
        end
      }.to raise_error

      MyKonfa.get(:my_var).should be(test_value)
    end

    it "works with multiple values" do
      MyKonfa.with_config(:my_var => 'my new value', :default_is_nil => 'a val') do
        MyKonfa.get(:my_var).should eq('my new value')
        MyKonfa.get(:default_is_nil).should eq('a val')
      end
      MyKonfa.get(:my_var).should be(test_value)
      MyKonfa.get(:default_is_nil).should_not eq('a val')
    end

    it "returns the result of the block" do
      retval = MyKonfa.with_config(:my_var => 'my new value') do
        MyKonfa.get(:my_var)
      end

      MyKonfa.get(:my_var).should be(test_value)
      retval.should eq('my new value')
    end
  end

  context "#true? and #false?" do
    it "implements a shorthand for boolean operations" do
      MyKonfa.respond_to?(:'true?').should be_true
      MyKonfa.respond_to?(:'false?').should be_true
    end

    it "raises an exception for true? if variable does not exist" do
      expect {
        MyKonfa.true?(:does_not_exist)
      }.to raise_error(Konfa::UnsupportedVariableError)
    end

    it "raises an exception for false? if variable does not exist" do
      expect {
        MyKonfa.false?(:does_not_exist)
      }.to raise_error(Konfa::UnsupportedVariableError)
    end

    it "considers values 1, yes or true to be true" do
      ['true', '1', 'yes', 'on'].each do |truthy|
        MyKonfa.set :my_var, truthy
        MyKonfa.true?(:my_var).should be_true
        MyKonfa.false?(:my_var).should be_false
      end
    end

    it "considers nil or any value other than 1, yes or true to be false" do
      [nil, '0', 'false', 'blah', 'NOT TRUE'].each do |falsy|
        MyKonfa.set :my_var, falsy
        MyKonfa.true?(:my_var).should be_false
        MyKonfa.false?(:my_var).should be_true
      end
    end

    it "is case insensitive" do
      ['True', 'trUe', 'yEs', 'YES', 'oN'].each do |truthy|
        MyKonfa.set :my_var, truthy
        MyKonfa.true?(:my_var).should be_true
        MyKonfa.false?(:my_var).should be_false
      end
    end

    it "ignores whitespace" do
      ['    true', ' on ', '1    '].each do |truthy|
        MyKonfa.set :my_var, truthy
        MyKonfa.true?(:my_var).should be_true
        MyKonfa.false?(:my_var).should be_false
      end
    end
  end

  context "#after_initialize" do
    it "calls after_initialize when initialized from environment" do
      MyKonfa.should_receive(:after_initialize)
      MyKonfa.initialize_from_env
    end

    it "calls after_initialize when initialized from yaml" do
      MyKonfa.should_receive(:after_initialize)
      MyKonfa.initialize_from_yaml(good_file)
    end
  end
end