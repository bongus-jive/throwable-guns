function init()
  local action = {
    action = "actions",
    list = config.getParameter("hitActions")
  }

  function hit()
    projectile.processAction(action)
  end
end
