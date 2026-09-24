-- Java, layered over nvim-lspconfig's own lsp/jdtls.lua.
--
-- Files under after/lsp/ are the documented way to amend a server config a
-- plugin provided: Neovim merges lsp/jdtls.lua from nvim-lspconfig with this
-- one, this side winning, and only when a Java buffer actually opens. So
-- everything nvim-lspconfig already gets right — the `jdtls` launcher, the
-- root markers that tell a Maven submodule from its parent, the per-project
-- workspace under ~/.cache/nvim/jdtls/workspace — is inherited and not
-- restated here. See :help lsp-config-merge.
--
-- Worth knowing about that workspace directory: it is jdtls's index of the
-- project, keyed only by the project directory's name, and it is not always
-- self-healing. When jdtls starts insisting on a dependency that is no longer
-- in the pom, or a source root that moved, deleting
-- ~/.cache/nvim/jdtls/workspace/<project> and reopening is the fix.
--
-- This is plain jdtls through vim.lsp, not the nvim-jdtls plugin. What that
-- leaves out is the Eclipse-specific extensions: running a single test from
-- the buffer, the debugger, "extract to method". Everything else — completion,
-- diagnostics, imports, go-to, rename, formatting, most code actions — is here.
-- nvim-jdtls is the upgrade path if the test running is ever missed.

-- Every JDK installed as a macOS package, newest first. The temurin@17, @21
-- and @25 casks in brew/Brewfile.dev all land here, and so does anything
-- installed outside this repo.
local function installed_jdks()
  local jdks = {}

  for _, home in ipairs(vim.fn.glob("/Library/Java/JavaVirtualMachines/*/Contents/Home", true, true)) do
    -- The `release` file rather than the directory name: the name is the
    -- vendor's to choose (temurin-25.jdk, but also zulu-21.jdk, openjdk.jdk
    -- with no version at all), while JAVA_VERSION in `release` is specified.
    local release = home .. "/release"
    if vim.fn.filereadable(release) == 1 then
      for _, line in ipairs(vim.fn.readfile(release)) do
        local version = line:match('^JAVA_VERSION="([^"]+)"')
        if version then
          -- 8 and earlier report themselves as 1.8.0, and Eclipse names that
          -- execution environment JavaSE-1.8 rather than JavaSE-8.
          local major = tonumber(version:match("^1%.(%d+)") or version:match("^(%d+)"))
          if major then
            table.insert(jdks, {
              major = major,
              name = major <= 8 and ("JavaSE-1." .. major) or ("JavaSE-" .. major),
              path = home,
            })
          end
          break
        end
      end
    end
  end

  table.sort(jdks, function(a, b) return a.major > b.major end)
  return jdks
end

local jdks = installed_jdks()

-- The JDK that runs the language server, which is a separate question from the
-- JDKs it compiles against. jdtls is an Eclipse application and needs 21 or
-- newer to start at all.
--
-- It matters here more than it would elsewhere because of jenv: `java` on $PATH
-- is a shim that resolves to whatever .java-version the project pins, so
-- opening a Java 17 project would hand jdtls a 17 and it would refuse to
-- launch — with a stack trace about a class file version, which reads like a
-- problem with the project rather than with the server.
--
-- cmd_env rather than setting JAVA_HOME anywhere else: nvim-lspconfig's cmd
-- passes it to the jdtls process and nothing else. A JAVA_HOME exported for the
-- whole Neovim session would be inherited by `:terminal` and by anything run
-- from it, and Maven prefers JAVA_HOME over $PATH — so a jenv-pinned project
-- would quietly compile against the wrong JDK, which is exactly the kind of
-- failure that does not look like a failure.
local launcher
for _, jdk in ipairs(jdks) do
  if jdk.major >= 21 then
    launcher = jdk.path
    break
  end
end

-- The runtimes jdtls offers projects. A Maven project usually declares its own
-- through maven.compiler.release and this list is what lets jdtls honour it
-- instead of analysing everything against whatever it happens to be running
-- on; `default` is only consulted when a project says nothing.
local runtimes = {}
for i, jdk in ipairs(jdks) do
  table.insert(runtimes, { name = jdk.name, path = jdk.path, default = i == 1 })
end

---@type vim.lsp.Config
return {
  cmd_env = launcher and { JAVA_HOME = launcher } or nil,

  settings = {
    java = {
      configuration = {
        runtimes = runtimes,
      },

      -- Sources for the jars Maven resolved, so go-to-definition into a
      -- dependency lands in its code rather than in a decompiled skeleton.
      -- It is a download per dependency on first use and then cached.
      maven = { downloadSources = true },
      eclipse = { downloadSources = true },

      format = { enabled = true },
      signatureHelp = { enabled = true },

      -- Never collapse imports into a wildcard. A star import is a merge
      -- conflict waiting to happen and hides which class a name came from;
      -- the thresholds are the number of imports from one package that would
      -- trigger one, set past any real file.
      sources = {
        organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
      },

      -- Off unless asked for, via <leader>ci. See the note in lsp.lua.
      inlayHints = { parameterNames = { enabled = "literals" } },
    },
  },
}
