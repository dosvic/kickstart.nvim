return {
  {
    'yetone/avante.nvim',
    event = 'VeryLazy',
    version = false,
    config = function()
      require('avante').setup {
        provider = 'copilot',
        copilot = {
          model = 'claude-3.7-sonnet',
          --model = 'claude-3.5-sonnet',
          -- temperature = 1,
          -- max_tokens = 20000,
        },
        vendors = {
          ['openrouter-deepseek-r1'] = {
            __inherited_from = 'openai',
            model = 'deepseek/deepseek-r1',
            endpoint = 'https://openrouter.ai/api/v1',
            api_key_name = 'OPENROUTER_API_KEY',
          },
          ['openrouter-deepseek-v3'] = {
            __inherited_from = 'openai',
            model = 'deepseek/deepseek-chat',
            endpoint = 'https://openrouter.ai/api/v1',
            api_key_name = 'OPENROUTER_API_KEY',
          },
          ['openrouter-claude-3.7-sonnet'] = {
            __inherited_from = 'openai',
            model = 'anthropic/claude-3.7-sonnet',
            endpoint = 'https://openrouter.ai/api/v1',
            api_key_name = 'OPENROUTER_API_KEY',
          },
          ['openrouter-gemini/gemini-2.5-pro'] = {
            __inherited_from = 'openai',
            model = 'google/gemini-2.5-pro-exp-03-25:free',
            endpoint = 'https://openrouter.ai/api/v1',
            api_key_name = 'OPENROUTER_API_KEY',
          },
        },
        behaviour = {
          auto_suggestions = false,
        },
      }
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
