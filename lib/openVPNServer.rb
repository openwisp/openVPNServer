#!/usr/bin/env ruby
 
# Authors::     Alessandro Celestini <a.celestini@gmail.com>, Antonio Davoli <antonio.davoli@gmail.com>, Davide Guerri <d.guerri@caspur.it> 
# Copyright::   Copyright (c) 2010 
# License::     Ruby License
# 

# This class was written to simplify the managing of a openVPN
# server through apposite command sent by a telnet client.

require 'net/telnet'

class OpenVPNServer
                  
    @cmd_prompt = /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/

    # Create a new openvpn telnet session. Need host and port of server and optionally password for login.
    def initialize(options)
      pass = nil
      
      # Parsing Options - Set to default values if missing
      if !options.has_key?("Host")
        options["Host"] = "localhost"
      end
      
      if !options.has_key?("Port")
        options["Port"] = 1234
      end
      
      if !options.has_key?("Timeout")
        options["Timeout"] = 10 
      end
      
      if options.has_key?("Password")
        pass = options["Password"]
        options.delete("Password")
      end
 
      # Add Prompt to options
      options["Prompt"] = />INFO:OpenVPN.*\n/
      
      # Create Socket Telnet Connection
      @sock = Net::Telnet::new(options)

      # Password Management
      # ----------------------
      # This is just a little trick. 
      # The openvpn telnet server for management requests just password without username. 
      # The Net::Telnet client wait first for username prompt indeed, so we have to deceive it
      # that there is a user without pass, and this is made inverting the prompt values and 
      # sending just pass prompt and pass value :)
      
	    if !pass.nil?
  	    @sock.login("LoginPrompt" => /ENTER PASSWORD:/, "Name" => pass) 
      end
    end

    # Destroy an openVPNServer telnet session.
    def destroy
      @sock.cmd("String"=>"quit")
      @sock.close
    end
    
    # Get information about clients connected list and routing table. Return two arrays of arrays with lists inside. 
    # For each client in client_list array there is: Common Name, Addredding Infos, Bytes in/out, Uptime.
		# Insteed for each route entry there is: IP/Eth Address (depend on tun/tap mode), Addressing, Uptime.
    def status
		  client_list_flag = 0, routing_list_flag = 0
		  client_list = []
		  routing_list = [] 

      c =  @sock.cmd("String" => "status", "Match" => /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/) 
		  c.each do |l| 
		    
		    # End Information Markers
  			if (l == "ROUTING TABLE\n")
          client_list_flag = 0
        end

        if (l == "GLOBAL STATS\n")
          routing_list_flag = 0
        end

        # Update Clients Connected List
			  if client_list_flag == 1
				  client_list << l.split(',')
				  client_list[-1][-1].chop!
			  end

        # Update Routing Info List
			  if routing_list_flag == 1 
				  routing_list << l.split(',')
				  routing_list[-1][-1].chop!
			  end
	
		    # Start Information Markers
			  if (l == "Common Name,Real Address,Bytes Received,Bytes Sent,Connected Since\n")
	    		client_list_flag = 1
			  end

			  if (l == "Virtual Address,Common Name,Real Address,Last Ref\n")
				  routing_list_flag = 1
			  end
		  end
  
		  return client_list, routing_list
	  end

    # Get information about number of clients connected and traffic statistic (byte in & byte out). 
    #Return an array of three element, the first is the number of client, second the number of byte in input and third the number of byte in output.
    
	  def load_stats
		  stats_info = []
		  c = @sock.cmd("String" => "load-stats", "Match" => /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/)
		  stats_info = c.split(',')
		  # Number of clients
		  stats_info[0] =  stats_info[0].gsub("SUCCESS: nclients=", "").to_i
		  # Bytes Input
		  stats_info[1] = stats_info[1].gsub("bytesin=", "").to_i
		  # Bytes Output
		  stats_info[2] = stats_info[2].chop!.gsub("bytesout=", "").to_i
		  return stats_info
    end

    # Returns a string showing the processes and management interface's version.
    def version
      @sock.cmd("String" => "version", "Match" => /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/)
    end

    # Show process ID of the current OpenVPN process.
    def pid
      @sock.cmd("String" => "pid", "Match" => /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/)
    end
    
    # Send signal s to daemon, where s can be SIGHUP, SIGTERM, SIGUSR1, SIGUSR2.
    def signal(s)
      msg = "signal"
      if s == "SIGHUP" || s == "SIGTERM" || s == "SIGUSR1" || s == "SIGUSR2"
        msg.concat(" #{s}")
        @sock.cmd("String" => msg , "Match" => /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/)
      else
        puts "openVPNServer Signal Error (Supported: SIGHUP, SIGTERM, SIGUSR1, SIGUSR2)"
      end
    end

    # Set log verbosity level to n, or show if n is absent.
    def verb(n=-1)
	    verb = "verb"
	    verb.concat(" #{n}") if n >= 0	 
	    @sock.cmd("String" => verb , "Match" => /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/)
    end

    # Set log mute level to n, or show level if n is absent.
    def mute(n=-1)
	    mute = "mute"
	    mute.concat(" #{n}") if n >= 0	 
	    @sock.cmd("String" => mute , "Match" => /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/)
    end

    # Kill the client instance(s) by common name of host:port combination.
    def kill(options)
    
      msg = "kill"
      cn = nil
      host = nil
      port = nil
      
      # Searching Options
      cn = options["CommonName"] if options.has_key?("CommonName")
      host = options["Host"] if options.has_key?("Host")
      port = options["Port"] if options.has_key?("Port")
      
      if !cn.nil?
        msg.concat(" #{cn}")
        @sock.cmd("String" => msg , "Match" => /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/) do |c|
          print c
        end
      else
        if !host.nil? && !port.nil? 
          msg.concat(" #{host}:#{port}")
          @sock.cmd("String" => msg , "Match" => /(SUCCESS:.*\n|ERROR:.*\n|END.*\n)/)
        else  
          puts "Net::OpenVPN Kill Error (Common Name or Host:Port Combination needed)"
        end
      end
    end
    
end

