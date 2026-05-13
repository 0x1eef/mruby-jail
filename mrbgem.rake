MRuby::Gem::Specification.new('mruby-jail') do |spec|
  spec.license = '0BSD'
  spec.author  = '0x1eef'
  spec.summary = 'mruby libjail interface'

  if ENV["ENV"] == "TEST"
    spec.add_dependency 'mruby-minitest', github: "0x1eef/mruby-minitest", branch: "main"
    spec.add_dependency "mruby-process", github: "0x1eef/mruby-process", branch: "main"
  end

  spec.cc.flags << '-Wall'
  spec.cc.flags << '-Wpedantic'
  spec.linker.libraries << 'jail'
end
