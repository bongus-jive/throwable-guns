require "/scripts/util.lua"
require "/scripts/vec2.lua"

local sourceId

function init()
  sourceId = projectile.sourceEntity()

  Cfg = config.getParameter("config")
  RotationRate = Cfg.rotationSpeed or 1
  Shots = Cfg.shots or 1

  HitBounces = Cfg.entityBounces or 0
  HitBounceFactor = (Cfg.entityBounceFactor or 1) * -1

  Cfg.targetQueryRange = Cfg.targetQueryRange or 100
  Cfg.targetQueryOptions = sb.jsonMerge({order = "nearest", includedTypes = {"creature"}}, Cfg.targetQueryOptions)
  Cfg.targetQueryOptions.withoutEntityId = sourceId
  
  for _, action in ipairs(Cfg.muzzleflashActions or {}) do
    action["time"] = action["time"] or 0
    action["repeat"] = action["repeat"] or false
  end
  MuzzleflashParams = {periodicActions = Cfg.muzzleflashActions}
end

function update(dt)
  FireState:update()

  local vel = mcontroller.velocity()
  local dir = vel[1] > 0 and 1 or -1
  local rotation = (vec2.mag(vel) / 180 * math.pi) * -dir * dt * RotationRate
  mcontroller.setRotation(mcontroller.rotation() + rotation)
end

function fire()
  FireState:set(fireRoutine)
end

function fireRoutine()
  for _ = 1, Cfg.burstCount or 1 do
    if Shots < 1 then return end
    Shots = Shots - 1
    
    snapToTarget()
    fireProjectile()
    util.wait(Cfg.burstTime or 0)
  end
end

function fireProjectile()
  local pos = mcontroller.position()
  local angle = mcontroller.rotation()
  local aimVector = {math.cos(angle), math.sin(angle)}
  local muzzlePos = vec2.add(pos, vec2.rotate(Cfg.muzzleOffset, angle))
  local firePos = world.lineCollision(pos, muzzlePos) or muzzlePos

  local params = sb.jsonMerge({
    power = projectile.power(),
    powerMultiplier = projectile.powerMultiplier() / Cfg.projectileCount / (Cfg.burstCount or 1) * (Cfg.inheritDamageFactor or 1),
    damageTeam = entity.damageTeam()
  }, Cfg.projectileParameters)
  
  for _ = 1, Cfg.projectileCount do
    params.speed = util.randomInRange(Cfg.projectileParameters.speed)
    local vec = vec2.rotate(aimVector, sb.nrand(Cfg.inaccuracy or 0, 0))
    world.spawnProjectile(Cfg.projectileType, firePos, sourceId, vec, nil, params)
  end
  
  world.spawnProjectile(Cfg.muzzleflash, muzzlePos, sourceId, aimVector, nil, MuzzleflashParams)

  if Cfg.recoilPower then
    local recoil = vec2.mul(aimVector, -Cfg.recoilPower)
    mcontroller.addMomentum(recoil)
  end
end

function snapToTarget()
  local pos = mcontroller.position()
  local targets = world.entityQuery(pos, Cfg.targetQueryRange, Cfg.targetQueryOptions)

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
  if HitBounces == 0 then return end
  if HitBounces ~= -1 then HitBounces = HitBounces - 1 end

  if Cfg.entityBounceAddShots then Shots = Shots + Cfg.entityBounceAddShots end
  
  local vel = mcontroller.velocity()
  local pos = vec2.sub(mcontroller.position(), vec2.norm(vel))
  local diff = world.distance(pos, world.entityPosition(id))

  local norm = vec2.norm({diff[2], -diff[1]})
  local dot = vec2.dot(vel, norm) * 2
  
  mcontroller.setVelocity({
    (vel[1] - dot * norm[1]) * HitBounceFactor,
    (vel[2] - dot * norm[2]) * HitBounceFactor
  })

  if Cfg.entityBounceShoot then fire() end
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
