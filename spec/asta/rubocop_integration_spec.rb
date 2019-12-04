RSpec.describe 'RuboCop Integration with AstBuilder' do
  describe RuboCop::Lint::ShortHandBlock do
    subject(:cop) { described_class.new }

    describe 'Detecting offenses' do
      context 'With valid code' do
        it 'raises no errors with a shorthand block' do
          expect_no_offenses <<~RUBY
            [1, 2, 3].map(&:even?)
          RUBY
        end

        it 'raises no errors with a long block that does more than one thing' do
          expect_no_offenses <<~RUBY
            [1, 2, 3].map { |v| v + 2 }
          RUBY
        end
      end

      context 'With invalid code' do
        it 'raises errors' do
          expect_offense <<~RUBY
            [1, 2, 3].map { |v| v.even? }
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use shorthand block syntax
          RUBY
        end

        it 'raises errors on a multi-line block' do
          expect_offense <<~RUBY
            [1, 2, 3].map do |v|
            ^^^^^^^^^^^^^^^^^^^^ Use shorthand block syntax
              v.even?
            end
          RUBY
        end
      end
    end

    describe 'Autocorrecting offenses' do
      it 'autocorrects a single-line block' do
        new_source = autocorrect_source <<~RUBY
          [1, 2, 3].map { |v| v.even? }
        RUBY

        expect(new_source).to eq <<~RUBY
          [1, 2, 3].map(&:even?)
        RUBY
      end
    end
  end
end
