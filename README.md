## About

mruby-jail provides a compact mruby interface to FreeBSD's libjail.
It allows you to: create and remove jails, find them by name or
jail ID (jid), read and/or update jail parameters, enumerate
running jails, and attach the current process to a jail. All
mentioned features are exposed through an easy-to-use
object-oriented interface.

## Quick start

#### Create a jail

```ruby
jail = Jail.create(path: "/tmp/jail", name: "example", hostname: "example.local")
jail.attach
```

#### Read parameters

```ruby
jail = Jail.find_by_id(1)
puts jail["name"]
puts jail["host.hostname"]
puts jail["path"]
```

#### Update parameters

```ruby
jail = Jail.find_by_id(1)
jail["host.hostname"] = "example.local"
```

#### Enumerate jails

```ruby
Jail.all.each do |jail|
  puts "JID=#{jail["jid"]} name=#{jail["name"]}"
end
```

#### Find a jail

```ruby
by_id = Jail.find_by_id(1)
by_name = Jail.find_by_name("example")
```

#### Attach to a jail

```ruby
jail = Jail.find_by_id(1)
jail.attach
```

#### Remove a jail

```ruby
jail = Jail.find_by_name("example")
jail.remove
```

## API

**`Jail.create(path:, name: nil, hostname: nil, persist: true, **params)`** <br>
Creates a jail and returns a `Jail` instance.

**`Jail.find_by_id(jid)`** <br>
Builds a `Jail` instance for an existing jail by JID.

**`Jail.find_by_name(name)`** <br>
Finds an existing jail by name and returns a `Jail` instance.

**`Jail.all`** <br>
Returns `Jail` instances for all running jails.

**`jail["param"]`** <br>
Reads a jail parameter from the kernel.

**`jail["param"] = value`** <br>
Updates a jail parameter immediately.

**`jail.attach`** <br>
Attaches the current process to the jail.

**`jail.remove`** <br>
Removes the jail from the system.

Parameter names use FreeBSD jail names such as `"name"`,
`"path"`, `"host.hostname"`, and `"persist"`.

## Integration

Add to your mruby build config:

```ruby
MRuby::Build.new("app") do |conf|
  conf.toolchain
  conf.gembox "default"
  conf.gem github: "0x1eef/mruby-jail", branch: "main"
end
```

Dependencies are declared in [mrbgem.rake](mrbgem.rake) and resolved
automatically by the mruby build system. This gem is only usable on
FreeBSD systems. The underlying syscalls and `libjail` interfaces
are FreeBSD-specific.

## License

[BSD Zero Clause](https://choosealicense.com/licenses/0bsd/)
<br>
See [LICENSE](./LICENSE)
