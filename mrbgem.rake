MRuby::Gem::Specification.new('mruby-jail') do |spec|
  spec.license = '0BSD'
  spec.author  = '0x1eef'
  spec.summary = 'mruby libjail interface'
  spec.add_dependency 'mruby-errno'
  spec.add_dependency 'mruby-iijson'

  if ENV["ENV"] == "test"
    spec.add_dependency 'mruby-minitest', github: "0x1eef/mruby-minitest", branch: "main"
    spec.add_dependency "mruby-process", github: "0x1eef/mruby-process", branch: "main"
  end

  spec.cc.flags << '-Wall'
  spec.cc.flags << '-Wpedantic'
  spec.linker.libraries << 'jail'
end
