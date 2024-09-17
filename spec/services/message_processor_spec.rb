RSpec.describe MessageProcessor do
  describe "#append" do
    let(:input) { "hello" }

    before do
      input.lines.each { |line| subject.append(line) }
    end

    it "returns the processed output and the raw output" do
      expect(subject.append(" world")).to eq([" world", " world"])
    end

    it "appends the given string" do
      subject.append(" world")
      expect(subject.output).to eq("hello world")
      expect(subject.input).to eq("hello world")
    end

    context "when the intput contains newlines" do
      let(:input) { "hello\nworld" }

      it "replaces newlines with <br> tags" do
        expect(subject.output).to eq("hello<br>\nworld")
      end
    end

    context "when the input contains code blocks" do
      let(:input) do
        <<~INPUT
          Ruby program:

          ```ruby
          def hello
            puts "Hello, World!"
          end

          hello
          ```
        INPUT
      end
      let(:expected_output) do
        <<~OUTPUT
          Ruby program:<br>
          <br>
          ```ruby<br>
          def hello<br>
          &nbsp;&nbsp;puts &quot;Hello, World!&quot;<br>
          end<br>
          <br>
          hello<br>
          ```<br>
        OUTPUT
      end

      it "replaces leading spaces with '&nbsp;'" do
        expect(subject.output).to eq(expected_output)
      end
    end
  end
end
