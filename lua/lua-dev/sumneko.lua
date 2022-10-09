local config = require("lua-dev.config")

local M = {}

---@param opts LuaDevOptions
function M.library(opts)
  opts = config.merge(opts)
  local ret = {}

  if opts.library.types then
    table.insert(ret, M.types())
  end

  local function add(lib, filter)
    ---@diagnostic disable-next-line: param-type-mismatch
    for _, p in pairs(vim.fn.expand(lib .. "/lua", false, true)) do
      p = vim.loop.fs_realpath(p)
      if p and (not filter or filter[vim.fn.fnamemodify(p, ":h:t")]) then
        table.insert(ret, vim.fn.fnamemodify(p, ":h"))
      end
    end
  end

  if opts.library.runtime then
    add(type(opts.library.runtime) == "string" and opts.library.runtime or "$VIMRUNTIME")
  end

  if opts.library.plugins then
    local filter
    if type(opts.library.plugins) == "table" then
      filter = {}
      for _, p in pairs(opts.library.plugins) do
        filter[p] = true
      end
    end
    for _, site in pairs(vim.split(vim.o.packpath, ",")) do
      add(site .. "/pack/*/opt/*", filter)
      add(site .. "/pack/*/start/*", filter)
    end
  end

  return ret
end

---@param settings? lspconfig.settings.sumneko_lua
function M.path(settings)
  settings = settings or {}
  local runtime = settings.Lua and settings.Lua.runtime or {}
  local meta = runtime.meta or "${version} ${language} ${encoding}"
  meta = meta:gsub("%${version}", runtime.version or "LuaJIT")
  meta = meta:gsub("%${language}", "en-us")
  meta = meta:gsub("%${encoding}", runtime.fileEncoding or "utf8")

  return {
    -- paths for builtin libraries
    ("meta/%s/?.lua"):format(meta),
    ("meta/%s/?/init.lua"):format(meta),
    -- paths for meta/3rd libraries
    "library/?.lua",
    "library/?/init.lua",
    -- Neovim lua files, config and plugins
    "lua/?.lua",
    "lua/?/init.lua",
  }
end

function M.types()
  local f = debug.getinfo(1, "S").source:sub(2)
  local ret = vim.loop.fs_realpath(vim.fn.fnamemodify(f, ":h:h:h") .. "/types")
  return vim.loop.fs_realpath(ret .. "/" .. (vim.version().prerelease and "/nightly" or "/stable"))
end

---@param opts? LuaDevOptions
---@param settings? lspconfig.settings.sumneko_lua
function M.setup(opts, settings)
  opts = config.merge(opts)
  return {
    ---@type lspconfig.settings.sumneko_lua
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
          path = M.path(settings),
          pathStrict = false,
        },
        ---@diagnostic disable-next-line: undefined-field
        completion = opts.snippet and { callSnippet = "Replace" } or nil,
        workspace = {
          -- Make the server aware of Neovim runtime files
          library = M.library(opts),
        },
      },
    },
  }
end

return M
