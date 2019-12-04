require 'rubocop'

module AstBuilder
  class InvalidCode < StandardError; end

  class Builder
    extend RuboCop::NodePattern::Macros

    attr_reader :meta_methods

    # NodePattern won't allow numbers in meta-method calls, so
    # we need to have alpha characters instead.
    ALPHA = ('a'..'zz').to_a

    # It can either work on a literal string or on a block
    #
    # @param s = nil [String]
    #   String to convert
    #
    # @param &fn [Proc]
    #   `instance_eval`'d function to allow for some nice Sexp-like
    #   tokens to be used in construction
    #
    # @return [AstBuilder]
    def initialize(s = nil, &fn)
      @meta_methods = {}
      @ast = s ? parse(s) : instance_eval(&fn)
    end

    # Stand-in for the s-expression given from `AST::Sexp`
    # to give us some of the `Node` level features that
    # RuboCop's variant has.
    #
    # @param type [String, Symbol]
    #   Type of the node
    #
    # @param *children [Array[Node, respond_to?(:inspect)]]
    #   RuboCop compatible nodes, or meta-tokens defining
    #   `inspect` to allow for `NodePattern` interpolation
    #
    # @return [RuboCop::AST::Node]
    def s_expression(type, *children)
      RuboCop::AST::Node.new(type, children)
    end

    alias s s_expression

    # A literal token. Think any of the node matchers from Rubocop's NodePattern:
    #
    # https://rubocop.readthedocs.io/en/latest/node_pattern/
    #
    # @param string [String]
    #   String to use as a literal token
    #
    # @return [LiteralToken]
    def literal(string)
      LiteralToken.new(string)
    end

    alias l literal

    # Expands a token by parsing it instead of manually having to nest
    # the thing 3-4 layers deep for constants and the like
    #
    # @param string [String]
    #   String to expand into AST Nodes
    #
    # @return [AST::Node]
    def expand(*strings)
      strings
        .map { |s| s.is_a?(String) ? parse(s) : s }
        .yield_self { |node, *children| node.concat(children) }
    end

    alias e expand

    # Prepends a `$` to represent a captured node for matchers.
    #
    # @param string [String]
    #   String or AST (yeah yeah, names) to "capture"
    #
    # @return [LiteralToken]
    def capture(string)
      literal("$#{string}")
    end

    alias c capture

    # Captures the children of a node. Convenience function
    # combining a capture and a literal.
    #
    # @return [String]
    def capture_children
      capture literal '(...)'
    end

    # Top level method send for sexps that avoids having to type out
    # the entire `(send nil? name (...))` bit.
    #
    # @param name [String]
    #   Name of the top level keyword
    #
    # @param *sexp [Array[String, AST::Node, LiteralToken]]
    #   Anything that looks vaguely like a Sexp
    #
    # @return [AST::Node]
    def top_method_send(name, *sexp)
      s(:send, nil, name, *sexp)
    end

    alias t top_method_send

    # Regular method send for any level, normally used for things like
    # constants and otherwise.
    #
    # @param name [String]
    #   Name of the method
    #
    # @param *sexp [[Array[String, AST::Node, LiteralToken]]
    #   Anything that looks vaguely like a Sexp
    #
    # @return [AST::Node]
    def method_send(name, *sexp)
      s(:send, name, *sexp)
    end

    alias m method_send

    # Wraps a variable assignment for shorthand usage. It will try and tell
    # the difference between instance
    #
    # @param variable [Symbol]
    #   Name of the variable
    #
    # @param value [Any]
    #   Value of the variable. Could be a NodePattern literal
    #
    # @return [AST::Node]
    def assigns(variable, value)
      # Constant assignment if we got a node
      return s(:casgn, nil, variable, value) unless variable.respond_to?(:to_sym)

      variable_name = variable.to_sym

      case variable.to_s
      when /^@@/
        s(:cvasgn, variable_name, value)
      when /^@/
        s(:ivasgn, variable_name, value)
      when /^\$/
        s(:gvasgn, variable_name, value)
      when /^[[:upper:]]/
        s(:casgn, nil, variable_name, value)
      else
        s(:lvasgn, variable_name, value)
      end
    end

    # Checks to see if a given value matches a meta-method.
    #
    # In a normal NodePattern, this is a method which exists in the parent context or on the NodePattern itself. As
    # these methods are rarely used outside of this context, they can be defined instead as anonymous functions
    # using the additional flexibility of AstBuilder's builder syntax:
    #
    # ```ruby
    # assigns(:value, s(:str, matching(/abc/)))
    # ```
    #
    # Now instead of having to specify these checks in an actual handler, or defining a method on the parent
    # context, we can do so inline.
    #
    # These meta methods are then stored and defined on the generated NodePattern upon match time to ensure they're
    # within scope.
    #
    # @param value = nil [#===]
    #   Any value that responds to `===`, used to build off of the flexibility of the Ruby `case`
    #   expression.
    #
    # @param &function [Proc]
    #   A function used to match against. Note that this function _must_ have the proper arity or NodePattern will
    #   reject it.
    #
    # @return [LiteralToken]
    #   This returns a literal token instead of a string, as NodePattern expects it to be a bare word.
    def matching(value = nil, &function)
      called_function = function ? function : -> x { value === x }

      # NodePattern will not accept numbers, so we have to use letters instead.
      meta_name = "_meta_method_#{ALPHA[@meta_methods.size]}"

      @meta_methods[meta_name] = called_function

      # These macros start with the `#` symbol, making this intentional
      literal("##{meta_name}")
    end

    alias mm matching

    # This method will both use anonymous functions or values to match against and then capture the output.
    #
    # @see #matching
    #
    # @param value = nil [#===]
    #   Any value that responds to `===`, used to build off of the flexibility of the Ruby `case`
    #   expression.
    #
    # @param &function [Proc]
    #   A function used to match against. Note that this function _must_ have the proper arity or NodePattern will
    #   reject it.
    #
    # @return [LiteralToken]
    def capture_matching(value = nil, &function)
      capture(matching(value, &function))
    end

    alias cm capture_matching

    # Coerces the builder into a RuboCop NodePattern and attempts to match another value against it.
    #
    # @param other [String, AST]
    #   Either plaintext code or another AST to match against
    #
    # @return [nil]
    #   There was no match
    #
    # @return [String]
    #   The matched portion of the code
    def match(other)
      ast = other.is_a?(String) ? self.class.new(other).to_ast : other
      self.to_cop.match(ast)
    end

    # Because RuboCop has... interesting ...formatting rules we have
    # to hack around nil a bit and add a question mark.
    #
    # @return [RuboCop::NodePattern]
    #   RuboCop compatible Sexp
    def to_cop
      RuboCop::NodePattern.new(self.to_s.gsub(/\bnil\b/, 'nil?')).tap do |node_pattern|
        # If there are any meta methods defined we bind them to the node pattern to match against
        @meta_methods.each do |name, fn|
          node_pattern.define_singleton_method(name, &fn)
        end
      end
    end

    # Returns the internal AST representation as-is
    #
    # @return [AST::Node]
    def to_ast
      @ast
    end

    # String version of the AST
    #
    # @return [String]
    def to_s
      @ast.to_s
    end

    # Parses a String to a Ruby AST
    #
    # @param string [String]
    #   String to convert
    #
    # @return [AST::Node]
    private def parse(string)
      ast_results = RuboCop::ProcessedSource.new(string, RUBY_VERSION.to_f).ast

      raise InvalidCode, "The following node is invalid: \n  '#{string}'" unless ast_results

      ast_results
    end
  end
end
