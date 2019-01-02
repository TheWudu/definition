# frozen_string_literal: true

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "definition"
  gem "dry-validation"
  gem "awesome_print"
  gem "benchmark-ips"
end

DrySchema = Dry::Validation.Params do
  configure do
    config.type_specs = true
  end

  required(:name, :string).value(type?: String)
  required(:time, :time).value(type?: String)
end

DefinitionSchema = Definition.Keys do
  required(:name, Definition.Type(String))
  required(:time, Definition.Type(Time))
end

puts "Benchmark with valid input data:"
valid_data = { name: "test", time: Time.now }
ap DefinitionSchema.conform(valid_data).value
ap DrySchema.call(valid_data)
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("definition") do
    DefinitionSchema.conform(valid_data)
  end

  x.report("dry-validation") do
    DrySchema.call(valid_data)
  end

  x.compare!
end

puts "Benchmark with invalid input data:"
invalid_data = { name: 1, time: Time.now.to_s }
ap DefinitionSchema.conform(invalid_data).error_message
ap DrySchema.call(invalid_data).errors
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("definition") do
    DefinitionSchema.conform(invalid_data)
  end

  x.report("dry-validation") do
    DrySchema.call(invalid_data)
  end

  x.compare!
end
