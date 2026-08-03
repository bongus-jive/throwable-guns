function init()
  self.travelDistance = config.getParameter("travelDistance", 32)
  self.startPos = config.getParameter("startPosition", mcontroller.position())
  self.endPos = config.getParameter("endPosition")
end

function shouldDestroy()
  if projectile.timeToLive() <= 0 then return true end

  if self.travelDistance <= world.magnitude(self.startPos, mcontroller.position()) then
    if self.endPos then mcontroller.setPosition(self.endPos) end
    return true
  end

  return false
end
