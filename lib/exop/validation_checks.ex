defmodule Exop.ValidationChecks do
  @moduledoc """
  Provides low-level validation functions:

    * check_type/3
    * check_required/3
    * check_numericality/3
    * check_in/3
    * check_not_in/3
    * check_format/3
    * check_length/3
    * check_struct/3
    * check_func/3
    * check_equals/3
    * check_exactly/3
    * check_allow_nil/3
  """

  @no_check_item :exop_no_check_item

  @type check_error :: %{(atom() | String.t()) => String.t()}

  @known_types ~w(boolean integer float string tuple map struct list atom module function keyword uuid)a

  @doc """
  Returns an check_item's value from either a Keyword or a Map by an atom-key.

  ## Examples

      iex> Exop.ValidationChecks.get_check_item(%{a: 1, b: 2}, :a)
      1

      iex> Exop.ValidationChecks.get_check_item([a: 1, b: 2], :b)
      2

      iex> Exop.ValidationChecks.get_check_item(%{a: 1, b: 2}, :c)
      nil
  """
  @spec get_check_item(Keyword.t() | map(), atom() | String.t()) :: any() | nil
  def get_check_item(check_items, item_name) when is_map(check_items) do
    Map.get(check_items, item_name)
  end

  def get_check_item(check_items, item_name) when is_list(check_items) do
    Keyword.get(check_items, item_name)
  end

  def get_check_item(_check_items, _item), do: nil

  @doc """
  Checks whether a check_item has been provided.
  Returns a boolean.

  ## Examples

      iex> Exop.ValidationChecks.check_item_present?(%{a: 1, b: 2}, :a)
      true

      iex> Exop.ValidationChecks.check_item_present?([a: 1, b: 2], :b)
      true

      iex> Exop.ValidationChecks.check_item_present?(%{a: 1, b: 2}, :c)
      false

      iex> Exop.ValidationChecks.check_item_present?(%{a: 1, b: nil}, :b)
      true
  """
  @spec check_item_present?(Keyword.t() | map(), atom() | String.t()) :: boolean()
  def check_item_present?(check_items, item_name) when is_map(check_items) do
    Map.get(check_items, item_name, @no_check_item) != @no_check_item
  end

  def check_item_present?(check_items, item_name) when is_list(check_items) do
    Keyword.get(check_items, item_name, @no_check_item) != @no_check_item
  end

  def check_item_present?(_check_items, _item), do: false

  @doc """
  Checks if an item_name presents in params if its required (true).

  ## Examples

      iex> Exop.ValidationChecks.check_required(%{}, :some_item, false)
      true

      iex> Exop.ValidationChecks.check_required([a: 1, b: 2], :a, true)
      true

      iex> Exop.ValidationChecks.check_required(%{a: 1, b: 2}, :b, true)
      true
  """
  @spec check_required(Keyword.t() | map(), atom() | String.t(), boolean) :: true | check_error
  def check_required(_check_items, _item, false), do: true

  def check_required(check_items, item_name, true) do
    check_item_present?(check_items, item_name) || %{item_name => "is required"}
  end

  @doc """
  Checks the type of an item_name.

  ## Examples

      iex> Exop.ValidationChecks.check_type(%{a: 1}, :a, :integer)
      true

      iex> Exop.ValidationChecks.check_type(%{a: "1"}, :a, :string)
      true

      iex> Exop.ValidationChecks.check_type(%{a: nil}, :a, :string)
      %{:a => "has wrong type"}
  """
  @spec check_type(Keyword.t() | map(), atom() | String.t(), atom()) :: true | check_error
  def check_type(check_items, item_name, check) do
    if check_item_present?(check_items, item_name) do
      check_item = get_check_item(check_items, item_name)

      if Enum.member?(@known_types, check) do
        do_check_type(check_item, check) || %{item_name => "has wrong type"}
      else
        true
      end
    else
      true
    end
  end

  defp do_check_type(check_item, :boolean) when is_boolean(check_item), do: true
  defp do_check_type(check_item, :integer) when is_integer(check_item), do: true
  defp do_check_type(check_item, :float) when is_float(check_item), do: true
  defp do_check_type(check_item, :string) when is_binary(check_item), do: true
  defp do_check_type(check_item, :tuple) when is_tuple(check_item), do: true

  defp do_check_type(%_{} = _check_item, :struct) do
    IO.warn("type check with :struct is deprecated, please use :map instead")
    true
  end

  defp do_check_type(_check_item, :struct) do
    IO.warn("type check with :struct is deprecated, please use :map instead")
    false
  end

  defp do_check_type(check_item, :map) when is_map(check_item), do: true
  defp do_check_type(check_item, :list) when is_list(check_item), do: true
  defp do_check_type(check_item, :atom) when is_atom(check_item), do: true
  defp do_check_type(check_item, :function) when is_function(check_item), do: true
  defp do_check_type([] = _check_item, :keyword), do: true
  defp do_check_type([{atom, _} | _] = _check_item, :keyword) when is_atom(atom), do: true

  defp do_check_type(check_item, :module) when is_atom(check_item) do
    Code.ensure_loaded?(check_item)
  end

  defp do_check_type(check_item, :uuid) when is_binary(check_item), do: validate_uuid(check_item)
  defp do_check_type(_, _), do: false

  @doc """
  Checks an item_name over numericality constraints.

  ## Examples

      iex> Exop.ValidationChecks.check_numericality(%{a: 3}, :a, %{ equal_to: 3 })
      true

      iex> Exop.ValidationChecks.check_numericality(%{a: 5}, :a, %{ greater_than_or_equal_to: 3 })
      true

      iex> Exop.ValidationChecks.check_numericality(%{a: 3}, :a, %{ less_than_or_equal_to: 3 })
      true
  """
  @spec check_numericality(Keyword.t() | map(), atom() | String.t(), map()) :: true | check_error
  def check_numericality(check_items, item_name, checks) do
    if check_item_present?(check_items, item_name) do
      check_item = get_check_item(check_items, item_name)

      cond do
        is_number(check_item) ->
          result = checks |> Enum.map(&check_number(check_item, item_name, &1))
          if Enum.all?(result, &(&1 == true)), do: true, else: result

        true ->
          %{item_name => "not a number"}
      end
    else
      true
    end
  end

  @spec check_number(number, atom() | String.t(), {atom, number}) :: boolean
  defp check_number(number, item_name, {:equal_to, check_value}) do
    if number == check_value, do: true, else: %{item_name => "must be equal to #{check_value}"}
  end

  defp check_number(number, item_name, {:eq, check_value}) do
    check_number(number, item_name, {:equal_to, check_value})
  end

  defp check_number(number, item_name, {:equals, check_value}) do
    check_number(number, item_name, {:equal_to, check_value})
  end

  defp check_number(number, item_name, {:is, check_value}) do
    check_number(number, item_name, {:equal_to, check_value})
  end

  defp check_number(number, item_name, {:greater_than, check_value}) do
    if number > check_value, do: true, else: %{item_name => "must be greater than #{check_value}"}
  end

  defp check_number(number, item_name, {:gt, check_value}) do
    check_number(number, item_name, {:greater_than, check_value})
  end

  defp check_number(number, item_name, {:greater_than_or_equal_to, check_value}) do
    if number >= check_value,
      do: true,
      else: %{item_name => "must be greater than or equal to #{check_value}"}
  end

  defp check_number(number, item_name, {:min, check_value}) do
    check_number(number, item_name, {:greater_than_or_equal_to, check_value})
  end

  defp check_number(number, item_name, {:gte, check_value}) do
    check_number(number, item_name, {:greater_than_or_equal_to, check_value})
  end

  defp check_number(number, item_name, {:less_than, check_value}) do
    if number < check_value, do: true, else: %{item_name => "must be less than #{check_value}"}
  end

  defp check_number(number, item_name, {:lt, check_value}) do
    check_number(number, item_name, {:less_than, check_value})
  end

  defp check_number(number, item_name, {:less_than_or_equal_to, check_value}) do
    if number <= check_value,
      do: true,
      else: %{item_name => "must be less than or equal to #{check_value}"}
  end

  defp check_number(number, item_name, {:lte, check_value}) do
    check_number(number, item_name, {:less_than_or_equal_to, check_value})
  end

  defp check_number(number, item_name, {:max, check_value}) do
    check_number(number, item_name, {:less_than_or_equal_to, check_value})
  end

  defp check_number(_number, _item_name, _), do: true

  @doc """
  Checks whether an item_name is a memeber of a list.

  ## Examples

      iex> Exop.ValidationChecks.check_in(%{a: 1}, :a, [1, 2, 3])
      true
  """
  @spec check_in(Keyword.t() | map(), atom() | String.t(), list()) :: true | check_error
  def check_in(check_items, item_name, check_list) when is_list(check_list) do
    check_item = get_check_item(check_items, item_name)

    if Enum.member?(check_list, check_item) do
      true
    else
      %{item_name => "must be one of #{inspect(check_list)}"}
    end
  end

  def check_in(_check_items, _item_name, _check_list), do: true

  @doc """
  Checks whether an item_name is not a memeber of a list.

  ## Examples

      iex> Exop.ValidationChecks.check_not_in(%{a: 4}, :a, [1, 2, 3])
      true
  """
  @spec check_not_in(Keyword.t() | map(), atom() | String.t(), list()) :: true | check_error
  def check_not_in(check_items, item_name, check_list) when is_list(check_list) do
    check_item = get_check_item(check_items, item_name)

    if Enum.member?(check_list, check_item) do
      %{item_name => "must not be included in #{inspect(check_list)}"}
    else
      true
    end
  end

  def check_not_in(_check_items, _item_name, _check_list), do: true

  @doc """
  Checks whether an item_name conforms the given format.

  ## Examples

      iex> Exop.ValidationChecks.check_format(%{a: "bar"}, :a, ~r/bar/)
      true
  """
  @spec check_format(Keyword.t() | map(), atom() | String.t(), Regex.t()) :: true | check_error
  def check_format(check_items, item_name, check) do
    check_item = get_check_item(check_items, item_name)

    if is_binary(check_item) do
      if Regex.match?(check, check_item) do
        true
      else
        %{item_name => "has invalid format"}
      end
    else
      true
    end
  end

  @doc """
  The alias for `check_format/3`.
  Checks whether an item_name conforms the given format.

  ## Examples

      iex> Exop.ValidationChecks.check_regex(%{a: "bar"}, :a, ~r/bar/)
      true
  """
  @spec check_regex(Keyword.t() | map(), atom() | String.t(), Regex.t()) :: true | check_error
  def check_regex(check_items, item_name, check) do
    check_format(check_items, item_name, check)
  end

  @doc """
  Checks an item_name over length constraints.

  ## Examples

      iex> Exop.ValidationChecks.check_length(%{a: "123"}, :a, %{min: 0})
      [true]

      iex> Exop.ValidationChecks.check_length(%{a: ~w(1 2 3)}, :a, %{in: 2..4})
      [true]

      iex> Exop.ValidationChecks.check_length(%{a: ~w(1 2 3)}, :a, %{is: 3, max: 4})
      [true, true]
  """
  @spec check_length(Keyword.t() | map(), atom() | String.t(), map()) :: true | [check_error]
  def check_length(check_items, item_name, checks) do
    check_item = get_check_item(check_items, item_name)

    actual_length = get_length(check_item)

    for {check, check_value} <- checks, into: [] do
      case check do
        :min -> check_min_length(item_name, actual_length, check_value)
        :max -> check_max_length(item_name, actual_length, check_value)
        :is -> check_is_length(item_name, actual_length, check_value)
        :in -> check_in_length(item_name, actual_length, check_value)
        _ -> true
      end
    end
  end

  @spec get_length(any) :: pos_integer
  defp get_length(param) when is_number(param), do: param
  defp get_length(param) when is_list(param), do: length(param)
  defp get_length(param) when is_binary(param), do: String.length(param)
  defp get_length(param) when is_atom(param), do: param |> Atom.to_string() |> get_length
  defp get_length(param) when is_map(param), do: param |> Map.to_list() |> get_length
  defp get_length(param) when is_tuple(param), do: tuple_size(param)
  defp get_length(_param), do: 0

  @spec check_min_length(atom() | String.t(), pos_integer, number) :: true | check_error
  defp check_min_length(item_name, actual_length, check_value) do
    actual_length >= check_value ||
      %{item_name => "length must be greater than or equal to #{check_value}"}
  end

  @spec check_max_length(atom() | String.t(), pos_integer, number) :: true | check_error
  defp check_max_length(item_name, actual_length, check_value) do
    actual_length <= check_value ||
      %{item_name => "length must be less than or equal to #{check_value}"}
  end

  @spec check_is_length(atom() | String.t(), pos_integer, number) :: true | check_error
  defp check_is_length(item_name, actual_length, check_value) do
    actual_length == check_value || %{item_name => "length must be equal to #{check_value}"}
  end

  @spec check_in_length(atom() | String.t(), pos_integer, Range.t()) :: true | check_error
  defp check_in_length(item_name, actual_length, check_value) do
    Enum.member?(check_value, actual_length) ||
      %{item_name => "length must be in range #{check_value}"}
  end

  @doc """
  Checks whether an item is expected structure.

  ## Examples

      defmodule SomeStruct1, do: defstruct [:a, :b]
      defmodule SomeStruct2, do: defstruct [:b, :c]

      Exop.ValidationChecks.check_struct(%{a: %SomeStruct1{}}, :a, %SomeStruct1{})
      # true
      Exop.ValidationChecks.check_struct(%{a: %SomeStruct1{}}, :a, %SomeStruct2{})
      # false
  """
  @spec check_struct(Keyword.t() | map(), atom() | String.t(), struct()) :: true | check_error
  def check_struct(check_items, item_name, check) do
    check_items
    |> get_check_item(item_name)
    |> validate_struct(check, item_name)
  end

  @doc """
  Checks whether an item is valid over custom validation function.

  ## Examples

      iex> Exop.ValidationChecks.check_func(%{a: 1}, :a, fn(_contract, param)-> param > 0 end)
      true
      iex> Exop.ValidationChecks.check_func(%{a: 1}, :a, fn(_contract, param)-> is_nil(param) end)
      %{a: "isn't valid"}
      iex> Exop.ValidationChecks.check_func(%{a: -1}, :a, fn(_contract, _param)-> {:error, :my_error} end)
      %{a: :my_error}
      iex> Exop.ValidationChecks.check_func(%{a: -1, b: 1}, :a, fn(_contract, param_name, param_value)-> {param_name, param_value} == {:a, -1} end)
      true
      iex> Exop.ValidationChecks.check_func(%{a: -1, b: 1}, :b, fn(_contract, param_name, param_value)-> {param_name, param_value} != {:a, -1} end)
      true
  """
  @spec check_func(
          Keyword.t() | map(),
          atom() | String.t(),
          (Keyword.t() | map(), any -> true | false)
        ) :: true | check_error
  def check_func(check_items, item_name, check) do
    check_item = get_check_item(check_items, item_name)

    check_result =
      case :erlang.fun_info(check)[:arity] do
        1 ->
          check.(check_item)

        2 ->
          check.(check_items, check_item)

        _ ->
          check.(check_items, item_name, check_item)
      end

    case check_result do
      {:error, msg} -> %{item_name => msg}
      false -> %{item_name => "isn't valid"}
      _ -> true
    end
  end

  @doc """
  Checks whether a parameter's value exactly equals given value (with type equality).

  ## Examples

      iex> Exop.ValidationChecks.check_equals(%{a: 1}, :a, 1)
      true
  """
  @spec check_equals(Keyword.t() | map(), atom() | String.t(), any()) :: true | check_error
  def check_equals(check_items, item_name, check_value) do
    check_item = get_check_item(check_items, item_name)

    if check_item === check_value do
      true
    else
      %{item_name => "must be equal to #{inspect(check_value)}"}
    end
  end

  @doc """
  The alias for `check_equals/3`.
  Checks whether a parameter's value exactly equals given value (with type equality).

  ## Examples

      iex> Exop.ValidationChecks.check_exactly(%{a: 1}, :a, 1)
      true
  """
  @spec check_exactly(Keyword.t() | map(), atom() | String.t(), any()) :: true | check_error
  def check_exactly(check_items, item_name, check_value) do
    check_equals(check_items, item_name, check_value)
  end

  @spec check_allow_nil(Keyword.t() | map(), atom() | String.t(), boolean()) :: true | check_error
  def check_allow_nil(_check_items, _item_name, true), do: true

  def check_allow_nil(check_items, item_name, false) do
    check_item = get_check_item(check_items, item_name)

    !is_nil(check_item) || %{item_name => "doesn't allow nil"}
  end

  @spec validate_struct(any(), any(), atom() | String.t()) :: boolean()
  defp validate_struct(%struct{}, %struct{}, _item_name), do: true

  defp validate_struct(%struct{}, struct, _item_name) when is_atom(struct), do: true

  defp validate_struct(_item, _check, item_name), do: %{item_name => "is not expected struct"}

  @spec validate_uuid(binary()) :: boolean()
  defp validate_uuid(
         <<a1, a2, a3, a4, a5, a6, a7, a8, ?-, b1, b2, b3, b4, ?-, c1, c2, c3, c4, ?-, d1, d2, d3,
           d4, ?-, e1, e2, e3, e4, e5, e6, e7, e8, e9, e10, e11, e12>>
       ) do
    <<c(a1), c(a2), c(a3), c(a4), c(a5), c(a6), c(a7), c(a8), ?-, c(b1), c(b2), c(b3), c(b4), ?-,
      c(c1), c(c2), c(c3), c(c4), ?-, c(d1), c(d2), c(d3), c(d4), ?-, c(e1), c(e2), c(e3), c(e4),
      c(e5), c(e6), c(e7), c(e8), c(e9), c(e10), c(e11), c(e12)>>
  catch
    :error -> false
  else
    _ -> true
  end

  defp validate_uuid(_), do: false

  defp c(?0), do: ?0
  defp c(?1), do: ?1
  defp c(?2), do: ?2
  defp c(?3), do: ?3
  defp c(?4), do: ?4
  defp c(?5), do: ?5
  defp c(?6), do: ?6
  defp c(?7), do: ?7
  defp c(?8), do: ?8
  defp c(?9), do: ?9
  defp c(?A), do: ?a
  defp c(?B), do: ?b
  defp c(?C), do: ?c
  defp c(?D), do: ?d
  defp c(?E), do: ?e
  defp c(?F), do: ?f
  defp c(?a), do: ?a
  defp c(?b), do: ?b
  defp c(?c), do: ?c
  defp c(?d), do: ?d
  defp c(?e), do: ?e
  defp c(?f), do: ?f
  defp c(_), do: throw(:error)
end
