return {
  {
    'yetone/avante.nvim',
    event = 'VeryLazy',
    version = false,
    config = function()
      local function openrouter_model(opts)
        local defaults = {
          __inherited_from = 'openai',
          endpoint = 'https://openrouter.ai/api/v1',
          api_key_name = 'OPENROUTER_API_KEY',
        }

        return vim.tbl_deep_extend('force', defaults, opts or {})
      end

      require('avante').setup {
        provider = 'copilot',
        copilot = {
          model = 'gemini-2.5-pro',
          -- temperature = 1,
          -- max_tokens = 20000,
        },
        vendors = {
          ['openrouter/deepseek-r1'] = openrouter_model {
            model = 'deepseek/deepseek-r1',
            display_name = 'openrouter/deepseek-r1',
          },
          ['openrouter/deepseek-v3'] = openrouter_model {
            model = 'deepseek/deepseek-chat',
            display_name = 'openrouter/deepseek-v3',
          },
          ['openrouter/grok-3-mini-beta'] = openrouter_model {
            model = 'x-ai/grok-3-mini-beta',
            display_name = 'openrouter/grok-3-mini-beta',
          },
        },
        behaviour = {
          auto_suggestions = false,
        },
      }

      vim.keymap.set('n', '<leader>ad', '<cmd>AvanteClear<cr>', { desc = '[a]vante [d]elete chat history' })
    end,
    build = 'make',
    dependencies = {
      'stevearc/dressing.nvim',
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'hrsh7th/nvim-cmp',
      'nvim-tree/nvim-web-devicons',
      'zbirenbaum/copilot.lua',
      {
        'HakonHarnes/img-clip.nvim',
        event = 'VeryLazy',
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            use_absolute_path = true,
          },
        },
      },
      {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { 'markdown', 'Avante' },
        },
        ft = { 'markdown', 'Avante' },
      },
    },
  },
}
