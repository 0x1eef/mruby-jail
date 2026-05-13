##
# The {Jail} class provides a compact Ruby interface to FreeBSD jails.
# It wraps the native `libjail` binding with a small object API for
# creating, finding, querying, updating, attaching, and removing jails.
#
# @example
#   jail = Jail.create(path: "/tmp/jail", name: "example",
#                      hostname: "example.local", persist: true)
#   jail["host.hostname"] = "example.local"
#   puts jail["name"]
#   jail.remove
class Jail
  ##
  # Creates a jail and returns a {Jail} instance for it.
  # @param [String] path The jail root path
  # @param [String, nil] name The jail name
  # @param [String, nil] hostname The jail hostname
  # @param [Boolean] persist Whether to create a persistent jail
  # @param [Hash] params Additional jail parameters
  # @return [Jail]
  def self.create(path:, name: nil, hostname: nil, persist: true, **params)
    raw = {}
    params.each do |key, value|
      raw[key.to_s] = value
    end
    raw["path"] = path
    raw["name"] = name if name
    raw["host.hostname"] = hostname if hostname
    raw["persist"] = persist ? 1 : 0
    jid = set(raw, CREATE)
    new(jid: jid, name: name)
  end

  ##
  # Returns a {Jail} instance for an existing jail by JID.
  # @param [Integer] jid The jail ID
  # @return [Jail]
  def self.find_by_id(jid)
    new(jid:)
  end

  ##
  # Finds a jail by name and returns a {Jail} instance for it.
  # @param [String] name The jail name
  # @return [Jail]
  def self.find_by_name(name)
    jail = all.find { _1["name"] == name }
    raise Errno::ENOENT, "jail_get" unless jail
    jail
  end

  ##
  # Returns the JIDs of all running jails.
  # @return [Array<Integer>]
  def self.all_by_id
    jids = []
    last = 0
    loop do
      begin
        result = get({"jid" => 0, "lastjid" => last}, 0)
        last = result["jid"]
        break unless last && last != 0
        jids << last
      rescue Errno::ENOENT
        break
      end
    end
    jids
  end

  ##
  # Returns all running jails as {Jail} instances.
  # @return [Array<Jail>]
  def self.all
    all_by_id.map { find_by_id(_1) }
  end

  ##
  # Returns the names of all running jails.
  # @return [Array<String, nil>]
  def self.all_by_name
    all.map(&:name)
  end

  ##
  # Returns a new jail wrapper.
  # @param [Integer, nil] jid The jail ID selector
  # @param [String, nil] name The jail name selector
  # @return [Jail]
  def initialize(jid: nil, name: nil)
    @jid = jid
    @name = name
  end

  ##
  # Returns the jail ID
  # @return [Integer, nil]
  def id
    @jid || self["jid"]
  end
  alias_method :jid, :id

  ##
  # Returns the jail name
  # @return [String, nil]
  def name
    @name || self["name"]
  end

  ##
  # Returns the jail path
  # @return [String]
  def path
    self["path"]
  end

  ##
  # Returns the jail hostname
  # @return [String, nil]
  def hostname
    self["host.hostname"]
  end

  ##
  # Reads a jail parameter from the kernel.
  # @param [String, Symbol] name The jail parameter name
  # @return [Object]
  def [](name)
    key = name.to_s
    return @jid if key == "jid" && @jid
    result = self.class.get(selector.merge(key => nil), 0)
    value = result[key]
    @jid = value if key == "jid" && value
    @name = value.to_s.strip if key == "name" && value && !value.to_s.strip.empty?
    if key == "name" && (value.nil? || value.to_s.strip.empty?) && @name
      return @name
    end
    value
  end

  ##
  # Updates a jail parameter immediately.
  # @param [String, Symbol] name The jail parameter name
  # @param [Object] value The parameter value
  # @return [Object] The assigned value
  def []=(name, value)
    key = name.to_s
    self.class.set(selector.merge(key => value), UPDATE)
    @name = value if key == "name"
    value
  end

  ##
  # Attaches the current process to the jail.
  # @return [Integer]
  def attach
    self.class.attach(jid)
  end

  ##
  # Removes the jail from the system.
  # @return [Integer]
  def remove
    self.class.remove(jid)
  end

  ##
  # Returns a human-readable representation of the jail.
  # @return [String]
  def inspect
    "#<Jail jid=#{jid} name=#{name.inspect}>"
  end

  private

  def selector
    selector = {}
    selector["jid"] = @jid if @jid
    selector["name"] = @name if !@jid && @name
    if selector.empty?
      raise ArgumentError, "jail selector requires jid or name"
    end
    selector
  end
end
