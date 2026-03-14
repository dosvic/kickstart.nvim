local function get_probe_dir(root_dir)
  local node_modules = root_dir and vim.fs.find('node_modules', { path = root_dir, upward = true })[1] or nil
  if node_modules then
    return node_modules
  end

  return vim.fn.stdpath 'data' .. '/mason/packages/angular-language-server/node_modules'
end

local function get_angular_core_version(root_dir)
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
  return type(version) == 'string' and version:match('%d+%.%d+%.%d+') or nil
end

return {
  cmd = function(dispatchers, config)
    local probe_dir = get_probe_dir(config.root_dir)
    local cmd = {
      'ngserver',
      '--stdio',
      '--tsProbeLocations',
      probe_dir,
      '--ngProbeLocations',
      probe_dir,
    }

    local angular_core_version = get_angular_core_version(config.root_dir)
    if angular_core_version then
      table.insert(cmd, '--angularCoreVersion')
      table.insert(cmd, angular_core_version)
    end

    return vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = { 'typescript', 'html', 'typescriptreact', 'typescript.tsx', 'htmlangular' },
  root_dir = function(bufnr, on_dir)
    local root_dir = vim.fs.root(bufnr, { 'angular.json' })
    if root_dir then
      on_dir(root_dir)
    end
  end,
}
