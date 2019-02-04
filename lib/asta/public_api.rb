require 'asta/literal_token'
require 'asta/builder'

module Asta
  module PublicApi
    # Builds an AST Node from Asta shorthand syntax
    #
    # @see Asta::Builder
    #   For more notes on usage
    #
    # @param string = nil [String]
    #   Literal String to build
    #
    # @param &fn [Proc]
    #   `instance_eval`'d function used to build an s-expression
    #
    # @return [Asta::Builder]
    def build(string = nil, &fn)
      Builder.new(string, &fn)
    end
  end
end