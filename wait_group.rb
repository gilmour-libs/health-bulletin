require 'thread'

class WaitGroup

  attr_reader :lock

  private
  attr_writer :lock
  public

  def initialize
    @done = false
    @count = 0
    self.lock = Mutex.new
  end

  def add n = 1
    lock.synchronize do
      @count += n
    end
  end

  def done
    lock.synchronize do
      @count -= 1
      if @count == 0
        @done = true
      end
    end
  end

  def status
    lock.synchronize do
      @done
    end
  end

  def wait_thread
    Thread.new {
      loop {
        sleep 1
        break if status
      }
      yield if block_given?
    }
  end

  def wait(&blk)
    wait_thread(&blk)
  end

  def wait_join &blk
    wait_thread(&blk).join
  end
end

def test
  wg = WaitGroup.new
  wg.add 3

  3.times {
    #wg.done
    Thread.new {
      t = 2
      puts "sleeping for #{t}\n"
      sleep(t)
      wg.done
    }
  }

  wg.wait_join do
    puts "yayy done"
  end

  puts "Ok"
end
