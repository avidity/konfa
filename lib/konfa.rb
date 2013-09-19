# -*- coding: utf-8 -*-
require 'yaml'

module Konfa
  class Base

    @@env_variable_prefix = 'APP_'
    @@variables = {}

    class << self

      def get(variable)
        raise UnsupportedVariableError.new(variable) unless @@variables.has_key? variable
        @@variables[variable]
      end

      def set(variable, value = nil)
        raise UnsupportedVariableError.new(variable) unless @@variables.has_key? variable
        @@variables[variable] = value
      end

      def true?(variable)
        v = self.get(variable)
        (!v.nil? && v =~ /^\s*(?:true|1|yes|on)\s*$/i) ? true : false
      end

      def false?(variable)
        self.true?(variable) == false
      end

      def variables
        @@variables.keys
      end

      def dump
        @@variables.dup
      end

      def env_variable_prefix
        @@env_variable_prefix
      end

      def initialize_from_yaml(path)
        # FIXME: It would be a lot cleaner if the YAML library would raise an
        # exception if it fails to read the file. We'll handle it like this for now
        # load_file just returns "false" if it fails

        yaml_data = YAML.load_file(path)
        yaml_data.each do |variable, value|
          raise UnsupportedVariableError.new(variable) unless @@variables.has_key? variable.to_sym
          set(variable.to_sym, value.to_s)
        end
        after_initialize
        dump
      end

      def initialize_from_env(prefix=@@env_variable_prefix)
        ENV.keys.reject { |key|
          key !~ /^#{prefix}/ # Ignore everything that doesn't match the prefix
        }.each { |key|
          variable = key[prefix.size..-1].downcase.to_sym
          unless @@variables.has_key? variable
            raise UnsupportedVariableError.new(variable)
          end

          set(variable, ENV[key])
        }
        after_initialize
        dump
      end

      def after_initialize
      end

      def with_config(overrides={})
        originals = dump
        overrides.each_pair {|k,v| self.set(k, v) }

        begin
          result = yield
        ensure
          @@variables = originals
        end

        result
      end
    end
  end

  class InitializationError < StandardError
  end

  class UnsupportedVariableError < StandardError
  end
end
