return {
  {
    dir = vim.fn.stdpath 'config' .. '/lua/kickstart/plugins/hello-world.nvim',
    config = function()
      require('hello-world').setup()
    end,
  },
}
