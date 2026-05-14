if !Jail::Test.root?
  puts "Skipping jail tests: not running as root"
  exit(1)
end

describe "Jail" do
  let(:root) { Jail::Test.root }

  describe "constants" do
    it "defines CREATE" do
      expect(Jail::CREATE).must_equal 0x01
    end

    it "defines UPDATE" do
      expect(Jail::UPDATE).must_equal 0x02
    end

    it "defines ATTACH" do
      expect(Jail::ATTACH).must_equal 0x04
    end

    it "defines DYING" do
      expect(Jail::DYING).must_equal 0x08
    end
  end

  describe ".flags" do
    it "returns a hash of flag constants" do
      flags = Jail.flags
      expect(flags).must_be_instance_of Hash
      expect(flags[:create]).must_equal 0x01
      expect(flags[:update]).must_equal 0x02
      expect(flags[:attach]).must_equal 0x04
      expect(flags[:dying]).must_equal 0x08
    end
  end

  describe ".set" do
    let(:jid) { Jail.set({"path" => root, "persist" => 1}, Jail::CREATE) }
    after { Jail.remove(jid) if jid }

    it "creates a jail with path and persist" do
      expect(jid).must_be_kind_of Integer
      expect(jid >= 0).must_equal true
    end
  end

  describe ".get" do
    let(:jid) { Jail.set({"path" => root, "persist" => 1}, Jail::CREATE) }
    let(:result) do
      Jail.get({
        "jid" => jid,
        "persist" => nil,
        "path" => nil,
        "name" => nil,
        "host.hostname" => nil
      }, 0)
    end
    after { Jail.remove(jid) if jid }

    it "returns a hash of jail parameters" do
      expect(result).must_be_instance_of Hash
      expect(result["jid"]).must_equal jid
      expect(result["path"].to_s.strip).must_equal root
      expect(result["persist"]).must_equal 1
    end
  end

  describe ".attach" do
    let(:jid) { Jail.set({"path" => root, "persist" => 1}, Jail::CREATE) }
    after { Jail.remove(jid) if jid }

    it "attaches to a jail" do
      err = nil
      pid = Process.fork do
        begin
          Jail.attach(jid)
          exit 0
        rescue SystemCallError
          exit 1
        end
      end
      _, status = Process.waitpid2(pid)
      err = RuntimeError.new("attach failed in child process") unless status.success?
      if err
        expect(err).must_be_kind_of RuntimeError
      end
    end
  end

  describe ".remove" do
    let(:jid) { Jail.set({"path" => root, "persist" => 1}, Jail::CREATE) }

    it "removes a jail" do
      result = Jail.remove(jid)
      expect(result).must_be_nil
      expect do
        Jail.get({"jid" => jid, "name" => nil}, 0)
      end.must_raise Errno::ENOENT
    end
  end

  describe ".create" do
    let(:jname) { Jail::Test.name("mruby-test") }

    it "creates a jail instance" do
      jail = Jail.create(path: root, name: name)
      expect(jail).must_be_instance_of Jail
      expect(jail["jid"]).must_be_kind_of Integer
      expect(jail["jid"] >= 0).must_equal true
      expect(jail["name"]).must_equal name
      jail.remove
    end

    it "sets hostname when given" do
      jail = Jail.create(path: root, name: Jail::Test.jname("mruby-host-test"), hostname: "test.local")
      expect(jail["host.hostname"].to_s.strip).must_equal "test.local"
      jail.remove
    end
  end

  describe ".find_by_id" do
    let(:jname) { Jail::Test.name("mruby-find-test") }
    let(:created) { Jail.create(path: root, name: name) }
    after { created.remove if created }

    it "finds a jail by its JID" do
      found = Jail.find_by_id(created["jid"])
      expect(found).must_be_instance_of Jail
      expect(found["jid"]).must_equal created["jid"]
      expect(found["name"]).must_equal name
    end
  end

  describe ".find_by_name" do
    let(:jname) { Jail::Test.name("mruby-find-name-test") }
    let(:created) { Jail.create(path: root, name: name) }
    before { created }
    after { created.remove if created }

    it "finds a jail by its name" do
      found = Jail.find_by_name(name)
      expect(found).must_be_instance_of Jail
      expect(found["name"]).must_equal name
    end
  end

  describe "#[]" do
    let(:jname) { Jail::Test.name("mruby-read-test") }
    let(:jail) { Jail.create(path: root, name: name, hostname: "read.local") }
    after { jail.remove if jail }

    it "reads a parameter from the kernel" do
      expect(jail["host.hostname"].to_s.strip).must_equal "read.local"
    end
  end

  describe "#[]=" do
    let(:jname) { Jail::Test.name("mruby-write-test") }
    let(:jail) { Jail.create(path: root, name: name) }
    after { jail.remove if jail }
    before { jail["host.hostname"] = "write.local" }

    it "updates a parameter immediately" do
      expect(jail["host.hostname"].to_s.strip).must_equal "write.local"
    end
  end

  describe "#inspect" do
    let(:jname) { Jail::Test.name("mruby-inspect-test") }
    let(:jail) { Jail.create(path: root, name: name) }
    let(:str) { jail.inspect }
    after { jail.remove if jail }

    it "returns a human-readable representation" do
      expect(str).must_include "Jail"
      expect(str).must_include name
    end
  end

  describe ".all_by_id" do
    it "returns an array of JIDs" do
      jids = Jail.all_by_id
      expect(jids).must_be_instance_of Array
    end
  end

  describe ".all_by_name" do
    it "returns an array of names" do
      names = Jail.all_by_name
      expect(names).must_be_instance_of Array
    end
  end
end


Minitest.run(ARGV) || exit(1)
