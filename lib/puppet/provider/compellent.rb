# encoding: utf-8
# Class for making connection with device

require 'puppet/provider'
require 'puppet/compellent/transport'

class Puppet::Provider::Compellent < Puppet::Provider

  def connection
    @device ||= Puppet::Compellent::Transport.new
  end

  # Helper function for simplifying the execution of Compellent API commands, in a similar fashion to the commands function.
  # Arguments should be a hash of 'command name' => 'api command'.
  def self.compellent_commands(command_specs)
    command_specs.each do |name, apicommand|
      # The `create_class_and_instance_method` method was added in puppet 3.0.0
      if respond_to? :create_class_and_instance_method
        create_class_and_instance_method(name) do |*args|
          debug "Executing api call #{[apicommand, args].flatten.join(' ')}"
          result = transport.invoke(apicommand, *args)
          if result.results_status == 'failed'
            raise Puppet::Error, "Executing api call #{[apicommand, args].flatten.join(' ')} failed: #{result.results_reason.inspect}"
          end
          result
        end
      else
        # workaround for puppet 2.7.x
        unless singleton_class.method_defined?(name)
          meta_def(name) do |*args|
            debug "Executing api call #{[apicommand, args].flatten.join(' ')}"
            result = transport.invoke(apicommand, *args)
            if result.results_status == 'failed'
              raise Puppet::Error, "Executing api call #{[apicommand, args].flatten.join(' ')} failed: #{result.results_reason.inspect}"
            end
            result
          end
        end
        unless method_defined?(name)
          define_method(name) do |*args|
            self.class.send(name, *args)
          end
        end
      end
    end
  end

end

