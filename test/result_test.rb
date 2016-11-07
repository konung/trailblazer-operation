require "test_helper"
require "dry-matcher"

class ResultTest < Minitest::Spec
  let (:success) { Trailblazer::Operation::Result.new(true, "x"=> String) }
  it { success.success?.must_equal true }
  it { success.failure?.must_equal false }
  # it { success["success?"].must_equal true }
  # it { success["failure?"].must_equal false }
  it { success["x"].must_equal String }
  it { success["not-existant"].must_equal nil }
  it { success.slice("x").must_equal [String] }
  it { success.inspect.must_equal %{<Result:true {\"x\"=>String} >} }

  class Create < Trailblazer::Operation
    self.> ->(input, options) { input.call }

    def call(*)
      self[:message] = "Result objects are actually quite handy!"
    end
  end

  # #result[]= allows to set arbitrary k/v pairs.
  it { Create.()[:message].must_equal "Result objects are actually quite handy!" }
end
