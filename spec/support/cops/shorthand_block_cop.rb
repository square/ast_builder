require 'rubocop'

module RuboCop
  module Lint
    # Goal:
    #
    #   Original:  `[1,2,3].map { |v| v.even? }`
    #   Corrected: `[1,2,3].map(&:even?)`
    #
    # Example Original AST:
    #
    #   ```
    #   (block
    #     (send
    #       (array
    #         (int 1)
    #         (int 2)
    #         (int 3)) :map)
    #     (args
    #       (arg :v))
    #     (send
    #       (lvar :v) :even?))
    #   ```
    #
    # Example Corrected AST:
    #
    #   ```
    #   (send
    #     (array
    #       (int 1)
    #       (int 2)
    #       (int 3)) :map
    #     (block-pass
    #       (sym :even?)))
    #   ```
    #
    class ShortHandBlock < RuboCop::Cop::Cop
      MSG = 'Use shorthand block syntax'

      # This code will produce this NodePattern AST:
      #
      #   (block $(send ... _)
      #     (args $(...))
      #     (send $(...) $_))
      #
      # Asta is purposely more verbose to make it easier to break apart,
      # comment, and read an expression. This also means they can be composed
      # and reused to build up more advanced matchers if need be.
      AST_MATCH = Asta.build do
        # Look for a block call
        s(:block,

          # Capture the calling object and function
          capture(s(:send, literal('...'), literal('_'))),

          # Capture the names of the argument
          s(:args, capture_children),

          # Capture the variable receiving a method, and that method's name
          s(:send, capture_children, literal('$_')))
      end

      # Temporary patch for naming captures until named-captures are completed
      # in `RuboCop::NodePattern` as a syntax extension:
      #
      # https://github.com/rubocop-hq/rubocop/issues/6724
      CAPTURE_NAMES = %i(
        caller
        block_argument
        called_variable
        called_method
      )

      # We're looking for a block node, as specified in our `AST_MATCH` above.
      #
      # @param node [RuboCop::AST::Node]
      #   AST Node from RuboCop
      def on_block(node)
        named_captures = get_named_captures(node)

        # If there are no captures, bail out.
        return false unless named_captures

        # Get the names of the block and called variables from our captures.
        #
        # As these are both still s-expressions, `(arg :v)` and `(lvar :v)`,
        # we need to get the first child, which is the name of the argument.
        block_variable = named_captures[:block_argument].children.first
        called_variable = named_captures[:called_variable].children.first

        # If those two names are the same, we add an offense
        if block_variable == called_variable
          add_offense(node, location: :expression)
        end
      end

      # Autocorrects the given code
      #
      # @param node [RuboCop::AST::Node]
      #   Node to be autocorrected
      #
      # @return [Proc]
      #   Function to be passed to the Tree Rewriter when the Corrector
      #   runs over all potential changes
      def autocorrect(node)
        -> corrector do
          # Get our named captures from earlier
          named_captures = get_named_captures(node)

          # You can get the source of the nodes using `source`
          #
          # In the case of `[1,2,3].map { |v| v.even? } this would mean that we
          # have the following:
          #
          #   caller source: `[1,2,3].map`
          #   called method: `:even?`
          #
          # Why do we have to call source on the first and not the second? The
          # second is a single entity instead of an entire expression, so it
          # only has one value, it's source.
          new_source = "#{named_captures[:caller].source}(&:#{named_captures[:called_method]})"

          corrector.replace(node.location.expression, new_source)
        end
      end

      # Gets the captures from a match and zips them into a `Hash` for easier
      # use in calling functions
      #
      # @param node [RuboCop::AST::Node]
      #   AST Node from RuboCop
      #
      # @return [NilClass]
      #   Nothing will be returned if the node does not match our AST match from
      #   above.
      #
      # @return [Hash[Symbol, RuboCop::AST::Node]]
      #   Matches indexed by a given name
      private def get_named_captures(node)
        # First we check if there's a match with our query above
        match_data = AST_MATCH.match(node)

        # If not we return `nil`
        return nil unless match_data

        # If there were matches, we get back an `Array` of matches, but that
        # doesn't give us context of what exactly we matched. That means we have
        # two options for giving things names:
        #
        #   1. splat captures on the array
        #   2. zipping with an index-matching array of names
        #
        # We opt for the latter here. There's currently a feature request in
        # RuboCop for named captures to make this irrelevant later.
        named_captures = CAPTURE_NAMES.zip(match_data).to_h
      end
    end
  end
end
