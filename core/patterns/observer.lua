local Observer = {}
Observer._listeners = {}

function Observer.register(event_type, listener)
  Observer._listeners[event_type] = Observer._listeners[event_type] or {}
  table.insert(Observer._listeners[event_type], listener)
end

function Observer.unregister(event_type, listener)
  local list = Observer._listeners[event_type]
  if not list then return end
  for i, l in ipairs(list) do
    if l == listener then
      table.remove(list, i)
      break
    end
  end
end

function Observer.notify_all(event)
  local list = Observer._listeners[event.type]
  if not list then return end
  for _, listener in ipairs(list) do
    listener(event)
  end
end

return Observer
