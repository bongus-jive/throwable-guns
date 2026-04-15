require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  sourceId = projectile.sourceEntity()
  cfg = config.getParameter("config")
  
  shots = cfg.shots or 1
  rotationSpeed = cfg.rotationSpeed or 1
  entityBounces = cfg.entityBounces or 0
  entityBounceFactor = (cfg.entityBounceFactor or 1) * -1

  cfg.targetQueryRange = cfg.targetQueryRange or 100
  targetQueryOptions = { withoutEntityId = sourceId, order = "nearest", includedTypes = { "creature" } }
  
  for _, action in ipairs(cfg.muzzleflashActions or {}) do
    action["time"] = action["time"] or 0
    action["repeat"] = action["repeat"] or false
  end
end

function update(dt)
  FireState:update()

  local vel = mcontroller.velocity()
  local dir = vel[1] > 0 and 1 or -1
  local rotation = (vec2.mag(vel) / 180 * math.pi) * -dir * dt * rotationSpeed
  mcontroller.setRotation(mcontroller.rotation() + rotation)
end

function fire()
  FireState:set(fireRoutine)
end

function fireRoutine()
  if shots == 0 then return end
  shots = shots - 1

  for _ = 1, cfg.burstCount or 1 do
    snapToTarget()
    fireProjectile()
    util.wait(cfg.burstTime or 0)
  end
end

function fireProjectile()
  local pos = mcontroller.position()
  local angle = mcontroller.rotation()
  local aimVector = {math.cos(angle), math.sin(angle)}
  local muzzlePos = vec2.add(pos, vec2.rotate(cfg.muzzleOffset, angle))
  local firePos = world.lineCollision(pos, muzzlePos) or muzzlePos

  local params = sb.jsonMerge({
    power = projectile.power(),
    powerMultiplier = projectile.powerMultiplier() / cfg.projectileCount / (cfg.burstCount or 1) * (cfg.inheritDamageFactor or 1),
    damageTeam = entity.damageTeam()
  }, cfg.projectileParameters)
  
  for _ = 1, cfg.projectileCount do
    params.speed = util.randomInRange(cfg.projectileParameters.speed)
    local vec = vec2.rotate(aimVector, sb.nrand(cfg.inaccuracy or 0, 0))
    world.spawnProjectile(cfg.projectileType, firePos, sourceId, vec, nil, params)
  end
  
  
  local flashParams = { periodicActions = cfg.muzzleflashActions }
  if cfg.muzzleFlashVariants then
    flashParams.processing = "."..math.random(cfg.muzzleFlashVariants)
  end
  world.spawnProjectile(cfg.muzzleflash, muzzlePos, sourceId, aimVector, nil, flashParams)
end

function snapToTarget()
  local pos = mcontroller.position()
  local targets = world.entityQuery(pos, cfg.targetQueryRange, targetQueryOptions)

  for _, id in ipairs(targets) do
    local targetPos = world.entityPosition(id)
    if world.entityCanDamage(sourceId, id) and not world.lineTileCollision(pos, targetPos) then
      local angle = vec2.angle(world.distance(targetPos, pos))
      mcontroller.setRotation(angle)
      return
    end
  end
end

function hit(id)
  if entityBounces == 0 then return end
  if entityBounces ~= -1 then entityBounces = entityBounces - 1 end
  
  local vel = mcontroller.velocity()
  local pos = vec2.sub(mcontroller.position(), vec2.norm(vel))
  local diff = world.distance(pos, world.entityPosition(id))

  local norm = vec2.norm({diff[2], -diff[1]})
  local dot = vec2.dot(vel, norm) * 2
  
  mcontroller.setVelocity({
    (vel[1] - dot * norm[1]) * entityBounceFactor,
    (vel[2] - dot * norm[2]) * entityBounceFactor
  })

  if cfg.entityBounceShoot then fire() end
end

function bounce()
  fire()
end


FireState = FSM:new()
function FireState:update()
  if not self.state then return end
  if coroutine.status(self.state) == "dead" then return self:set() end
  self:resume()
end
