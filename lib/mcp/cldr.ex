defmodule Mcp.Cldr do
  use Cldr,
    locales: ["en"],
    default_locale: "en",
    providers: [Cldr.Number, Cldr.DateTime, Cldr.List, Cldr.Unit]
end