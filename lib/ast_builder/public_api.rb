require 'ast_builder/literal_token'
require 'ast_builder/builder'

module AstBuilder
  module PublicApi
    # Builds an AST Node from AstBuilder shorthand syntax
    #
    # @see AstBuilder::Builder
    #   For more notes on usage
    #
    # @param string = nil [String]
    #   Literal String to build
    #
    # @param &fn [Proc]
    #   `instance_eval`'d function used to build an s-expression
    #
    # @return [AstBuilder::Builder]
    def build(string = nil, &fn)
      Builder.new(string, &fn)
    end
  end
end
