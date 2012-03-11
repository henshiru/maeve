module Mv
  class PropertyHolder
    include Enumerable
    def initialize
      @values = {}
      @changed = []
      @listeners = {:all=>[]}
    end
    def [] key
      @values[key]
    end
    def []= key,value
      @values[key] = value
      set_changed key
    end
    def set_changed key
      @changed.push key
    end
    def add_listener *keys, &proc
      keys.each{|key|
        @listeners[key] ||= []
        @listeners[key].push proc
      }
      proc
    end
    def remove_listener proc
      @listeners.each{|k, procs|
        procs.delete proc
      }
    end
    def notify_listeners
      @changed.uniq!
      targets = []
      targets.concat(@listeners[:all]) unless @changed.empty?
      @changed.each{|key|
        targets.concat(@listeners[key] || [])
      }
      targets.uniq!
      targets.each{|listener|
        listener.call @changed
      }
      @changed.clear
    end
    def each
      @values.each{|key,value|
        yield key,value
      }
    end
  end
end
