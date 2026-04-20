require "/scripts/util.lua"
require "/scripts/vec2.lua"

local self
function init()
  self = _ENV.self
  
  local cfg = config.getParameter("throwngunConfig")

  self.sourceId = projectile.sourceEntity()

  self.ammo = cfg.ammo or 1
  self.cooldownTimer = 0
  self.cooldownTime = cfg.cooldownTime or 0
  self.burstTime = cfg.burstTime or 0
  self.burstCount = cfg.burstCount or 1
  self.inaccuracy = cfg.inaccuracy or 0
  self.rotateWithInaccuracy = cfg.rotateWithInaccuracy
  self.recoil = cfg.recoil
  self.recoilRotation = math.rad(cfg.recoilRotation or 0)

  self.emptyBounces = cfg.emptyBounces or -1
  self.emptyTimer = 0
  self.emptyTimeToLive = cfg.emptyTimeToLive or 0
  self.hitBounceFactor = (cfg.hitBounceFactor or 1) * -1
  self.rotationRate = sb.nrand(cfg.rotationDeviation or 0, cfg.rotationRate or 1)
  self.fireOnHit = cfg.fireOnHit or false
  self.ammoOnHit = cfg.ammoOnHit
  self.ammoOnHitLimit = cfg.ammoOnHitLimit or -1

  self.targetLockRange = cfg.targetLockRange
  self.targetQueryRange = cfg.targetQueryRange or 100
  self.targetQueryOptions = sb.jsonMerge({
    order = "nearest",
    includedTypes = {"creature"},
    withoutEntityId = self.sourceId
  }, cfg.targetQueryOptions)

  self.muzzleOffset = cfg.muzzleOffset or {0, 0}
  self.projectileType = cfg.projectileType
  self.projectileCount = cfg.projectileCount or 1
  self.projectileDamageFactor = cfg.projectileDamageFactor or 1
  self.projectileSpeedRange = cfg.projectileSpeedRange
  self.projectileParameters = sb.jsonMerge({
    powerMultiplier = projectile.powerMultiplier() / self.projectileCount / self.burstCount
  }, cfg.projectileParameters)
  
  for _, action in ipairs(cfg.muzzleflashActions or {}) do
    action["time"] = action["time"] or 0
    action["repeat"] = action["repeat"] or false
  end
  self.muzzleflashType = cfg.muzzleflash
  self.muzzleflashParameters = sb.jsonMerge(cfg.muzzleflashParameters, {periodicActions = cfg.muzzleflashActions})
  self.burstSingleMuzzleflash = cfg.burstSingleMuzzleflash
end

function update(dt)
  if self.cooldownTimer > 0 then self.cooldownTimer = self.cooldownTimer - dt end

  if self.ammo <= 0 then
    self.emptyTimer = self.emptyTimer + dt
  elseif self.emptyTimer ~= 0 then
    self.emptyTimer = 0
  end

  FireState:update()

  local vel = mcontroller.velocity()
  local dir = vel[1] > 0 and -1 or 1
  local rot = math.rad(vec2.mag(vel)) * self.rotationRate * dir * dt
  mcontroller.setRotation(mcontroller.rotation() + rot)
end

function fire()
  if self.cooldownTimer > 0 or self.ammo <= 0 or FireState.state then return end
  self.cooldownTimer = self.cooldownTime
  FireState:set(fireRoutine)
end

function fireRoutine()
  for i = 1, self.burstCount do
    if self.ammo <= 0 then return end
    self.ammo = self.ammo - 1
    
    snapToTarget()
    fireProjectile(self.burstSingleMuzzleflash and i ~= 1)
    util.wait(self.burstTime)
  end
end

