-- Spring Boot, as a second language server beside jdtls.
--
-- Spring is a framework, not a language, and jdtls treats it as one more
-- library: it resolves the annotations and it type-checks the code, and that
-- is all. Everything Spring knows about itself that is not expressible in Java
-- is invisible to it — that `spring.datasource.url` is a real property and
-- `spring.datasource.urls` is a typo, which beans exist, what an `@Autowired`
-- constructor argument will actually be given at runtime. None of that lives
-- in the source; it lives in spring-configuration-metadata.json inside the
-- jars, and in an index of the project's own annotations.
--
-- The Spring Boot language server reads both. It is the same server VS Code's
-- Spring Boot extension runs, shipped inside that extension's vsix, and it is
-- what turns application.yml from a text file into something with completion
-- and diagnostics.
--
-- Two processes, not one. The Boot server owns application.properties,
-- application.yml and spring.factories outright, and it is a second opinion on
-- Java buffers next to jdtls — bean navigation and the Spring-aware code
-- lenses, on top of jdtls' own diagnostics. The `source = "if_many"` in
-- lsp.lua's diagnostic config is what keeps their virtual text attributable.
--
-- The Java-side half of this is in after/lsp/jdtls.lua, which loads the
-- extension's Eclipse plugins into jdtls so the two servers can talk. Neither
-- half is useful without the other.

-- The vsix, from mason. It is not in the `servers` list in lsp.lua because
-- that list is nvim-lspconfig server names for mason-lspconfig to install and
-- enable, and this is neither: nvim-lspconfig has no Spring Boot entry at all,
-- and spring-boot.nvim brings its own lsp/spring-boot.lua instead. So the
-- install is done here, by hand, against mason's registry.
local PACKAGE = "vscode-spring-boot-tools"

return {
  {
    "JavaHello/spring-boot.nvim",

    -- The three filetypes the server has an opinion about. `jproperties` is
    -- Neovim's name for .properties files; `yaml` is broader than
    -- application.yml, but the plugin's own root_dir narrows it back down to
    -- files the Boot server should actually see.
    ft = { "java", "yaml", "jproperties" },

    -- mason only. The plugin's README also lists nvim-jdtls and fzf-lua, and
    -- neither is a dependency in any real sense: nothing in the plugin
    -- requires either one. nvim-jdtls is there because most people reach this
    -- plugin through it, and fzf-lua only backs the `:SpringBoot` symbol
    -- pickers, which fall back to what is available.
    dependencies = { "mason-org/mason.nvim" },

    opts = {
      -- Do not start the Boot server in every Java project. The plugin
      -- attaches on filetype, and a plain Java or Angular-backend repo would
      -- get a second JVM started for nothing; this walks the build files
      -- looking for Spring Boot before allowing it.
      project_filter = function(root_dir)
        return require("spring_boot.util").has_spring_boot_dependency(root_dir)
      end,

      -- Warnings and worse. The default already, stated because the
      -- alternative — a server logging into the message area on every project
      -- import — is the kind of thing you only discover by turning it on.
      log_level = "warn",
    },

    -- Not `opts` alone: setup() resolves the server jar as it runs, so on a
    -- machine where mason has not fetched it yet it has to wait for the
    -- install rather than warn and give up.
    config = function(_, opts)
      local registry = require("mason-registry")

      -- refresh() runs the callback immediately unless the registry is stale,
      -- in which case it fetches first. Either way get_package() below is
      -- talking to a registry that has been loaded, which on a fresh machine
      -- it otherwise would not be.
      registry.refresh(vim.schedule_wrap(function()
        local found, pkg = pcall(registry.get_package, PACKAGE)
        if not found then
          vim.notify(PACKAGE .. " is not in mason's registry — Spring Boot support is off", vim.log.levels.WARN)
          return
        end

        if pkg:is_installed() then
          require("spring_boot").setup(opts)
          return
        end

        -- First run on this machine. The install is a ~100MB vsix, so this
        -- says what it is doing rather than appearing to hang, and sets the
        -- server up when it lands instead of on the next start.
        vim.notify("Installing " .. PACKAGE .. " for Spring Boot support…")
        pkg:install():once("closed", vim.schedule_wrap(function()
          if pkg:is_installed() then
            require("spring_boot").setup(opts)
            vim.notify(PACKAGE .. " installed — reopen the file for Spring Boot support")
          else
            vim.notify(PACKAGE .. " failed to install — see :MasonLog", vim.log.levels.WARN)
          end
        end))
      end))
    end,
  },
}
