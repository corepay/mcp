defmodule Mcp.Repo.Migrations.AddMoneyWithCurrencyTypeToPostgres do
  use Ecto.Migration

  def up do
    # Create Type (Idempotent)
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'money_with_currency') THEN
        CREATE TYPE public.money_with_currency AS (currency_code varchar, amount numeric);
      END IF;
    END
    $$;
    """

    # Plus Operator
    execute """
    CREATE OR REPLACE FUNCTION money_add(money_1 money_with_currency, money_2 money_with_currency)
    RETURNS money_with_currency
    IMMUTABLE
    STRICT
    LANGUAGE plpgsql
    AS $$
      DECLARE
        currency varchar;
        addition numeric;
      BEGIN
        IF (money_1).currency_code = (money_2).currency_code THEN
          currency := (money_1).currency_code;
          addition := (money_1).amount + (money_2).amount;
          return row(currency, addition)::money_with_currency;
        ELSE
          RAISE EXCEPTION
            'Incompatible currency codes for + operator. Expected both currency codes to be %', (money_1).currency_code
            USING HINT = 'Please ensure both columns have the same currency code',
            ERRCODE = '22033';
        END IF;
      END;
    $$;
    """

    execute """
    CREATE OPERATOR + (
        leftarg = money_with_currency,
        rightarg = money_with_currency,
        procedure = money_add,
        commutator = +
    );
    """

    # Minus Operator
    execute """
    CREATE OR REPLACE FUNCTION money_sub(money_1 money_with_currency, money_2 money_with_currency)
    RETURNS money_with_currency
    IMMUTABLE
    STRICT
    LANGUAGE plpgsql
    AS $$
      DECLARE
        currency varchar;
        subtraction numeric;
      BEGIN
        IF (money_1).currency_code = (money_2).currency_code THEN
          currency := (money_1).currency_code;
          subtraction := (money_1).amount - (money_2).amount;
          return row(currency, subtraction)::money_with_currency;
        ELSE
          RAISE EXCEPTION
            'Incompatible currency codes for - operator. Expected both currency codes to be %', (money_1).currency_code
            USING HINT = 'Please ensure both columns have the same currency code',
            ERRCODE = '22033';
        END IF;
      END;
    $$;
    """

    execute """
    CREATE OPERATOR - (
        leftarg = money_with_currency,
        rightarg = money_with_currency,
        procedure = money_sub
    );
    """

    # Sum Function
    execute """
    CREATE OR REPLACE FUNCTION money_sum_state_function(agg_state money_with_currency, money money_with_currency)
    RETURNS money_with_currency
    IMMUTABLE
    STRICT
    LANGUAGE plpgsql
    AS $$
      DECLARE
        expected_currency varchar;
        aggregate numeric;
        addition numeric;
      BEGIN
        if (agg_state).currency_code IS NULL then
          expected_currency := (money).currency_code;
          aggregate := 0;
        else
          expected_currency := (agg_state).currency_code;
          aggregate := (agg_state).amount;
        end if;

        IF (money).currency_code = expected_currency THEN
          addition := aggregate + (money).amount;
          return row(expected_currency, addition)::money_with_currency;
        ELSE
          RAISE EXCEPTION
            'Incompatible currency codes. Expected all currency codes to be %', expected_currency
            USING HINT = 'Please ensure all columns have the same currency code',
            ERRCODE = '22033';
        END IF;
      END;
    $$;
    """

    execute """
    CREATE OR REPLACE FUNCTION money_sum_combine_function(agg_state1 money_with_currency, agg_state2 money_with_currency)
    RETURNS money_with_currency
    IMMUTABLE
    STRICT
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF (agg_state1).currency_code = (agg_state2).currency_code THEN
          return row((agg_state1).currency_code, (agg_state1).amount + (agg_state2).amount)::money_with_currency;
        ELSE
          RAISE EXCEPTION
            'Incompatible currency codes. Expected all currency codes to be %', (agg_state1).currency_code
            USING HINT = 'Please ensure all columns have the same currency code',
            ERRCODE = '22033';
        END IF;
      END;
    $$;
    """

    execute """
    CREATE AGGREGATE sum(money_with_currency)
    (
      sfunc = money_sum_state_function,
      stype = money_with_currency,
      combinefunc = money_sum_combine_function,
      parallel = SAFE
    );
    """
  end

  def down do
    execute("DROP TYPE IF EXISTS public.money_with_currency CASCADE;")
  end
end
