defmodule Mcp.Underwriting.Services.MentionParser do
  @moduledoc """
  Parses @mentions from note content.
  Handles mention extraction and HTML rendering.
  """

  @mention_regex ~r/(?<!\S)@([a-zA-Z0-9._-]+)/

  defstruct [:mentions, :plain_text]

  @type t :: %__MODULE__{
          mentions: list(String.t()),
          plain_text: String.t()
        }

  @doc """
  Parses content for @mentions.
  Returns struct with extracted mentions and plain text.
  """
  @spec parse(String.t()) :: t()
  def parse(content) do
    mentions =
      @mention_regex
      |> Regex.scan(content)
      |> Enum.map(fn [_, username] -> username end)
      |> Enum.uniq()

    %__MODULE__{
      mentions: mentions,
      plain_text: content
    }
  end

  @doc """
  Renders content with mentions as HTML links.
  """
  @spec render_html(String.t(), list(map())) :: String.t()
  def render_html(content, users) do
    user_map = Map.new(users, fn u -> {u.username, u} end)

    Regex.replace(@mention_regex, content, fn full, username ->
      case Map.get(user_map, username) do
        nil -> full
        user -> ~s(<a href="/users/#{user.id}" class="mention">@#{user.display_name}</a>)
      end
    end)
  end
end
