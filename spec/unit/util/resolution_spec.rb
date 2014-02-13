#! /usr/bin/env ruby

require 'spec_helper'
require 'facter/util/resolution'

describe Facter::Util::Resolution do
  include FacterSpec::ConfigHelper

  subject(:resolution) { described_class.new(:foo, stub_fact) }

  let(:stub_fact) { stub('fact', :name => :stubfact) }

  it "requires a name" do
    expect { Facter::Util::Resolution.new }.to raise_error(ArgumentError)
  end

  it "requires a fact" do
    expect { Facter::Util::Resolution.new('yay') }.to raise_error(ArgumentError)
  end

  it "can return its name" do
    expect(resolution.name).to eq :foo
  end

  it "should be able to set the value" do
    resolution.value = "foo"
    expect(resolution.value).to eq "foo"
  end

  it "should default to nil for code" do
    expect(resolution.code).to be_nil
  end

  describe "when setting the code" do
    before do
      Facter.stubs(:warnonce)
    end

    it "should set the code to any provided string" do
      resolution.setcode "foo"
      expect(resolution.code).to eq "foo"
    end

    it "should set the code to any provided block" do
      block = lambda { }
      resolution.setcode(&block)
      resolution.code.should equal(block)
    end

    it "should prefer the string over a block" do
      resolution.setcode("foo") { }
      expect(resolution.code).to eq "foo"
    end

    it "should fail if neither a string nor block has been provided" do
      expect { resolution.setcode }.to raise_error(ArgumentError)
    end
  end

  describe "when returning the value" do
    it "should return any value that has been provided" do
      resolution.value = "foo"
      expect(resolution.value).to eq "foo"
    end

    describe "and setcode has not been called" do
      it "should return nil" do
        Facter::Core::Execution.expects(:exec).with(nil, nil).never
        resolution.value.should be_nil
      end
    end

    describe "and the code is a string" do
      describe "on windows" do
        before do
          given_a_configuration_of(:is_windows => true)
        end

        it "should return the result of executing the code" do
          resolution.setcode "/bin/foo"
          Facter::Core::Execution.expects(:exec).once.with("/bin/foo").returns "yup"

          expect(resolution.value).to eq "yup"
        end
      end

      describe "on non-windows systems" do
        before do
          given_a_configuration_of(:is_windows => false)
        end

        it "should return the result of executing the code" do
          resolution.setcode "/bin/foo"
          Facter::Core::Execution.expects(:exec).once.with("/bin/foo").returns "yup"

          expect(resolution.value).to eq "yup"
        end
      end
    end

    describe "and the code is a block" do
      it "should warn but not fail if the code fails" do
        resolution.setcode { raise "feh" }
        Facter.expects(:warn)
        resolution.value.should be_nil
      end

      it "should return the value returned by the block" do
        resolution.setcode { "yayness" }
        expect(resolution.value).to eq "yayness"
      end
    end
  end

  describe "setting options" do
    it "can set the value" do
      resolution.set_options(:value => 'something')
      expect(resolution.value).to eq 'something'
    end

    it "can set the timeout" do
      resolution.set_options(:timeout => 314)
      expect(resolution.limit).to eq 314
    end

    it "can set the weight" do
      resolution.set_options(:weight => 27)
      expect(resolution.weight).to eq 27
    end

    it "fails on unhandled options" do
      expect do
        resolution.set_options(:foo => 'bar')
      end.to raise_error(ArgumentError, /Invalid resolution options.*foo/)
    end
  end

  describe "evaluating" do
    it "evaluates the block in the context of the given resolution" do
      subject.expects(:has_weight).with(5)
      subject.evaluate { has_weight(5) }
    end

    it "raises a warning if the resolution is evaluated twice" do
      Facter.expects(:warn).with do |msg|
        expect(msg).to match /Already evaluated foo at.*reevaluating anyways/
      end

      subject.evaluate { }
      subject.evaluate { }
    end
  end
end
