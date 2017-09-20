require "test_helper"

class TaskWrapTest < Minitest::Spec
  MyMacro = ->( (options, *args), *) do
    options["MyMacro.contract"] = options[:contract]
    [ Trailblazer::Circuit::Right, [options, *args] ]
  end

  class Create < Trailblazer::Operation
    step :model!
    # step [ MyMacro, { name: "MyMacro" }, { dependencies: { "contract" => :external_maybe } }]
    step(
      task: MyMacro,
      node_data: { id: "MyMacro" },

      runner_options: {
        alteration: [
          [ :insert_before!, "task_wrap.call_task",
            node: [ Trailblazer::Operation::TaskWrap::Injection::ReverseMergeDefaults( contract: "MyDefaultContract" ), id: "inject.reverse_merge_defaults.{:contract=>MyDefaultContract}" ],
            incoming: Proc.new{ true },
            outgoing: [ Trailblazer::Circuit::Right, {} ]
          ],
        ]
      }

    )

    def model!(options, **)
      options["options.contract"] = options[:contract]
      true
    end
  end

  # it { Create.__call__("adsf", options={}, {}).inspect("MyMacro.contract", "options.contract").must_equal %{} }

  #-
  # default gets set by Injection.
  it do
    direction, (options, _) = Create.__call__( [{}, {}] )

    Trailblazer::Hash.inspect(options, "options.contract", :contract, "MyMacro.contract").
      must_equal %{{"options.contract"=>nil, :contract=>"MyDefaultContract", "MyMacro.contract"=>"MyDefaultContract"}}
  end

  # injected from outside, Injection skips.
  it do
    direction, (options, _) = Create.__call__( [ { :contract=>"MyExternalContract" }, {} ] )

    Trailblazer::Hash.inspect(options, "options.contract", :contract, "MyMacro.contract").
      must_equal %{{"options.contract"=>"MyExternalContract", :contract=>"MyExternalContract", "MyMacro.contract"=>"MyExternalContract"}}
  end

  #- Nested task_wraps should not override the outer.
  AnotherMacro = ->( (options, *args), *) do
    options["AnotherMacro.another_contract"] = options[:another_contract]
    [ Trailblazer::Circuit::Right, [options, *args] ]
  end

  class Update < Trailblazer::Operation
    step(
      task: ->( (options, *args), * ) {
          _d, *o = Create.__call__( [ options, *args ] )

          [ Trailblazer::Circuit::Right, *o ]
        },
        node_data: { id: "Create" }
    )
    step(
      task:       AnotherMacro,
      node_data:  { id: "AnotherMacro" },

      runner_options: {
        alteration: [
          [ :insert_before!, "task_wrap.call_task",
            node: [ Trailblazer::Operation::TaskWrap::Injection::ReverseMergeDefaults( another_contract: "AnotherDefaultContract" ), id: "inject.reverse_merge_defaults.{:another_contract=>AnotherDefaultContract}" ],
            incoming: Proc.new{ true },
            outgoing: [ Trailblazer::Circuit::Right, {} ]
          ],
        ]
      }
    )
  end

  it do
    direction, (options, _) = Update.__call__( [ {}, {} ] )

    Trailblazer::Hash.inspect(options, "options.contract", :contract, "MyMacro.contract", "AnotherMacro.another_contract").
      must_equal %{{"options.contract"=>nil, :contract=>"MyDefaultContract", "MyMacro.contract"=>"MyDefaultContract", "AnotherMacro.another_contract"=>"AnotherDefaultContract"}}
  end
end
