local function angular_probe_dir(root_dir)
  local node_modules = root_dir and vim.fs.find('node_modules', { path = root_dir, upward = true })[1] or nil
  if node_modules then
    return node_modules
  end

  return vim.fn.stdpath 'data' .. '/mason/packages/angular-language-server/node_modules'
end

local function angular_core_version(root_dir)
  local package_json = root_dir and vim.fs.find('package.json', { path = root_dir, upward = true })[1] or nil
  if not package_json then
    return nil
  end

  local ok_read, lines = pcall(vim.fn.readfile, package_json)
  if not ok_read then
    return nil
  end

  local ok_json, json = pcall(vim.json.decode, table.concat(lines, '\n'))
  if not ok_json or type(json) ~= 'table' or type(json.dependencies) ~= 'table' then
    return nil
  end

  local version = json.dependencies['@angular/core']
  return type(version) == 'string' and version:match '%d+%.%d+%.%d+' or nil
end

local function angular_cmd(dispatchers, config)
  local probe_dir = angular_probe_dir(config.root_dir)
  local cmd = {
    'ngserver',
    '--stdio',
    '--tsProbeLocations',
    probe_dir,
    '--ngProbeLocations',
    probe_dir,
  }

  local version = angular_core_version(config.root_dir)
  if version then
    table.insert(cmd, '--angularCoreVersion')
    table.insert(cmd, version)
  end

  return vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.root_dir })
end

return {
  {
    'williamboman/mason.nvim',
    opts = {},
    dependencies = {
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
      'hrsh7th/cmp-nvim-lsp',
    },
    config = function()
      require('mason').setup()

      local lsp_attach_group = vim.api.nvim_create_augroup('lsp-attach', { clear = true })
      local lsp_detach_group = vim.api.nvim_create_augroup('lsp-detach', { clear = true })
      local lsp_highlight_group = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })

      vim.api.nvim_create_autocmd('LspAttach', {
        group = lsp_attach_group,
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
          map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
          map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = lsp_highlight_group,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = lsp_highlight_group,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = lsp_detach_group,
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
        },
      }

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      local servers = {
        angularls = {
          cmd = angular_cmd,
          filetypes = { 'typescript', 'html', 'typescriptreact', 'typescript.tsx', 'htmlangular' },
          root_dir = function(bufnr, on_dir)
            local root_dir = vim.fs.root(bufnr, { 'angular.json' })
            if root_dir then
              on_dir(root_dir)
            end
          end,
        },
        lua_ls = {
          cmd = { 'lua-language-server' },
          filetypes = { 'lua' },
          root_markers = {
            { '.luarc.json', '.luarc.jsonc' },
            '.luacheckrc',
            '.stylua.toml',
            'stylua.toml',
            'selene.toml',
            'selene.yml',
            '.git',
          },
          settings = {
            Lua = {
              runtime = {
                version = 'LuaJIT',
              },
              workspace = {
                checkThirdParty = false,
                -- VIMRUNTIME/lua holds Neovim API metadata; avoids racing lazydev.
                library = { vim.env.VIMRUNTIME .. '/lua' },
              },
              completion = {
                callSnippet = 'Replace',
              },
              diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
        rust_analyzer = {
          cmd = { 'rust-analyzer' },
          filetypes = { 'rust' },
          root_markers = {
            'Cargo.toml',
            'rust-project.json',
            '.git',
          },
          settings = {
            ['rust-analyzer'] = {
              cargo = {
                allFeatures = true,
              },
            },
          },
        },
        tailwindcss = {
          cmd = { 'tailwindcss-language-server', '--stdio' },
          filetypes = {
            'html',
            'htmlangular',
            'css',
            'scss',
            'sass',
            'javascript',
            'javascriptreact',
            'typescript',
            'typescriptreact',
            'vue',
            'svelte',
            'templ',
          },
          root_markers = {
            'tailwind.config.js',
            'tailwind.config.cjs',
            'tailwind.config.mjs',
            'tailwind.config.ts',
            'postcss.config.js',
            'postcss.config.cjs',
            'postcss.config.mjs',
            'postcss.config.ts',
            'package.json',
            '.git',
          },
          settings = {
            tailwindCSS = {
              validate = true,
              classAttributes = {
                'class',
                'className',
                'class:list',
                'classList',
                'ngClass',
              },
              includeLanguages = {
                templ = 'html',
                htmlangular = 'html',
              },
            },
          },
        },
        ts_ls = {
          cmd = { 'typescript-language-server', '--stdio' },
          filetypes = {
            'javascript',
            'javascriptreact',
            'javascript.jsx',
            'typescript',
            'typescriptreact',
            'typescript.tsx',
          },
          root_markers = {
            'tsconfig.json',
            'jsconfig.json',
            'package.json',
            '.git',
          },
        },
        ty = {
          cmd = { 'ty', 'server' },
          filetypes = { 'python' },
          root_markers = {
            'pyproject.toml',
            'setup.py',
            'setup.cfg',
            'requirements.txt',
            '.git',
          },
        },
      }

      local ensure_installed = {
        'ty',
        'lua-language-server',
        'rust-analyzer',
        'typescript-language-server',
        'angular-language-server',
        'tailwindcss-language-server',
        'jdtls',
        'stylua',
        'ruff',
        'java-test',
        'java-debug-adapter',
        'prettier',
      }
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      vim.lsp.config('*', { capabilities = capabilities })

      for server_name, server in pairs(servers) do
        vim.lsp.config(server_name, server)
        vim.lsp.enable(server_name)
      end
    end,
  },
}
