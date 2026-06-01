function init()
  if projectile.timeToLive() <= 0 then return end

  local name = config.getParameter("gunProjectile")
  if not name then return end

  local params = config.getParameter("gunParameters", {})

  local angle = mcontroller.rotation()
  local dir = { math.cos(angle), math.sin(angle) }

  if dir[1] > 0 then
    params.processing = (params.processing or "") .. "?flipy"
    params.gunFlipped = true
  end
  params.powerMultiplier = projectile.powerMultiplier()

  world.spawnProjectile(name, mcontroller.position(), projectile.sourceEntity(), dir, nil, params)

  projectile.die()
end
