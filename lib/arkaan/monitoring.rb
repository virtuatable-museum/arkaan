module Arkaan
  # The monitoring module holds all the logic about the services so they can be activated or deactivated.
  # @author Vincent Courtois <courtois.vincent@outlook.com>
  module Monitoring
    autoload :Service , 'arkaan/monitoring/service'
    autoload :Instance, 'arkaan/monitoring/instance'
    autoload :Gateway , 'arkaan/monitoring/gateway'
    autoload :Route   , 'arkaan/monitoring/route'
  end
end