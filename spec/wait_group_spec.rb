require 'wait_group'

RSpec.describe WaitGroup, "#wg" do
  context "With a wait group" do
    it "should wait and exit after 2 seconds" do
      wg = WaitGroup.new
      wg.add 3

      3.times {
        Thread.new {
          t = 2
          puts "sleeping for #{t}\n"
          sleep(t)
          wg.done
        }
      }

      code = nil

      wg.wait_join do
        code = 200
      end

      expect(code).to eq 200
    end
  end
end
