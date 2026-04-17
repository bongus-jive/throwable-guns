require "/scripts/util.lua"
require "/scripts/vec2.lua"

local sourceId

function init()
  sourceId = projectile.sourceEntity()

  Cfg = config.getParameter("config")

  CooldownTimer = 0
  Shots = Cfg.shots or 1
  RotationRate = sb.nrand(Cfg.rotationDeviation or 0, Cfg.rotationSpeed or 1)
  Falldown = config.getParameter("falldown", false)
  TileBounces = Cfg.tileBounces or -1
  HitBounces = Cfg.entityBounces or 0

  Cfg.entityBounceFactor = -(Cfg.entityBounceFactor or 1)
  Cfg.targetQueryRange = Cfg.targetQueryRange or 100
  Cfg.targetQueryOptions = sb.jsonMerge({order = "nearest", includedTypes = {"creature"}}, Cfg.targetQueryOptions)
  Cfg.targetQueryOptions.withoutEntityId = sourceId
  
  for _, action in ipairs(Cfg.muzzleflashActions or {}) do
    action["time"] = action["time"] or 0
    action["repeat"] = action["repeat"] or false
  end
  MuzzleflashParameters = sb.jsonMerge(Cfg.muzzleflashParameters, {periodicActions = Cfg.muzzleflashActions})

  ProjectileParameters = sb.jsonMerge({
    power = projectile.power(),
    powerMultiplier = projectile.powerMultiplier() / Cfg.projectileCount / (Cfg.burstCount or 1) * (Cfg.inheritDamageFactor or 1),
    damageTeam = entity.damageTeam()
  }, Cfg.projectileParameters)
end

function update(dt)
  if CooldownTimer > 0 then CooldownTimer = CooldownTimer - dt end

  FireState:update()

  local vel = mcontroller.velocity()
  local dir = vel[1] > 0 and 1 or -1
  local rotation = (vec2.mag(vel) / 180 * math.pi) * -dir * dt * RotationRate
  mcontroller.setRotation(mcontroller.rotation() + rotation)
end

function fire()
  if CooldownTimer > 0 or Shots <= 0 or FireState.state then return end
  CooldownTimer = Cfg.cooldownTime or 0
  FireState:set(fireRoutine)
end

function fireRoutine()
  for _ = 1, Cfg.burstCount or 1 do
    if Shots <= 0 then return end
    Shots = Shots - 1
    
    snapToTarget()
    fireProjectile()
    util.wait(Cfg.burstTime or 0)
  end
end

function fireProjectile()
  local angle = mcontroller.rotation()
  local aimVector = {math.cos(angle), math.sin(angle)}
  local firePos, muzzlePos = firePosition(angle)

  for _ = 1, Cfg.projectileCount do
    local inacc = sb.nrand(Cfg.inaccuracy or 0, 0)
    local vec = vec2.rotate(aimVector, inacc)
    
    if Cfg.rotateWithInaccuracy and inacc > 0 then
      angle = angle + inacc
      firePos, muzzlePos = firePosition(angle)
      aimVector = vec
    end
    
    ProjectileParameters.speed = util.randomInRange(Cfg.projectileParameters.speed)
    world.spawnProjectile(Cfg.projectileType, firePos, sourceId, vec, nil, ProjectileParameters)
  end
  
  world.spawnProjectile(Cfg.muzzleflash, muzzlePos, sourceId, aimVector, nil, MuzzleflashParameters)
  
  if Cfg.rotateWithInaccuracy then mcontroller.setRotation(angle) end
  if Cfg.recoilPower then
    local recoil = vec2.mul(aimVector, -Cfg.recoilPower)
    mcontroller.addMomentum(recoil)
  end
end

function firePosition(angle)
  if not angle then angle = mcontroller.rotation() end
  local pos = mcontroller.position()
  local muzzlePos = vec2.add(pos, vec2.rotate(Cfg.muzzleOffset, angle))
  local firePos = world.lineCollision(pos, muzzlePos) or muzzlePos

  return firePos, muzzlePos
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
  local vel = mcontroller.velocity()
  local pos = vec2.sub(mcontroller.position(), vec2.norm(vel))
  local diff = world.distance(pos, world.entityPosition(id))

  local norm = vec2.norm({diff[2], -diff[1]})
  local dot = vec2.dot(vel, norm) * 2
  
  mcontroller.setVelocity({
    (vel[1] - dot * norm[1]) * Cfg.entityBounceFactor,
    (vel[2] - dot * norm[2]) * Cfg.entityBounceFactor
  })

  if HitBounces ~= 0 then
    if Cfg.entityBounceAddShots then Shots = Shots + Cfg.entityBounceAddShots end
    if Cfg.entityBounceShoot then fire() end
  end
  if HitBounces > 0 then HitBounces = HitBounces - 1 end
end

function bounce()
  if TileBounces > 0 then TileBounces = TileBounces - 1 end
  fire()
end

function shouldDestroy()
  if Shots > 0 or FireState.state then return false end

  if TileBounces == 0 then
    local mc = mcontroller
    if not Falldown or (mc.zeroG() or mc.onGround() or mc.isCollisionStuck() or mc.stickingDirection()) then
      return true
    end
  end
  
  return projectile.timeToLive() <= 0
end


FireState = FSM:new()
function FireState:update()
  if not self.state then return end
  if coroutine.status(self.state) == "dead" then return self:set() end
  self:resume()
end