function fireProjectile(skipFlash)
  local aimAngle = mcontroller.rotation()
  local aimVector = {math.cos(aimAngle), math.sin(aimAngle)}
  local firePos, muzzlePos = firePosition(aimAngle)

  self.projectileParameters.power = projectile.power() * self.projectileDamageFactor

  for _ = 1, self.projectileCount do
    local inacc = sb.nrand(self.inaccuracy, aimAngle)
    local vec = {math.cos(inacc), math.sin(inacc)}
    
    if self.rotateWithInaccuracy then
      aimAngle, aimVector = inacc, vec
      firePos, muzzlePos = firePosition(aimAngle)
    end
    
    if self.projectileSpeedRange then
      self.projectileParameters.speed = util.randomInRange(self.projectileSpeedRange)
    end

    world.spawnProjectile(self.projectileType, firePos, self.sourceId, vec, nil, self.projectileParameters)
  end
  
  if self.muzzleflashType and not skipFlash then
    world.spawnProjectile(self.muzzleflashType, muzzlePos, self.sourceId, aimVector, nil, self.muzzleflashParameters)
  end
  
  if self.rotateWithInaccuracy then mcontroller.setRotation(aimAngle) end
  if self.recoil then
    local recoil = vec2.mul(aimVector, -self.recoil)
    if self.recoilRotation > 0 then
      recoil = vec2.rotate(recoil, self.recoilRotation)
    end
    mcontroller.addMomentum(recoil)
  end
end

function firePosition(angle)
  if not angle then angle = mcontroller.rotation() end
  local pos = mcontroller.position()
  local muzzlePos = vec2.add(pos, vec2.rotate(self.muzzleOffset, angle))
  local firePos = world.lineCollision(pos, muzzlePos) or muzzlePos

  return firePos, muzzlePos
end

function snapToTarget()
  local targetId = findTarget()
  if not targetId then return end

  local angle = vec2.angle(entity.distanceToEntity(targetId))
  mcontroller.setRotation(angle)
end

function findTarget()
  local pos = mcontroller.position()
  
  if self.targetLockRange and self.lockedTargetId then
    local tPos = world.entityPosition(self.lockedTargetId)
    if tPos and world.magnitude(pos, tPos) < self.targetLockRange then
      return self.lockedTargetId
    end
    self.lockedTargetId = nil
  end
  
  if self.targetQueryRange <= 0 then return end
  local targets = world.entityQuery(pos, self.targetQueryRange, self.targetQueryOptions)
  for _, id in ipairs(targets) do
    if entity.entityInSight(id) and world.entityCanDamage(self.sourceId, id) then
      if self.targetLockRange then self.lockedTargetId = id end
      return id
    end
  end
end

function hit(id)
  local vel = mcontroller.velocity()
  local pos = vec2.sub(mcontroller.position(), vec2.norm(vel))
  local diff = world.distance(world.entityPosition(id), pos)

  local norm = vec2.norm({diff[2], -diff[1]})
  local dot = vec2.dot(vel, norm) * 2
  
  mcontroller.setVelocity({
    (vel[1] - dot * norm[1]) * self.hitBounceFactor,
    (vel[2] - dot * norm[2]) * self.hitBounceFactor
  })
  
  if self.ammoOnHit and self.ammoOnHitLimit ~= 0 then
    if self.ammoOnHitLimit > 0 then self.ammoOnHitLimit = self.ammoOnHitLimit - 1 end
    self.ammo = self.ammo + self.ammoOnHit
  end
  if self.fireOnHit then fire() end
end

function bounce()
  if self.emptyBounces > 0 and self.ammo <= 0 then
    self.emptyBounces = self.emptyBounces - 1
  end
  fire()
end

function shouldDestroy()
  if FireState.state then return false end
  if projectile.timeToLive() <= 0 then return true end

  if self.ammo <= 0 and self.emptyTimer >= self.emptyTimeToLive and self.emptyBounces <= 0 then
    local mc = mcontroller
    if mc.zeroG() or mc.onGround() or mc.isCollisionStuck() or mc.stickingDirection() then
      return true
    end
  end

  return false
end


FireState = FSM:new()
function FireState:update()
  if not self.state then return end
  if coroutine.status(self.state) == "dead" then return self:set() end
  self:resume()
end
