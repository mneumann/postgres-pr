require 'binary_writer'
require 'binary_reader'

# Fixed size buffer.
class Buffer

  class Error < RuntimeError; end
  class EOF < Error; end 

  def initialize(size)
    raise ArgumentError if size < 0

    @size = size
    @position = 0
    @content = "#" * @size
  end

  def size
    @size
  end

  def position
    @position
  end

  def position=(new_pos)
    raise ArgumentError if new_pos < 0 or new_pos > @size
    @position = new_pos
  end

  def at_end?
    @position == @size
  end

  def content
    @content
  end

  def read(n)
    raise EOF, 'cannot read beyond the end of buffer' if @position + n > @size
    str = @content[@position, n]
    @position += n
    str
  end

  def write(str)
    sz = str.size
    raise EOF, 'cannot write beyond the end of buffer' if @position + sz > @size
    @content[@position, sz] = str
    @position += sz
    self
  end

  def copy_from_stream(stream, n)
    raise ArgumentError if n < 0
    while n > 0
      str = stream.read(n) 
      write(str)
      n -= str.size
    end
  end

  def write_cstring(cstr)
    raise ArgumentError, "Invalid Ruby/cstring" if cstr.include?("\000")
    write(cstr)
    write("\000")
  end

  # returns a Ruby string without the trailing NUL character
  def read_cstring
    nul_pos = @content.index(0, @position)
    raise Error, "no cstring found!" unless nul_pos

    sz = nul_pos - @position
    str = @content[@position, sz]
    @position += sz + 1
    return str
  end

  # read till the end of the buffer
  def read_rest
    read(self.size-@position)
  end

  include BinaryWriterMixin
  include BinaryReaderMixin
end
