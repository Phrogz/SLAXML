package = "SLAXML"
version = "0.8-0"
source = {
  url = "https://github.com/Phrogz/SLAXML.git"
}
description = {
  summary = "SAX-like streaming XML parser for Lua",
  detailed = [[
      SLAXML is a pure-Lua SAX-like streaming XML parser. It is more robust than many (simpler) pattern-based parsers that exist (such as http://phrogz.net/lua/AKLOMParser.lua), properly supporting code like <expr test="5 > 7" />, CDATA nodes, comments, namespaces, and processing instructions.

      It is currently not a truly valid XML parser, however, as it allows certain XML that is syntactically-invalid (not well-formed) to be parsed without reporting an error.
    ]],
  homepage = "https://github.com/Phrogz/SLAXML",
  maintainer = "Gavin Kistner <avin@phrogz.net>",
  license = "MIT"
}
dependencies = {
  "lua ~> 5.1",
}
build = {
  type = "builtin",

  modules = {
    ["slaxml"] = "slaxml.lua",
    ["slaxdom"] = "slaxdom.lua"
  }
}
