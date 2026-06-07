require "/scripts/vec2.lua"

function destroy()
  if not mcontroller.isColliding() then return end

  local pos = mcontroller.position()
  local vel = mcontroller.velocity()

  local a = vec2.sub(pos, vec2.mul(vel, script.updateDt()))
  local b = vec2.add(pos, vel)
  local coll = world.lineTileCollisionPoint(a, b)
  if not coll then return end

  local norm = coll[2]
  if norm[1] == 0 and norm[2] == 0 then return end

  local cfg = config.getParameter("spikeProjectile")
  local params = cfg.parameters or {}
  if math.random() > 0.5 then
    params.processing = (params.processing or "") .. "?flipy"
  end
  
  local dir = vec2.rotate(norm, sb.nrand(cfg.inaccuracy or 0, math.pi))
  world.spawnProjectile(cfg.type, pos, projectile.sourceEntity(), dir, nil, params)
end
