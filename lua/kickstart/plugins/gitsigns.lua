return {
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = 'eol',
        delay = 250,
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        map('n', ']h', gs.next_hunk, 'Git: Next hunk')
        map('n', '[h', gs.prev_hunk, 'Git: Prev hunk')
        map('n', '<leader>hs', gs.stage_hunk, 'Git: Stage hunk')
        map('n', '<leader>hr', gs.reset_hunk, 'Git: Reset hunk')
        map('v', '<leader>hs', function()
          gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, 'Git: Stage selected hunk')
        map('v', '<leader>hr', function()
          gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, 'Git: Reset selected hunk')
        map('n', '<leader>hS', gs.stage_buffer, 'Git: Stage buffer')
        map('n', '<leader>hu', gs.undo_stage_hunk, 'Git: Undo stage hunk')
        map('n', '<leader>hR', gs.reset_buffer, 'Git: Reset buffer')
        map('n', '<leader>hp', gs.preview_hunk, 'Git: Preview hunk')
        map('n', '<leader>hb', function()
          gs.blame_line { full = true }
        end, 'Git: Blame line')
        map('n', '<leader>tb', gs.toggle_current_line_blame, 'Git: Toggle line blame')
        map('n', '<leader>hd', gs.diffthis, 'Git: Diff this')
        map('n', '<leader>hD', function()
          gs.diffthis '~'
        end, 'Git: Diff this (~)')
        map('n', '<leader>hq', gs.setqflist, 'Git: Hunks to quickfix')
        map('n', '<leader>hQ', function()
          gs.setqflist 'all'
        end, 'Git: All hunks to quickfix')
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', 'Git: Select hunk')
      end,
    },
  },
}
