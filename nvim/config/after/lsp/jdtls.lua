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

-- Lombok, as a JVM agent on the language server itself.
--
-- Nothing else will do. Lombok does not generate source that jdtls could read;
-- it rewrites the compiler's own syntax tree while the compiler is running, so
-- the getters and setters an annotation promises exist only inside a JVM that
-- loaded Lombok as an agent. jdtls without it reports every `@Data`,
-- `@Getter`, `@Builder` and `@Slf4j` class as missing the methods the rest of
-- the project calls on it — a file full of errors that Maven compiles without
-- a word. This is the whole fix for that.
--
-- The jar is nvim/update.sh's, at a fixed path outside this repo; see the
-- lombok section there for why it is a pinned download rather than the copy
-- Maven already put in ~/.m2.
--
-- JDTLS_JVM_ARGS is nvim-lspconfig's own way in: its `cmd` reads that variable
-- and turns each whitespace-separated word into a `--jvm-arg=` for the jdtls
-- launcher. Using it means not restating the launcher, the data directory or
-- the workspace layout here, which is the same bargain the rest of this file
-- makes. It also means the value is read from Neovim's environment rather than
-- from `cmd_env`, so this is set on the process — unlike JAVA_HOME below,
-- which is deliberately not. That is safe in a way JAVA_HOME is not: nothing
-- but a jdtls launcher has ever read JDTLS_JVM_ARGS, so a `:terminal` that
-- inherits it inherits something inert.
--
-- Appended rather than assigned, so a value exported by the shell survives.
-- And no spaces in the path, because the splitting is on whitespace.
local lombok = vim.fs.joinpath(vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share"), "java", "lombok.jar")

if vim.fn.filereadable(lombok) == 1 then
  local existing = vim.env.JDTLS_JVM_ARGS
  local arg = "-javaagent:" .. lombok
  if not (existing or ""):find(arg, 1, true) then
    vim.env.JDTLS_JVM_ARGS = existing and (existing .. " " .. arg) or arg
  end
elseif not vim.g.davconf_lombok_warned then
  -- Worth saying out loud rather than letting it look like a broken project:
  -- without the agent, Lombok classes are wrong and nothing explains why.
  -- Once per session, not once per evaluation — Neovim resolves this file
  -- again every time it works out a configuration for jdtls, and a warning
  -- that repeats is a warning that gets scrolled past.
  vim.g.davconf_lombok_warned = true
  vim.notify("lombok.jar is missing — run ./nvim/update.sh, or Lombok classes will show errors", vim.log.levels.WARN)
end

-- Spring Boot's half of the work that happens inside jdtls.
--
-- The Spring Boot language server is a separate process — see
-- lua/plugins/spring-boot.lua — but a good part of what it knows it cannot
-- find out on its own: which beans a project declares, what a `@Value`
-- resolves to, where an `@Autowired` field is satisfied from. All of that is
-- the Java model, and only jdtls has it. These jars are the Eclipse plugins
-- that let the two talk: loaded into jdtls, they answer the Boot server's
-- questions about the project.
--
-- Without them the Boot server still starts and still completes
-- application.properties keys, because those come from the spring-configuration
-- metadata in the jars on the classpath. It is the Java-side navigation that
-- quietly does not work.
--
-- pcall because this file has to keep working when the plugin is not there —
-- a machine that has not run lazy.nvim yet, or a `:Lazy` that failed. jdtls
-- with no bundles is jdtls without Spring, not a broken Java setup.
local ok, spring_boot = pcall(require, "spring_boot")
local bundles = ok and spring_boot.java_extensions() or {}

---@type vim.lsp.Config
return {
  cmd_env = launcher and { JAVA_HOME = launcher } or nil,

  -- Eclipse plugins loaded into the language server. Empty when spring-boot.nvim
  -- is not installed, which is the same as not passing it at all.
  init_options = { bundles = bundles },

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
