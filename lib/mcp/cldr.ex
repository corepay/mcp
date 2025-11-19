defmodule Mcp.Cldr do
  @moduledoc false
  use Cldr,
    locales: ["en", "fr"],
    default_locale: "en",
    providers: [Cldr.Number, Cldr.DateTime, Cldr.List, Cldr.Unit]
end
