require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  sourceId = projectile.sourceEntity()
  cfg = config.getParameter("config")
  
  shots = cfg.shots or 1
  rotationSpeed = cfg.rotationSpeed or 1
  entityBounces = cfg.entityBounces or 0
  entityBounceFactor = (cfg.entityBounceFactor or 1) * -1
  
  burstShots = 0
  burstTimer = 0
end

function update(dt)
  local vel = mcontroller.velocity()
  local dir = vel[1] > 0 and 1 or -1
  local rotation = (vec2.mag(vel) / 180 * math.pi) * -dir * dt * rotationSpeed
  mcontroller.setRotation(mcontroller.rotation() + rotation)
  
  if burstTimer > 0 then
    burstTimer = math.max(0, burstTimer - dt)
    if burstShots > 0 and burstTimer == 0 then
      burstShots = burstShots - 1
      burstTimer = cfg.burstTime
      fire(true)
    end
  end
  
  if cfg.muzzleflashActions then
    for _,action in ipairs(cfg.muzzleflashActions) do
      action.time = action.time or 0
      action["repeat"] = action["repeat"] or false
    end
  end
end

function bounce()
  fire()
end

function fire(burst)
  if not burst then
    if shots == 0 then return end
    if shots > 0 then shots = shots - 1 end
    
    if cfg.burstCount and cfg.burstCount > 1 then
      burstShots = cfg.burstCount - 1
      burstTimer = cfg.burstTime
    end
  end
  
  --targets
  local mpos = mcontroller.position()
  local ents = world.entityQuery(mpos, 100, {withoutEntityId = sourceId, order = "nearest", includedTypes = {"creature"}})
  local target, tpos
  for _,id in ipairs(ents) do
    local epos = world.entityPosition(id)
    if world.entityCanDamage(sourceId, id) and not world.lineTileCollision(mpos, epos) then
      target = id
      tpos = epos
      break
    end
  end
  if target then
    local angle = vec2.angle(world.distance(tpos, mpos))
    mcontroller.setRotation(angle)
    mpos = mcontroller.position()
  end
  
  --projectile
  local mrot = mcontroller.rotation()
  local firePos = vec2.add(mpos, vec2.rotate(cfg.muzzleOffset, mrot))
  
  local collision = world.lineCollision(mpos, firePos)
  
  local params = {
    power = projectile.power() / cfg.projectileCount / (cfg.burstCount or 1) * (cfg.inheritDamageFactor or 1),
    powerMultiplier = projectile.powerMultiplier(),
    damageTeam = world.entityDamageTeam(sourceId)
  }
  if cfg.projectileParameters then
    params = sb.jsonMerge(params, cfg.projectileParameters)
  end
  
  for i = 1, cfg.projectileCount do
    if cfg.projectileParameters then
      params.speed = util.randomInRange(cfg.projectileParameters.speed)
    end
    local aimVec = vec2.rotate({1,0}, mrot + sb.nrand(cfg.inaccuracy, 0))
    world.spawnProjectile(cfg.projectileType, collision or firePos, entity.id(), aimVec, false, params)
  end
  
  --muzzleflash
  local mparams = {periodicActions = cfg.muzzleflashActions}
  if cfg.muzzleflashVariants and cfg.muzzleflashVariants > 0 then
    mparams.processing = "."..math.random(1, cfg.muzzleflashVariants)
  end
  world.spawnProjectile(cfg.muzzleflash, firePos, sourceId, vec2.rotate({1,0}, mrot), false, mparams)
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
