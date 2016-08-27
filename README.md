# Exop

Little library that provides a few macros which allow you to encapsulate business logic and validate incoming params over predefined contract.

Inspired by [Trailblazer::Operation](http://trailblazer.to/gems/operation/) - a part of awesome high-level architecture for ruby/rails applications.

## Installation

```elixir
def deps do
  [{:exop, git: "https://github.com/madeinussr/exop"}]
end
```

## Operation definition

```elixir
defmodule IntegersDivision do
  use Exop.Operation

  parameter :a, type: :integer, default: 1
  parameter :b, type: :integer, required: true,
                numericality: %{greater_than: 0}

  def process(params) do
    result = params[:a] / params[:b]
    IO.inspect "The division result is: #{result}"
  end
end
```

`Exop.Operation` provides `parameter` macro, which is responsible for the contract definition.
Its spec is `@spec parameter(atom, Keyword.t) :: none`, we define parameter name as the first atom attribute
and paramater options as the second `Keyword` attribute.

Parameter options determine a contract of a parameter, a set of parameters contracts is an operation contract.

Business logic of an operation is defined in `process/1` function, which is required by the Exop.Operation module
behaviour.

After the contract and business logic were defined, you can invoke the operation simply by calling `run/1` function:

```elixir
iex> IntegersDivision.run(a: 50, b: 5)
"The division result is: 10"
```

### Parameter options

A parameter options could have various checks. Here the list of checks available yet:

* `type`
* `required`
* `default`
* `numericality`
* `in`
* `not_in`
* `format`
* `length`
* `inner` (experimental)

#### `type`

Checks whether a parameter's value is of declared type.

```elixir
parameter :some_param, type: :map
```

Exop handle almost all Elixir types:

* :boolean
* :integer
* :float
* :string
* :tuple
* :map
* :struct
* :list
* :atom
* :function

_Unknown type always passes this check._

#### `required`

Checks the presence of a parameter in passed to `run/1` params collection.

```elixir
parameter :some_param, required: true
```

#### `default`

Checks the presence of a parameter in passed to `run/1` params collection,
and if the parameter is missed - assign default value to it.

```elixir
parameter :some_param, default: "default value"
```

#### `numericality`

Checks whether a parameter's value is a number and other numeric constraints.
All possible constraints are listed in the example below.

```elixir
parameter :some_param, numericality: %{equal_to: 10,
                                       greater_than: 0,
                                       greater_than_or_equal_to: 10,
                                       less_than: 20,
                                       less_than_or_equal_to: 10}
```

#### `in`

Checks whether a parameter's value is within a given list.

```elixir
parameter :some_param, in: ~w(a b c)
```

#### `not_in`

Checks whether a parameter's value is not within a given list.

```elixir
parameter :some_param, not_in: ~w(a b c)
```

#### `format`

Checks wether paramter's value matches given regex.

```elixir
parameter :some_param, format: ~r/foo/
```

#### `length`

Checks the length of a parameter's value. The value should be one of handled types:

* list (items count)
* string (chars count)
* atom (treated as string)
* map (key-value pairs count)
* tuple (items count)

`length` check is complex as `numericality` (should define map of inner checks).
All possible checks are listed in the example below.

```elixir
parameter :some_param, length: %{min: 5, max: 10, is: 7, in: 5..8}
```

#### `inner`
TODO: make tests & description

## Operation invocation

As said earlier, operations in most cases called by `run/1` function. This function
receives parameters collection. It's not required to pass to `run/1` function parameters
only described in the operation's contract, but only described parameters will be validated.

`run/1` function validate received paramerers over the contract and if all parameters passed
the validation, the `run/1` function calls the code defined in `process/1` function.

```elixir
iex> SomeOperation.run(param1: 1, param2: "2")
_some_result_
```

If at least one of the given parameters didn't pass the validation `process/1` function's code
will not be invoked and corresponding warning in the application's log will appear.

You always can bypass the validation simply by calling `process/1` function itself, if needed.