# Assertions are activated by default. They are always on when in debug mode
# ($DEBUG=true). To disable them, you must set $ASSERT to false and disable
# debug mode.

class AssertionFailedError < RuntimeError
end

if $DEBUG or (not defined?($ASSERT)) or $ASSERT
  def assert(cond=nil, msg=nil, &block)
    raise AssertionFailedError, msg unless (block ? block.call : cond)
  end
else
  def assert(cond=nil, msg=nil, &block)
  end
end
