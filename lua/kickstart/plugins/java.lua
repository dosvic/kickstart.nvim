-- https://ptrtojoel.dev/posts/so-you-want-to-write-java-in-neovim/
-- needs to have jdtls via mason installed
-- jdtls requires java 21
return {
  {
    'mfussenegger/nvim-jdtls',
    ft = 'java',
    dependencies = {
      'hrsh7th/nvim-cmp',
      'hrsh7th/cmp-nvim-lsp',
    },
    config = function()
      local java_cmds = vim.api.nvim_create_augroup('java_cmds', { clear = true })
      local cache_vars = {}

      local root_files = {
        'pom.xml',
        'mvnw',
        'build.gradle',
        'build.gradle.kts',
        'settings.gradle',
        'settings.gradle.kts',
        'gradlew',
        '.git',
        'build.sbt',
      }

      local features = {
        -- change this to `true` to enable codelens
        codelens = true,

        -- change this to `true` if you have `nvim-dap`,
        -- `java-test` and `java-debug-adapter` installed
        debugger = true,
      }

      local function mason_package_path(name)
        return vim.fn.stdpath 'data' .. '/mason/packages/' .. name
      end

      local function get_jdtls_paths()
        if cache_vars.paths then
          return cache_vars.paths
        end

        local path = {}

        path.data_dir = vim.fn.stdpath 'cache' .. '/nvim-jdtls'

        local jdtls_install = mason_package_path 'jdtls'

        -- Automatically download lombok.jar if missing
        local lombok_path = jdtls_install .. '/lombok.jar'
        -- if vim.fn.filereadable(lombok_path) == 0 then
        --   vim.notify('Downloading lombok.jar...', vim.log.levels.INFO)
        --   local result = os.execute(string.format('curl -L -o "%s" https://projectlombok.org/downloads/lombok.jar', lombok_path))
        --   if result ~= 0 then
        --     vim.notify('Failed to download lombok.jar!', vim.log.levels.ERROR)
        --   end
        -- else
        --   vim.notify('lombok.jar found', vim.log.levels.INFO)
        -- end
        path.java_agent = lombok_path

        path.launcher_jar = vim.fn.glob(jdtls_install .. '/plugins/org.eclipse.equinox.launcher_*.jar')

        if vim.fn.has 'mac' == 1 then
          path.platform_config = jdtls_install .. '/config_mac'
        elseif vim.fn.has 'unix' == 1 then
          path.platform_config = jdtls_install .. '/config_linux'
        elseif vim.fn.has 'win32' == 1 then
          path.platform_config = jdtls_install .. '/config_win'
        end

        path.bundles = {}

        ---
        -- Include java-test bundle if present
        ---
        local java_test_path = mason_package_path 'java-test'

        local java_test_bundle = vim.split(vim.fn.glob(java_test_path .. '/extension/server/*.jar'), '\n')

        -- vim.notify('java_test_bundle: ' .. vim.inspect(java_test_bundle), vim.log.levels.INFO)
        -- vim.notify('java_test_bundle[1]: ' .. vim.inspect(java_test_bundle[1]), vim.log.levels.INFO)
        -- vim.notify('java_test_bundle[1] ~= "": ' .. vim.inspect(java_test_bundle[1] ~= ''), vim.log.levels.INFO)

        if java_test_bundle[1] ~= '' then
          vim.list_extend(path.bundles, java_test_bundle)
        end

        ---
        -- Include java-debug-adapter bundle if present
        ---
        local java_debug_path = mason_package_path 'java-debug-adapter'

        local java_debug_bundle = vim.split(vim.fn.glob(java_debug_path .. '/extension/server/com.microsoft.java.debug.plugin-*.jar'), '\n')

        if java_debug_bundle[1] ~= '' then
          vim.list_extend(path.bundles, java_debug_bundle)
        end

        ---
        -- Useful if you're starting jdtls with a Java version that's
        -- different from the one the project uses.
        ---
        -- path.runtimes = {
        --   -- Note: the field `name` must be a valid `ExecutionEnvironment`,
        --   -- you can find the list here:
        --   -- https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
        --   --
        --   -- This example assume you are using sdkman: https://sdkman.io
        --   {
        --     name = 'JavaSE-17',
        --     path = vim.fn.expand '/usr/bin/java',
        --   },
        -- }

        cache_vars.paths = path

        return path
      end

      local function project_name(root_dir)
        return vim.fn.fnamemodify(root_dir, ':t')
      end

      local function project_workspace_dir(base_dir, root_dir)
        local root_path = vim.fn.fnamemodify(root_dir, ':p')
        local workspace_id = root_path:gsub('[/\\:]', '_'):gsub('_+', '_'):gsub('^_', '')
        return base_dir .. '/' .. workspace_id
      end

      local function get_jdtls_client(bufnr)
        for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, name = 'jdtls' }) do
          return client
        end
      end

      local function get_active_jdtls_clients()
        local clients = {}
        local seen = {}

        for _, client in ipairs(vim.lsp.get_clients { name = 'jdtls' }) do
          local root_dir = client.config and client.config.root_dir
          if root_dir and not seen[root_dir] then
            seen[root_dir] = true
            table.insert(clients, client)
          end
        end

        table.sort(clients, function(a, b)
          local a_root = a.config.root_dir
          local b_root = b.config.root_dir
          return a_root < b_root
        end)

        return clients
      end

      local function stop_jdtls_client(client)
        if not client then
          return
        end

        local name = project_name(client.config.root_dir)
        vim.lsp.stop_client(client.id)
        vim.notify('Stopped jdtls: ' .. name, vim.log.levels.INFO)
      end

      local function enable_codelens(bufnr)
        pcall(vim.lsp.codelens.refresh)

        vim.api.nvim_create_autocmd('BufWritePost', {
          buffer = bufnr,
          group = java_cmds,
          desc = 'refresh codelens',
          callback = function()
            pcall(vim.lsp.codelens.refresh)
          end,
        })
      end

      local function enable_debugger(bufnr)
        require('jdtls').setup_dap { hotcodereplace = 'auto' }
        require('jdtls.dap').setup_dap_main_class_configs()

        local opts = { buffer = bufnr }
        -- Test execution (without debugging)
        vim.keymap.set('n', '<leader>tc', "<cmd>lua require('jdtls').test_class()<cr>", opts)
        vim.keymap.set('n', '<leader>tm', "<cmd>lua require('jdtls').test_nearest_method()<cr>", opts)

        -- Debug tests (with debugging enabled)
        vim.keymap.set('n', '<leader>dc', "<cmd>lua require('jdtls').test_class({ config = { dap = true } })<cr>", opts)
        vim.keymap.set('n', '<leader>dm', "<cmd>lua require('jdtls').test_nearest_method({ config = { dap = true } })<cr>", opts)
      end

      local function jdtls_on_attach(client, bufnr)
        --vim.lsp.inlay_hint(bufnr, true)
        if features.debugger then
          enable_debugger(bufnr)
        end

        if features.codelens then
          enable_codelens(bufnr)
        end

        -- The following mappings are based on the suggested usage of nvim-jdtls
        -- https://github.com/mfussenegger/nvim-jdtls#usage

        local opts = { buffer = bufnr }
        vim.keymap.set('n', '<leader>oi', "<cmd>lua require('jdtls').organize_imports()<cr>", opts)
        vim.keymap.set('n', '<leader>rv', "<cmd>lua require('jdtls').extract_variable()<cr>", opts)
        vim.keymap.set('x', '<leader>rv', "<esc><cmd>lua require('jdtls').extract_variable(true)<cr>", opts)
        vim.keymap.set('n', '<leader>rc', "<cmd>lua require('jdtls').extract_constant()<cr>", opts)
        vim.keymap.set('x', '<leader>rc', "<esc><cmd>lua require('jdtls').extract_constant(true)<cr>", opts)
        vim.keymap.set('x', '<leader>rm', "<esc><Cmd>lua require('jdtls').extract_method(true)<cr>", opts)
        vim.keymap.set('n', '<leader>pjp', "<cmd>lua require('jdtls').javap()<cr>", opts)
      end

      local function jdtls_setup(event)
        local jdtls = require 'jdtls'
        local extendedClientCapabilities = jdtls.extendedClientCapabilities
        extendedClientCapabilities.onCompletionItemSelectedCommand = 'editor.action.triggerParameterHints'

        local bufname = vim.api.nvim_buf_get_name(event.buf)
        if bufname == '' or bufname:match '^%a[%w+.-]*://' then
          return
        end

        local root_dir = jdtls.setup.find_root(root_files, bufname)
        if not root_dir then
          vim.notify('jdtls: no project root found for ' .. bufname, vim.log.levels.WARN)
          return
        end

        local path = get_jdtls_paths()
        local data_dir = project_workspace_dir(path.data_dir, root_dir)

        if cache_vars.capabilities == nil then
          jdtls.extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

          local ok_cmp, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
          cache_vars.capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), ok_cmp and cmp_lsp.default_capabilities() or {})
        end

        -- The command that starts the language server
        -- See: https://github.com/eclipse/eclipse.jdt.ls#running-from-the-command-line
        local cmd = {
          'java',

          '-Declipse.application=org.eclipse.jdt.ls.core.id1',
          '-Dosgi.bundles.defaultStartLevel=4',
          '-Declipse.product=org.eclipse.jdt.ls.core.product',
          '-Dlog.protocol=true',
          '-Dlog.level=ALL',
          '-javaagent:' .. path.java_agent,
          '-Xms1g',
          '--add-modules=ALL-SYSTEM',
          '--add-opens',
          'java.base/java.util=ALL-UNNAMED',
          '--add-opens',
          'java.base/java.lang=ALL-UNNAMED',

          -- 💀
          '-jar',
          path.launcher_jar,

          -- 💀
          '-configuration',
          path.platform_config,

          -- 💀
          '-data',
          data_dir,
        }

        local lsp_settings = {
          java = {
            -- jdt = {
            --   ls = {
            --     vmargs = "-XX:+UseParallelGC -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Dsun.zip.disableMemoryMapping=true -Xmx1G -Xms100m"
            --   }
            -- },
            project = {
              referencedLibraries = {
                -- add any library jars here for the lsp to pick them up
              },
            },
            eclipse = {
              downloadSources = true,
            },
            configuration = {
              updateBuildConfiguration = 'interactive',
              runtimes = path.runtimes,
            },
            maven = {
              downloadSources = false,
            },
            implementationsCodeLens = {
              enabled = true,
            },
            referencesCodeLens = {
              enabled = true,
            },
            references = {
              includeDecompiledSources = true,
            },
            inlayHints = {
              enabled = true,
              --parameterNames = {
              --   enabled = 'all' -- literals, all, none
              --}
            },
            format = {
              enabled = false,
              -- settings = {
              --   profile = 'asdf'
              -- },
            },
          },
          signatureHelp = {
            enabled = true,
          },
          completion = {
            favoriteStaticMembers = {
              'org.hamcrest.MatcherAssert.assertThat',
              'org.hamcrest.Matchers.*',
              'org.hamcrest.CoreMatchers.*',
              'org.junit.jupiter.api.Assertions.*',
              'java.util.Objects.requireNonNull',
              'java.util.Objects.requireNonNullElse',
              'org.mockito.Mockito.*',
            },
          },
          contentProvider = {
            preferred = 'fernflower',
          },
          extendedClientCapabilities = jdtls.extendedClientCapabilities,
          sources = {
            organizeImports = {
              starThreshold = 9999,
              staticStarThreshold = 9999,
            },
          },
          codeGeneration = {
            toString = {
              template = '${object.className}{${member.name()}=${member.value}, ${otherMembers}}',
            },
            useBlocks = true,
          },
        }

        -- This starts a new client & server,
        -- or attaches to an existing client & server depending on the `root_dir`.
        jdtls.start_or_attach {
          cmd = cmd,
          settings = lsp_settings,
          on_attach = jdtls_on_attach,
          capabilities = cache_vars.capabilities,
          root_dir = root_dir,
          flags = {
            allow_incremental_sync = true,
          },
          init_options = {
            bundles = path.bundles,
            extendedClientCapabilities = extendedClientCapabilities,
          },
        }
      end

      vim.api.nvim_create_user_command('JdtlsStopCurrent', function()
        local client = get_jdtls_client(0)
        if not client then
          vim.notify('No jdtls client attached to current buffer', vim.log.levels.INFO)
          return
        end

        stop_jdtls_client(client)
      end, { desc = 'Stop jdtls for the current buffer project' })

      vim.api.nvim_create_user_command('JdtlsStopPick', function()
        local clients = get_active_jdtls_clients()
        if vim.tbl_isempty(clients) then
          vim.notify('No active jdtls clients', vim.log.levels.INFO)
          return
        end

        vim.ui.select(clients, {
          prompt = 'Stop jdtls project',
          format_item = function(client)
            return string.format('%s — %s', project_name(client.config.root_dir), client.config.root_dir)
          end,
        }, function(choice)
          if not choice then
            return
          end

          stop_jdtls_client(choice)
        end)
      end, { desc = 'Pick and stop an active jdtls project' })

      vim.api.nvim_create_user_command('JdtlsList', function()
        local clients = get_active_jdtls_clients()
        if vim.tbl_isempty(clients) then
          vim.notify('No active jdtls clients', vim.log.levels.INFO)
          return
        end

        local lines = { 'Active jdtls clients:' }
        for _, client in ipairs(clients) do
          table.insert(lines, string.format('- [%d] %s', client.id, client.config.root_dir))
        end

        vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
      end, { desc = 'List active jdtls projects' })

      vim.api.nvim_create_autocmd('FileType', {
        group = java_cmds,
        pattern = { 'java' },
        desc = 'Setup jdtls',
        callback = jdtls_setup,
      })
    end,
  },
}
