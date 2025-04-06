vim.api.nvim_create_user_command('HiWorld', function()
  vim.print 'Hi world'
end, {})
