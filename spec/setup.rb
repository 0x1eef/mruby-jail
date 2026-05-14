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

  def self.remove(jail)
    Jail.remove(jail.id)
  rescue Errno::ENOENT
    Jail.find_by_name(jail.name).remove
  end

  def self.remove_all
    Jail.all.each do |jail|
      remove(jail) if jail.path == root
    end
  end
end
