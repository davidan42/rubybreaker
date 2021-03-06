#-
# This file overrides the describe method of RSpec to call the RubyBreaker
# setup first.

RUBYBREAKER_RSPEC_PREFIX = "__rubybreaker" #:nodoc:

if defined?(RSpec)
  alias :"#{RUBYBREAKER_RSPEC_PREFIX}_describe" :describe #:nodoc:
end

def describe(*args,&blk) #:nodoc:
  RubyBreaker.run if defined?(RubyBreaker) 
  send(:"#{RUBYBREAKER_RSPEC_PREFIX}_describe", *args, &blk)
end

