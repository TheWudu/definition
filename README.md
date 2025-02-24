# Definition

[![Build Status](https://circleci.com/gh/Goltergaul/definition.svg?style=svg)][circleci]
[![Gem Version](https://badge.fury.io/rb/definition.svg)][rubygems]

Simple and composable validation and coercion of data structures. It also includes a ValueObject for convenience.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'definition'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install definition

## Usage

Definitions can be used to validate data structures like for example Hashes:

```ruby
schema = Definition.Keys do
  required :first_name, Definition.Type(String)
  required :last_name, Definition.Type(String)
  optional :birthday, Definition.Type(Date)
end

conform_result = schema.conform({first_name: "John", last_name: "Doe", birthday: Date.today})
conform_result.passed? # => true

conform_result = schema.conform({first_name: "John", last_name: "Doe", birthday: "2018/02/09"})
conform_result.passed? # => false
conform_result.error_message # => hash fails validation for key birthday: { Is of type String instead of Date }
conform_result.error_hash # =>
# {
#     :birthday => [
#         [0] <Definition::ConformError
#               description: "hash fails validation for key birthday: { Is of type String instead of Date }",
#               json_pointer: "/birthday">
#     ]
# }
```

But it can also transform those data structures at the same time. The following
example shows how a Unix timestamp in milliseconds can be transformed to a Time
object while validating:

```ruby
milliseconds_time_definition = Definition.Lambda(:milliseconds_time) do |value|
  conform_with(Time.at(value.to_r / 1000).utc) if value.is_a?(Integer)
end

schema = Definition.Keys do
  required :title, Definition.Type(String)
  required :body, Definition.Type(String)
  optional :publication_date, milliseconds_time_definition
end

conform_result = schema.conform({title: "My first blog post", body: "Shortest one ever!", publication_date: 1546170180339})
conform_result.passed? # => true
conform_result.value # => {title: "My first blog post", body: "Shortest one ever!", publication_date: 2018-12-30 11:43:00 UTC}
```

Because definitions do not only validate input but also transform input, we use
the term `conform` which stands for validation and coercion.

### Handling errors

#### I18n translated errors
For end users you best use the translated errors that you get from definition:

```ruby
schema = Definition.Keys do
  required :title, Definition.NonEmptyString
  required :body, Definition::And(
                    Definition.Type(String),
                    Definition.MinSize(100)
                  )
end

conform_result = schema.conform({title: "", body: "this is not long enough"})
conform_result.errors # => returns an array of Definition::ConformError
conform_result.errors.each do |error|
  puts "----"
  puts error.json_pointer # provides a path to the invalid value, also works with nested objects and arrays
  puts error.translated_error
end
# =>
# ----
# /title
# Value is shorter than 1
# ----
# /body
# Value is shorter than 100
```

The error messages are only translated into English for now, but you can add or change translations by adding a yaml file like [this](./config/locales/en.yml) to your I18n load path.

#### Other ways of accessing errors

To get a quick error summary during debugging, you can also use `conform_result.error_message`

Instead of getting a flat array of all errors via `conform_result.errors`, you can also get a hierarchical representation:

```ruby
conform_result.error_hash
# =>
# {
#     :title => [
#         [0] <Definition::ConformError 
# 	 message: "hash fails validation for key title: { Not all definitions are valid for 'non_empty_string': { Did not pass test for min_size (1) } }", 
# 	 json_pointer: "/title">
#     ],
#      :body => [
#         [0] <Definition::ConformError 
# 	 message: "hash fails validation for key body: { Not all definitions are valid for 'and': { Did not pass test for min_size (100) } }", 
# 	 json_pointer: "/body">
#     ]
# }

```

### Value Objects

```ruby
class User < Definition::ValueObject
  definition(Definition.Keys do
    required :username, Definition.Type(String)
    required :password, Definition.Type(String)
  end)
end

user = User.new(username: "johndoe", password: "zg(2ds8x2/")
user.username # => "johndoe"
user[:username] # => "johndoe"
user.username = "Alice" # => NoMethodError (ValueObjects are immutable)
user[:username] = "Alice" # => FrozenError (ValueObjects are immutable)

User.new(username: "johndoe") # => Definition::InvalidValueObjectError: hash does not include :password
```

Value objects delegate all calls to the output value of the defined definition,
so in this example you can use all methods that are defined on `Hash` also on the
user object. If you use a `Keys` definition, the value object additionally defines
convenient accessor methods for all attributes.

Value Objects can also be used for all other data structures that can be validated
by a definition, for example arrays:

```ruby
class IntegerArray < Definition::ValueObject
  definition(Definition.Each(Definition.Type(Integer)))
end

array = IntegerArray.new([1,2,3])
array.first # => 1

IntegerArray.new([1,2,"3"]) # => Definition::InvalidValueObjectError: Not all items conform with each: { Item "3" did not conform to each: { Is of type String instead of Integer } }
```

You can access the conform result object via `InvalidValueObjectError#conform_result`

#### Nesting value Objects

Value objects can be nested by either using the value object itself as type definition,
or by using the `CoercibleValueObject` Definition. The latter would convert input
hashes that conform with the value objects schema to an instance of the value object.

```ruby
class IntegerArray < Definition::ValueObject
  definition(Definition.Each(Definition.Type(Integer)))
end

class User < Definition::ValueObject
  definition(Definition.Keys do
    required :username, Definition.Type(String)
    required :scores, Definition.CoercibleValueObject(IntegerArray)
  end)
end

object = User.new(username: "John", scores: [1,2,3])
object.scores.class.name # => IntegerArray
```

### Conforming Hashes

Hashes can be conformed by using the `Keys` definition. It allows you to configure
required and optional attributes. The first argument of `required` and `optional`
takes either Symbols or Strings. If you use a Symbol, then the validated Hash
needs to have a Symbol key with that name, otherwise a string key.

The key definition will also fail if the input value contains extra keys.

You can configure default values for optional keys, see the following example.

```ruby
Definition.Keys do
  required :title, Definition.NonEmptyString
  optional :publication_date, Definition.Type(Date)
  optional :is_draft, Definition.Boolean, default: true
end
```

#### Ignoring unexpected keys

By default the `Keys` Definition does not conform with input hashes that contains
keys that are not defined in the Definition. You can set the `:ignore_extra_keys`
option to disable this.

```ruby
schema = Definition.Keys do
  option :ignore_extra_keys

  required :title, Definition.NonEmptyString
  optional :publication_date, Definition.Type(Time)
end

conform_result = schema.conform({title: "My first blog post", body: "Shortest one ever!", publication_date: Time.new})
conform_result.passed? # => true
conform_result.value # => {title: "My first blog post", publication_date: 2018-12-30 11:43:00 UTC}
```

### Validating types

This will validate that the value is of the specified type.

```ruby
Definition.Type(String)
Definition.Type(Float)
Definition.Type(MyClass)

Definition.Type(MyClass).conform(0.1).passed? # => false
Definition.Type(MyClass).conform(MyClass.new).passed? # => true
```

### Conforming types

This will validate that the value is of the specified type. But if its not it will
try to coerce it into that type. This Definition works only with primitive types.

```ruby
Definition.CoercibleType(String) # Uses String() to coerce values
Definition.CoercibleType(Float) # Uses Float() to coerce values

Definition.CoercibleType(Float).conform("0.1").passed? # => true
Definition.CoercibleType(Float).conform("0.1").value # => 0.1
```

### Combining multiple definitions with "And"

```ruby
Definition.And(definition1, definition2, ...)
```

This definition will only conform if all definitions conform. The definitions will
be processed from left to right and the output of the previous will be the input
of the next. Processing of the And-Definition stops as soon as one definition does not conform.

### Combining multiple definitions with "Or"

```ruby
Definition.Or(definition1, definition2, ...)
```

This definition will conform if at least one definition conforms. The definitions will
be processed from left to right and stop as soon as a definition conforms. The output
of that definition will be the output of the Or definition.

### Conforming array values with "Each"

```ruby
Definition.Each(item_definition)

Definition.Each(Definition.Type(Integer)).conform([1,2,3,"4"]).error_message
# => Not all items conform with each: { Item "4" did not conform to each: { Is of type String instead of Integer } }
```

This definition will only conform if all elements of the value conform to the
`item_definition`.

### Conforming with custom lambda functions

```ruby
Definition.Lambda(:password) do |value|
  matches = Regexp.new(/^
    (?=.*[a-z]) # should contain at least one lower case letter
    (?=.*[A-Z]) # should contain at least one upper case letter
    (?=.*\d)    # should contain at least one digit
    .{6,50}     # should be between 6 and 50 characters long
    $/x).match(value.to_s)
  conform_with(value) if matches
end
```

This definition can be used to build any custom validation or coercion you want.
The example above makes sure that a password conforms with a set of rules.

The block gets the input value as argument and you can do any transformation or
validation on it that you want. If you determine that the value is valid, then
you must call `conform_with` and pass it the value you want to return. This can
either be the original value or any transformed version of it. By not calling
`conform_with` you tell the definition to fail for the current input value.

The first argument of `Definition.Lambda` is a name you can give this definition.
It will only be used in the error message to make it more readable.

If you want to provide detailed custom error messages you can use `fail_with`:

```ruby
Definition.Lambda(:password) do |value|
  if !value.match(/[a-z]+/)
    fail_with("must contain at least one lower case letter")
  elsif !value.match(/[A-Z]+/)
    fail_with("must contain at least one upper case letter") 
  elsif !value.match(/\d+/)
    fail_with("must contain at least one digit") 
  elsif value.size < 6 || value.size > 50
    fail_with("must be between 6 and 50 characters long") 
  else
    conform_with(value)
  end
end
```

### Composing Definitions

Definitions are reusable and can be easily composed:

```ruby
country_code_definition = Definition.Lambda(:iso_county_code) do |value|
  if iso_code = IsoCountryCodes.find(value)
    conform_with(iso_code.alpha2)
  end
end

address_definition = Definition.Keys do
  required :street, Definition.Type(String)
  required :postal_code, Definition.Type(String)
  required :country_code, country_code_definition
end

order = Definition.Keys do
  required :user, user_definition
  required :invoice_address, address_definition
  required :shipping_address, address_definition
end
```

### Extending Key definitions with include

Besides composing Definitions, you can also include `Keys` Definitions in each 
other. This will basically copy all required and optional keys as well as defaults into the other definition.

```ruby
address_definition = Definition.Keys do
  required :street, Definition.Type(String)
  required :postal_code, Definition.Type(String)
  required :country_code, Definition.Type(String)
end

user_definition = Definition.Keys do
  required :user, user_definition

  include address_definition
end
```
Above Definition will equal the following:
```ruby
user_definition = Definition.Keys do
  required :user, user_definition

  required :street, Definition.Type(String)
  required :postal_code, Definition.Type(String)
  required :country_code, Definition.Type(String)
end
```

### Predefined Definitions

#### Strings and Arrays

```ruby
Definition.MaxSize(5).conform("house") # => pass
Definition.MaxSize(5).conform([1,2,3,4,5]) # => pass
```

```ruby
Definition.MinSize(5).conform("house") # => pass
Definition.MinSize(5).conform([1,2,3,4,5]) # => pass
```

#### Strings

```ruby
Definition.NonEmptyString.conform("house") # => pass
```

```ruby
Definition.Regex(/^\d*$/).conform("123") # => pass
```

#### Numerics

```ruby
Definition.GreaterThan(5).conform(5.1) # => pass
Definition.GreaterThanEqual(5).conform(5) # => pass
Definition.LessThan(5).conform(4) # => pass
Definition.LessThanEqual(5).conform(5) # => pass
```

#### Strings, Array, Hashes

```ruby
Definition.Empty.conform("") # => pass
Definition.Empty.conform([]) # => pass
Definition.Empty.conform({}) # => pass
```

```ruby
Definition.NonEmpty.conform("Joe") # => pass
Definition.NonEmpty.conform([1]) # => pass
Definition.NonEmpty.conform({ a: 1 }) # => pass
```

#### Nil

```ruby
Definition.Nil.conform(nil) # => pass
```

#### Boolean

```ruby
Definition.Boolean.conform(true) # => pass
```

#### All types

```ruby
Definition.Equal(5).conform(5) # => pass
Definition.Equal("foo").conform("foo") # => pass
```

The Nilable Definition allows a value to be nil or to conform
with the definition you pass it as argument:

```ruby
Definition.Nilable(Definition.Type(String)).conform(nil) # => pass
Definition.Nilable(Definition.Type(String)).conform("foo") # => pass
```

The Enum Definition checks if the input equals one of the values you pass it as argument. You can pass in as many arguments as you like:

```ruby
Definition.Enum("foo", 1, 2.0).conform("foo") # => pass
Definition.Enum("foo", 1, 2.0).conform(1) # => pass
Definition.Enum("foo", 1, 2.0).conform("bar) # => fail
```

### Examples

Check out the [integration specs](./spec/integration) for more usage examples.

### I18n translations

Every error object has a method `translated_error` that will give you a translated
version of the error message. You can load the default English translations shipped
with the gem by adding them to your I18n load path.


```ruby
schema = Definition.Keys do
  required :title, Definition.Type(String)
  required :body, Definition.Type(String)
  required(:author, Definition.Keys do
    required :name, Definition.Type(String)
    required :email, Definition.Type(String)
  end)
end
schema.conform(input_hash).errors.first.translated_error # => Value is of wrong type, needs to be a String"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Goltergaul/definition.

[circleci]: https://circleci.com/gh/Goltergaul/definition
[rubygems]: https://rubygems.org/gems/definition
