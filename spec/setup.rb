module Jail::Test
  extend self

  def self.root?
    Process.euid == 0
  rescue
    false
  end

  def self.root
    path = "/tmp/mruby-jail-test"
    Dir.mkdir("/tmp") unless Dir.exist?("/tmp")
    Dir.mkdir(path) unless Dir.exist?(path)
    path
  end

  def self.jname(prefix)
    "#{prefix}-#{Process.pid}-#{Time.now.to_i}"
  end
end
