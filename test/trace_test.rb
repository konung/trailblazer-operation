require "test_helper"

class TraceTest < Minitest::Spec
  Circuit = Trailblazer::Circuit
  Wrapped = Trailblazer::Circuit::Activity::Wrapped

  MyNested = ->(direction, options, flow_options) do
    B.__call__("start here", options, flow_options )

    [ direction, options, flow_options ]
  end

  class Create < Trailblazer::Operation
    step ->(options, **) { options[:a] = true }, name: "Create.task.a"
    step [ MyNested, {} ],                       name: "MyNested"
    step ->(options, **) { options[:c] = true }, name: "Create.task.c"

    self["__task_wraps__"] = {
      self["__sequence__"][0].step => Wrapped::Activity,
      self["__sequence__"][1].step => Wrapped::Activity,
      self["__sequence__"][2].step => Wrapped::Activity,
      nil => Wrapped::Activity
    }
  end
  # raise Create["__task_wraps__"].inspect

  class B < Trailblazer::Operation
    step ->(options, **) { options[:b] = true }, name: "B.task.b"
    step ->(options, **) { options[:e] = true }, name: "B.task.e"

    self["__task_wraps__"] = {
      self["__sequence__"][0].step => Wrapped::Activity,
      self["__sequence__"][1].step => Wrapped::Activity,
      nil => Wrapped::Activity
    }
  end

  it do
    operation = ->(*args) { Create.__call__(*args) }

    stack, _ = Trailblazer::Circuit::Trace.(
      operation,
      "[START] nil fixme start signal",
      options={},
    )

    puts output = Circuit::Trace::Present.tree(stack)

    output.gsub(/0x\w+/, "").gsub(/@.+_test/, "").must_equal %{|-- #<Trailblazer::Circuit::Start:>
|-- Create.task.a
|-- #<Proc:.rb:7 (lambda)>
|   |-- #<Trailblazer::Circuit::Start:>
|   |-- B.task.b
|   |-- B.task.e
|   |-- #<Trailblazer::Operation::Railway::End::Success:>
|   `-- #<Proc:.rb:7 (lambda)>
|-- Create.task.c
`-- #<Trailblazer::Operation::Railway::End::Success:>}
  end
end