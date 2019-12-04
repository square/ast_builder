module AstBuilder
  # Represents a literal token entity to avoid any quotation marks on inspect.
  # Parser::AST will recursively call nodes, using `inspect` for anything
  # that's not a `Node` type, so we can cheat to get the macro language in
  # here.
  class LiteralToken
    def initialize(string)
      @string = string
    end

    # Converts to a string. If we happen to have gotten some
    # extra fun we make sure it's a string representation instead
    # of a node.
    #
    # @return [String]
    def to_s
      @string.to_s
    end

    # Won't show quotes around it, which we need for literal tokens
    #
    # @return [String]
    def inspect
      to_s
    end
  end
end
