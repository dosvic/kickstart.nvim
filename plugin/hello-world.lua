vim.api.nvim_create_user_command('HelloWorld', function()
  vim.print 'Hello world'
end, {})
