require "/scripts/vec2.lua"

function update()
  local stuck = mcontroller.stickingDirection() ~= nil

  if stuck and not self.stuck then
    self.stuck = true
    local ttl = config.getParameter("stickyTimeToLive")
    if ttl then projectile.setTimeToLive(ttl) end
  end
end

function destroy()
  if not self.stuck then return end

  local pos = mcontroller.position()
  local rot = mcontroller.rotation()

  local a = vec2.add(pos, vec2.withAngle(rot, -1))
  local b = vec2.add(pos, vec2.withAngle(rot, 2))
  local coll = world.lineTileCollisionPoint(a, b)
  if not coll then return end

  local norm = coll[2]
  if norm[1] == 0 and norm[2] == 0 then return end

  local cfg = config.getParameter("spikeProjectile")
  local params = cfg.parameters or {}
  params.power = (params.power or projectile.power()) * (cfg.damageFactor or 1)
  params.powerMultipler = projectile.powerMultiplier()
  if math.random() > 0.5 then
    params.processing = (params.processing or "") .. "?flipy"
  end
  
  local dir = vec2.rotate(norm, sb.nrand(cfg.inaccuracy or 0, math.pi))
  world.spawnProjectile(cfg.type, coll[1], projectile.sourceEntity(), dir, nil, params)
end
