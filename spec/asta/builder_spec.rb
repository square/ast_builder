RSpec.describe Asta::Builder do
  let(:fn) { nil }
  let(:string) { '1 + 1' }
  let(:builder) { Asta.build(string, &fn) }

  describe '.initialize' do
    it 'can initialize' do
      expect(builder).to be_a(Asta::Builder)
    end
  end

  describe '#s_expression' do
    it 'can create a new s_expression' do
      node = builder.s_expression(:send, nil)

      expect(node).to be_a(RuboCop::AST::Node)
      expect(node.type).to eq(:send)
      expect(node.children).to eq([nil])
    end
  end

  describe '#literal' do
    it 'can create a literal token for NodePattern matching' do
      token = builder.literal('...')

      expect(token).to be_a(Asta::LiteralToken)
      expect(token.inspect).to eq('...')
    end
  end

  describe '#expand' do
    it 'can expand the content of a string to an AST' do
      ast = builder.expand('A::B::C')

      expect(ast.to_s).to eq <<~AST.chomp
        (const
          (const
            (const nil :A) :B) :C)
      AST
    end

    it 'can take multiple expressions' do
      ast = builder.expand('A::B::C', builder.capture_children)

      expect(ast.to_s).to eq <<~AST.chomp
        (const
          (const
            (const nil :A) :B) :C $(...))
      AST
    end
  end

  describe '#capture' do
    it 'will add a capture to the node' do
      ast = builder.capture(builder.literal('_'))

      expect(ast.to_s).to eq '$_'
    end

    it 'will capture entire node paths' do
      ast = builder.capture(builder.expand('A::B::C'))

      expect(ast.to_s).to eq <<~AST.chomp
        $(const
          (const
            (const nil :A) :B) :C)
      AST
    end
  end

  describe '#capture_children' do
    it 'will capture all the children of a node' do
      ast = builder.assigns(builder.expand('A::B::C'), builder.capture_children)

      expect(ast.to_s).to eq <<~AST.chomp
        (casgn nil
          (const
            (const
              (const nil :A) :B) :C) $(...))
      AST
    end
  end

  describe '#assigns' do
    it 'can generate an s-expression for variable assignment' do
      ast = builder.assigns('a', builder.capture_children)

      expect(ast.to_s).to eq <<~AST.chomp
        (lvasgn :a $(...))
      AST
    end

    it 'can generate an s-expression for an instance variable assignment' do
      ast = builder.assigns('@a', builder.capture_children)

      expect(ast.to_s).to eq <<~AST.chomp
        (ivasgn :@a $(...))
      AST
    end

    it 'can generate an s-expression for a class variable assignment' do
      ast = builder.assigns('@@a', builder.capture_children)

      expect(ast.to_s).to eq <<~AST.chomp
        (cvasgn :@@a $(...))
      AST
    end

    it 'can generate an s-expression for a global variable assignment' do
      ast = builder.assigns('$a', builder.capture_children)

      expect(ast.to_s).to eq <<~AST.chomp
        (gvasgn :$a $(...))
      AST
    end

    it 'can generate an s-expression for a constant assignment' do
      ast = builder.assigns('A', builder.capture_children)

      expect(ast.to_s).to eq <<~AST.chomp
        (casgn nil :A $(...))
      AST
    end
  end

  describe '#matching' do
    it 'will define a meta method on the builder and leave a literal token' do
      ast = builder.matching(/abc/)

      expect(ast.to_s).to eq <<~AST.chomp
        #_meta_method_a
      AST

      expect(builder.meta_methods['_meta_method_a']).to be_a(Proc)
    end
  end

  describe '#capture_matching' do
    it 'will define a meta method on the builder and leave a literal token' do
      ast = builder.capture_matching(/abc/)

      expect(ast.to_s).to eq <<~AST.chomp
        $#_meta_method_a
      AST

      expect(builder.meta_methods['_meta_method_a']).to be_a(Proc)
    end
  end

  describe '#match' do
    let(:fn) { proc { assigns(:a, capture_children) } }
    let(:string) { nil }

    it 'can match against a basic node' do
      variable_value, *_ = builder.match('a = 1').children

      expect(variable_value).to eq(1)
    end

    context 'With a conditional statement being captured' do
      it 'can capture the entire statement' do
        code = <<~CODE
          a = if true
            1
          else
            2
          end
        CODE

        _condition, true_branch, false_branch = builder.match(code).children

        expect(true_branch.children.first).to eq(1)
        expect(false_branch.children.first).to eq(2)
      end
    end

    context 'With a captured meta method in the expression' do
      context 'When given a block' do
        let(:fn) { proc { assigns(:value, s(:str, capture_matching { |s| s.include?('abc') })) } }

        it 'will capture the value of a string matching the condition' do
          expect(builder.match('value = "abc123"')).to eq('abc123')
        end
      end

      context 'When given a value' do
        let(:fn) { proc { assigns(:value, s(:str, capture_matching(/abc/))) } }

        it 'will capture the value of a string matching the condition' do
          expect(builder.match('value = "abc123"')).to eq('abc123')
        end
      end
    end
  end
end
