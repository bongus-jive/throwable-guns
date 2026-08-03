require "/scripts/vec2.lua"

function init()
  self.queryOptions = config.getParameter("queryOptions", {})
  self.queryRange = config.getParameter("queryRange", 50)
  self.maxTargets = config.getParameter("maxTargets") or math.huge

  self.tracerProjectile = config.getParameter("tracerProjectile")
  self.tracerRadius = config.getParameter("tracerRadius", 0)
end

function hit(id)
  self.queryOptions.withoutEntityId = id
  projectile.die()
end

function destroy()
  local mPos = mcontroller.position()
  local targets = world.entityQuery(mPos, self.queryRange, self.queryOptions)
  local positions = { }

  for _, target in ipairs(targets) do
    if isValidTarget(target) then
      local i = #positions + 1
      positions[i] = world.entityPosition(target)
      if i >= self.maxTargets then break end
    end
  end

  local params = {
    power = projectile.power(),
    powerMultiplier = projectile.powerMultiplier()
  }
  
  for _, targetPos in ipairs(positions) do
    local dir = vec2.norm(world.distance(targetPos, mPos))
    local pos = vec2.add(mPos, vec2.mul(dir, self.tracerRadius))

    params.startPosition = pos
    params.endPosition = targetPos
    params.travelDistance = world.magnitude(pos, targetPos)

    world.spawnProjectile(self.tracerProjectile, pos, projectile.sourceEntity(), dir, false, params)
  end
end

function isValidTarget(id)
  return world.entityExists(id) and entity.entityInSight(id) and world.entityCanDamage(entity.id(), id)
end
