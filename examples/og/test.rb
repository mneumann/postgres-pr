$LOAD_PATH.unshift '../../lib'
require 'rubygems'
require 'og'
require 'glue/logger'

$DBG = true

class User
end

class Comment
  prop_accessor :body, String
  belongs_to :user, User
end

class User
  prop_accessor :name, String
  has_many :comments, Comment
end

if __FILE__ == $0
  config = {
    :address => "localhost",
    :database => "mneumann",
    :backend => "psql",
    :user => "mneumann",
    :password => "",
    :connection_count => 1
  }
  $log = Logger.new(STDERR)
  $og = Og::Database.new(config)

  $og.get_connection

  u1 = User.new
  u1.name = "Michael Neumann"
  u1.save!

  u2 = User.new
  u2.name = "John User"
  u2.save!

  c1 = Comment.new
  c1.body = "og test"
  c1.user = u1
  c1.save!

  p User.all
  p Comment.all
end
