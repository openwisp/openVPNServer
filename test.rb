
# OpenVPNServer Test Example

require 'Rubygems'
require 'openVPNServer'

# openVPNServer creation (Modify your fields)
s = OpenVPNServer.new("Host" => "localhost", "Port" => 1234, "Timeout" => 10,  "Password" => "hi")
# status command
c,r = s.status
p c
p r
# load_stats command
s_info = s.load_stats
p s_info
s.destroy

